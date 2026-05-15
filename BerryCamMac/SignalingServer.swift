import Foundation
import Darwin
import Network
import LiveKitWebRTC

@MainActor
final class SignalingServer: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var status = "Stopped"
    @Published private(set) var urls: [String] = []

    var onOffer: ((RTCSessionDescription, @escaping (Result<RTCSessionDescription, Error>) -> Void) -> Void)?
    var onRemoteCandidate: ((RTCIceCandidate) -> Void)?

    private var listener: NWListener?
    private var accessCode = "berrycam"
    private var hostCandidates: [IceCandidatePayload] = []

    func start(port: UInt16, accessCode: String) {
        stop()
        self.accessCode = accessCode
        hostCandidates.removeAll()

        do {
            let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection: connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        self?.status = "Listening on \(port)"
                        self?.urls = NetworkAddresses.httpURLs(port: port)
                    case .failed(let error):
                        self?.isRunning = false
                        self?.status = error.localizedDescription
                    case .cancelled:
                        self?.isRunning = false
                        self?.status = "Stopped"
                    default:
                        break
                    }
                }
            }
            self.listener = listener
            listener.start(queue: .global(qos: .userInitiated))
        } catch {
            status = error.localizedDescription
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        status = "Stopped"
        urls = []
        hostCandidates.removeAll()
    }

    func addHostCandidate(_ candidate: RTCIceCandidate) {
        hostCandidates.append(candidate.payload)
    }

    private nonisolated func handle(connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        receive(on: connection, buffer: Data())
    }

    private nonisolated func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            var nextBuffer = buffer
            if let data {
                nextBuffer.append(data)
            }

            if let request = HTTPRequest(data: nextBuffer) {
                Task { @MainActor in
                    self?.respond(to: request, on: connection)
                }
                return
            }

            if isComplete || error != nil {
                connection.cancel()
                return
            }

            self?.receive(on: connection, buffer: nextBuffer)
        }
    }

    private func respond(to request: HTTPRequest, on connection: NWConnection) {
        switch (request.method, request.path) {
        case ("GET", "/health"):
            sendJSON(["ok": true, "running": isRunning], on: connection)

        case ("POST", "/offer"):
            guard
                let envelope = try? JSONDecoder().decode(SignalingEnvelope.self, from: request.body),
                envelope.code == accessCode,
                let sdp = envelope.sdp,
                let type = envelope.type
            else {
                send(status: 401, body: #"{"error":"invalid code or offer"}"#, on: connection)
                return
            }

            let offer = RTCSessionDescription(payload: SessionDescriptionPayload(sdp: sdp, type: type))
            onOffer?(offer) { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success(let answer):
                        self?.sendJSON(answer.payload, on: connection)
                    case .failure(let error):
                        self?.send(status: 500, body: #"{"error":"\#(error.localizedDescription)"}"#, on: connection)
                    }
                }
            }

        case ("POST", "/candidate"):
            guard
                let envelope = try? JSONDecoder().decode(SignalingEnvelope.self, from: request.body),
                envelope.code == accessCode,
                let candidate = envelope.candidate
            else {
                send(status: 401, body: #"{"error":"invalid code or candidate"}"#, on: connection)
                return
            }
            onRemoteCandidate?(RTCIceCandidate(payload: candidate))
            sendJSON(["ok": true], on: connection)

        case ("GET", "/candidates"):
            guard request.query["code"] == accessCode else {
                send(status: 401, body: #"{"error":"invalid code"}"#, on: connection)
                return
            }
            let after = Int(request.query["after"] ?? "0") ?? 0
            let payload = Array(hostCandidates.dropFirst(max(0, after)))
            sendJSON(CandidatesResponse(candidates: payload, next: hostCandidates.count), on: connection)

        default:
            send(status: 404, body: #"{"error":"not found"}"#, on: connection)
        }
    }

    private func sendJSON<T: Encodable>(_ value: T, on connection: NWConnection) {
        do {
            let data = try JSONEncoder().encode(value)
            send(status: 200, bodyData: data, contentType: "application/json", on: connection)
        } catch {
            send(status: 500, body: #"{"error":"encoding failed"}"#, on: connection)
        }
    }

    private func send(status: Int, body: String, on connection: NWConnection) {
        send(status: status, bodyData: Data(body.utf8), contentType: "application/json", on: connection)
    }

    private func send(status: Int, bodyData: Data, contentType: String, on connection: NWConnection) {
        let reason = status == 200 ? "OK" : status == 401 ? "Unauthorized" : status == 404 ? "Not Found" : "Error"
        var header = "HTTP/1.1 \(status) \(reason)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(bodyData.count)\r\n"
        header += "Connection: close\r\n"
        header += "Access-Control-Allow-Origin: *\r\n\r\n"

        var response = Data(header.utf8)
        response.append(bodyData)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

private struct CandidatesResponse: Encodable {
    var candidates: [IceCandidatePayload]
    var next: Int
}

private struct HTTPRequest {
    let method: String
    let path: String
    let query: [String: String]
    let body: Data

    init?(data: Data) {
        guard let headerRange = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = data[..<headerRange.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }

        var contentLength = 0
        for line in lines.dropFirst() {
            let pair = line.split(separator: ":", maxSplits: 1)
            if pair.count == 2 && pair[0].lowercased() == "content-length" {
                contentLength = Int(pair[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }

        let bodyStart = headerRange.upperBound
        guard data.count >= bodyStart + contentLength else { return nil }

        method = String(parts[0])
        let fullPath = String(parts[1])
        let components = fullPath.split(separator: "?", maxSplits: 1).map(String.init)
        path = components.first ?? "/"
        if components.count > 1 {
            query = URLComponents(string: "http://berrycam.local?\(components[1])")?
                .queryItems?
                .reduce(into: [:]) { $0[$1.name] = $1.value ?? "" } ?? [:]
        } else {
            query = [:]
        }
        body = Data(data[bodyStart..<(bodyStart + contentLength)])
    }
}

private enum NetworkAddresses {
    static func httpURLs(port: UInt16) -> [String] {
        var urls = ["http://localhost:\(port)"]
        var addresses: UnsafeMutablePointer<ifaddrs>?

        if getifaddrs(&addresses) == 0 {
            var pointer = addresses
            while pointer != nil {
                defer { pointer = pointer?.pointee.ifa_next }
                guard
                    let interface = pointer?.pointee,
                    interface.ifa_addr.pointee.sa_family == UInt8(AF_INET)
                else { continue }

                var address = interface.ifa_addr.pointee
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(&address, socklen_t(interface.ifa_addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                let ip = String(cString: host)
                if ip != "127.0.0.1" {
                    urls.append("http://\(ip):\(port)")
                }
            }
            freeifaddrs(addresses)
        }

        return urls
    }
}
