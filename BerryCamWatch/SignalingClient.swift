import Foundation
import LiveKitWebRTC

final class SignalingClient {
    private let baseURL: URL
    private let accessCode: String
    private var nextCandidateIndex = 0

    init(host: String, port: UInt16, accessCode: String) {
        let normalizedHost = host
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.baseURL = URL(string: "http://\(normalizedHost):\(port)")!
        self.accessCode = accessCode
    }

    func sendOffer(_ offer: RTCSessionDescription) async throws -> RTCSessionDescription {
        let envelope = SignalingEnvelope(code: accessCode, sdp: offer.sdp, type: offer.type.stringValue, candidate: nil)
        let answer: SessionDescriptionPayload = try await post(path: "/offer", body: envelope)
        return RTCSessionDescription(payload: answer)
    }

    func sendCandidate(_ candidate: RTCIceCandidate) async throws {
        let envelope = SignalingEnvelope(code: accessCode, sdp: nil, type: nil, candidate: candidate.payload)
        let _: SimpleResponse = try await post(path: "/candidate", body: envelope)
    }

    func fetchCandidates() async throws -> [RTCIceCandidate] {
        var components = URLComponents(url: baseURL.appending(path: "/candidates"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "code", value: accessCode),
            URLQueryItem(name: "after", value: String(nextCandidateIndex)),
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        try validate(response: response)
        let payload = try JSONDecoder().decode(CandidatesResponse.self, from: data)
        nextCandidateIndex = payload.next
        return payload.candidates.map(RTCIceCandidate.init(payload:))
    }

    private func post<T: Encodable, U: Decodable>(path: String, body: T) async throws -> U {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode(U.self, from: data)
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SignalingError.badResponse
        }
    }
}

private struct CandidatesResponse: Decodable {
    var candidates: [IceCandidatePayload]
    var next: Int
}

private struct SimpleResponse: Decodable {
    var ok: Bool
}

private enum SignalingError: LocalizedError {
    case badResponse

    var errorDescription: String? {
        "The Mac host rejected the signaling request."
    }
}
