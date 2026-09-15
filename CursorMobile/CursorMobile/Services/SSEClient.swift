import Foundation

final class SSEClient: ObservableObject {
    private var task: URLSessionDataTask?
    private var session: URLSession?
    private var buffer = ""
    private var lastEventId: String?
    private var intentionallyDisconnected = false

    var onEvent: ((StreamEvent) -> Void)?
    var onComplete: (() -> Void)?
    var onError: ((Error) -> Void)?

    @MainActor
    func connect(agentId: String, runId: String) {
        disconnect(intentional: false)

        guard let apiKey = KeychainService.shared.loadAPIKey() else {
            onError?(CursorAPIError.unauthorized)
            return
        }

        intentionallyDisconnected = false

        let url = URL(string: "https://api.cursor.com/v1/agents/\(agentId)/runs/\(runId)/stream")!
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        if let lastEventId {
            request.setValue(lastEventId, forHTTPHeaderField: "Last-Event-ID")
        }

        let session = URLSession(
            configuration: .default,
            delegate: SSEDelegate(client: self),
            delegateQueue: nil
        )
        self.session = session
        task = session.dataTask(with: request)
        task?.resume()
    }

    @MainActor
    func disconnect() {
        disconnect(intentional: true)
    }

    @MainActor
    private func disconnect(intentional: Bool) {
        intentionallyDisconnected = intentional
        task?.cancel()
        task = nil
        buffer = ""
        session?.invalidateAndCancel()
        session = nil
    }

    @MainActor
    var isIntentionallyDisconnected: Bool {
        intentionallyDisconnected
    }

    @MainActor
    func processChunk(_ data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        buffer += chunk

        while let range = buffer.range(of: "\n\n") {
            let block = String(buffer[..<range.lowerBound])
            buffer = String(buffer[range.upperBound...])
            parseEventBlock(block)
        }
    }

    @MainActor
    func finish() {
        guard !intentionallyDisconnected else { return }
        onComplete?()
    }

    @MainActor
    func fail(_ error: Error) {
        guard !intentionallyDisconnected else { return }
        onError?(error)
    }

    @MainActor
    private func parseEventBlock(_ block: String) {
        var eventType: String?
        var eventId: String?
        var dataLines: [String] = []

        for line in block.split(separator: "\n", omittingEmptySubsequences: false) {
            let lineStr = String(line)
            if lineStr.hasPrefix("event:") {
                eventType = lineStr.dropFirst(6).trimmingCharacters(in: .whitespaces)
            } else if lineStr.hasPrefix("id:") {
                eventId = lineStr.dropFirst(3).trimmingCharacters(in: .whitespaces)
                lastEventId = eventId
            } else if lineStr.hasPrefix("data:") {
                dataLines.append(lineStr.dropFirst(5).trimmingCharacters(in: .whitespaces))
            }
        }

        guard let eventType,
              let type = StreamEvent.EventType(rawValue: eventType) else {
            return
        }

        let dataString = dataLines.joined(separator: "\n")
        let jsonData = dataString.data(using: .utf8) ?? Data()
        let json = (try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]) ?? [:]

        let event = StreamEvent(type: type, eventId: eventId, data: json)
        onEvent?(event)
    }
}

private final class SSEDelegate: NSObject, URLSessionDataDelegate {
    weak var client: SSEClient?
    private var receivedSuccessfulResponse = false

    init(client: SSEClient) {
        self.client = client
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200...299:
                receivedSuccessfulResponse = true
                completionHandler(.allow)
            case 401:
                completionHandler(.cancel)
                Task { @MainActor in
                    client?.fail(CursorAPIError.unauthorized)
                }
            case 410:
                // Stream retention window expired — do not reconnect; fetch final run via REST.
                completionHandler(.cancel)
                Task { @MainActor in
                    client?.fail(CursorAPIError.streamExpired)
                }
            default:
                completionHandler(.cancel)
                Task { @MainActor in
                    client?.fail(CursorAPIError.serverError(httpResponse.statusCode))
                }
            }
            return
        }

        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        Task { @MainActor in
            client?.processChunk(data)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task { @MainActor in
            // User-initiated disconnect must never trigger reconnect / complete handlers.
            if client?.isIntentionallyDisconnected == true {
                return
            }

            if let error, (error as NSError).code != NSURLErrorCancelled {
                client?.fail(error)
            } else if receivedSuccessfulResponse {
                client?.finish()
            }
        }
    }
}
