import AVFoundation
import Foundation
import LiveKitWebRTC

@MainActor
final class HostWebRTCService: NSObject, ObservableObject {
    @Published private(set) var localVideoTrack: RTCVideoTrack?
    @Published private(set) var connectionState = "Idle"

    var onLocalCandidate: ((RTCIceCandidate) -> Void)?

    private var peerConnection: RTCPeerConnection?
    private var factory: RTCPeerConnectionFactory?
    private var videoCapturer: RTCCameraVideoCapturer?

    func startCamera() {
        guard localVideoTrack == nil else { return }
        RTCInitializeSSL()

        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        let factory = RTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)
        self.factory = factory

        let videoSource = factory.videoSource()
        let capturer = RTCCameraVideoCapturer(delegate: videoSource)
        videoCapturer = capturer

        let track = factory.videoTrack(with: videoSource, trackId: "berrycam-video")
        localVideoTrack = track
        startCapture(using: capturer)
    }

    func stop() {
        peerConnection?.close()
        peerConnection = nil
        localVideoTrack = nil
        videoCapturer?.stopCapture()
        videoCapturer = nil
        connectionState = "Idle"
    }

    func answer(offer: RTCSessionDescription, completion: @escaping (Result<RTCSessionDescription, Error>) -> Void) {
        startCamera()

        guard let factory else {
            completion(.failure(BerryCamError.missingFactory))
            return
        }

        peerConnection?.close()
        let configuration = RTCConfiguration()
        configuration.sdpSemantics = .unifiedPlan
        configuration.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
        ]

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue]
        )

        guard let peerConnection = factory.peerConnection(with: configuration, constraints: constraints, delegate: self) else {
            completion(.failure(BerryCamError.peerConnectionFailed))
            return
        }

        if let localVideoTrack {
            peerConnection.add(localVideoTrack, streamIds: ["berrycam"])
        }

        self.peerConnection = peerConnection
        connectionState = "Received offer"

        peerConnection.setRemoteDescription(offer) { [weak self] error in
            if let error {
                completion(.failure(error))
                return
            }

            let mediaConstraints = RTCMediaConstraints(
                mandatoryConstraints: [
                    kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueFalse,
                    kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueFalse,
                ],
                optionalConstraints: nil
            )

            peerConnection.answer(for: mediaConstraints) { answer, error in
                if let error {
                    completion(.failure(error))
                    return
                }
                guard let answer else {
                    completion(.failure(BerryCamError.answerFailed))
                    return
                }

                peerConnection.setLocalDescription(answer) { error in
                    Task { @MainActor in
                        if let error {
                            completion(.failure(error))
                        } else {
                            self?.connectionState = "Answered"
                            completion(.success(answer))
                        }
                    }
                }
            }
        }
    }

    func addRemoteCandidate(_ candidate: RTCIceCandidate) {
        peerConnection?.add(candidate) { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.connectionState = "Candidate error: \(error.localizedDescription)"
                }
            }
        }
    }

    private func startCapture(using capturer: RTCCameraVideoCapturer) {
        guard let device = RTCCameraVideoCapturer.captureDevices().first else {
            connectionState = "No camera"
            return
        }

        let formats = RTCCameraVideoCapturer.supportedFormats(for: device)
        let format = formats
            .sorted { lhs, rhs in
                let left = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription)
                let right = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription)
                return left.width * left.height < right.width * right.height
            }
            .last

        guard let format else {
            connectionState = "No camera format"
            return
        }

        let fps = min(30, Int(format.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 30))
        capturer.startCapture(with: device, format: format, fps: fps)
        connectionState = "Camera on"
    }
}

extension HostWebRTCService: RTCPeerConnectionDelegate {
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Task { @MainActor [weak self] in
            self?.connectionState = newState.label
        }
    }
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        Task { @MainActor [weak self] in
            self?.onLocalCandidate?(candidate)
        }
    }
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}

private enum BerryCamError: LocalizedError {
    case missingFactory
    case peerConnectionFailed
    case answerFailed

    var errorDescription: String? {
        switch self {
        case .missingFactory:
            return "WebRTC factory is not ready"
        case .peerConnectionFailed:
            return "Could not create peer connection"
        case .answerFailed:
            return "Could not create answer"
        }
    }
}

private extension RTCIceConnectionState {
    var label: String {
        switch self {
        case .new:
            return "New"
        case .checking:
            return "Checking"
        case .connected:
            return "Connected"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .disconnected:
            return "Disconnected"
        case .closed:
            return "Closed"
        case .count:
            return "Unknown"
        @unknown default:
            return "Unknown"
        }
    }
}
