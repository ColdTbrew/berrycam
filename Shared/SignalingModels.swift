import Foundation
import LiveKitWebRTC

struct SignalingEnvelope: Codable {
    var code: String
    var sdp: String?
    var type: String?
    var candidate: IceCandidatePayload?
}

struct SessionDescriptionPayload: Codable {
    var sdp: String
    var type: String
}

struct IceCandidatePayload: Codable, Hashable {
    var sdp: String
    var sdpMLineIndex: Int32
    var sdpMid: String?
}

extension RTCSessionDescription {
    convenience init(payload: SessionDescriptionPayload) {
        self.init(type: RTCSdpType(payload.type), sdp: payload.sdp)
    }

    var payload: SessionDescriptionPayload {
        SessionDescriptionPayload(sdp: sdp, type: type.stringValue)
    }
}

extension RTCIceCandidate {
    convenience init(payload: IceCandidatePayload) {
        self.init(sdp: payload.sdp, sdpMLineIndex: payload.sdpMLineIndex, sdpMid: payload.sdpMid)
    }

    var payload: IceCandidatePayload {
        IceCandidatePayload(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
    }
}

extension RTCSdpType {
    init(_ string: String) {
        switch string.lowercased() {
        case "offer":
            self = .offer
        case "answer":
            self = .answer
        case "pranswer":
            self = .prAnswer
        default:
            self = .offer
        }
    }

    var stringValue: String {
        switch self {
        case .offer:
            return "offer"
        case .answer:
            return "answer"
        case .prAnswer:
            return "pranswer"
        case .rollback:
            return "rollback"
        @unknown default:
            return "offer"
        }
    }
}
