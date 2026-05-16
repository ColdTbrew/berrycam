import AVFoundation
import Foundation
import LiveKitWebRTC

@MainActor
final class ViewerWebRTCService: NSObject, ObservableObject {
    @Published private(set) var remoteVideoTrack: RTCVideoTrack?
    @Published private(set) var connectionState = "Idle"
    @Published private(set) var audioState = "Off"
    @Published private(set) var isMicrophoneEnabled = false
    @Published private(set) var isWatching = false
    @Published private(set) var detectionEvents: [CatDetectionEventPayload] = []
    @Published private(set) var liveDetectionEvent: CatDetectionEventPayload?
    @Published private(set) var historyState = "Not loaded"

    private var factory: RTCPeerConnectionFactory?
    private var peerConnection: RTCPeerConnection?
    private var signaling: SignalingClient?
    private var pollingTask: Task<Void, Never>?
    private var detectionPollingTask: Task<Void, Never>?
    private var localAudioTrack: RTCAudioTrack?
    private var remoteAudioTrack: RTCAudioTrack?

    func connect(host: String, port: UInt16, accessCode: String, microphoneEnabled: Bool = false) {
        disconnect()
        isWatching = true
        connectionState = "Connecting"
        setMicrophoneEnabled(microphoneEnabled)
        if microphoneEnabled {
            configureAudioSession()
        }

        RTCInitializeSSL()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        let factory = RTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)
        self.factory = factory

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
            connectionState = "Peer failed"
            isWatching = false
            return
        }

        if microphoneEnabled {
            localAudioTrack = factory.audioTrack(
                with: factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)),
                trackId: "berrycam-iphone-audio"
            )
            if let localAudioTrack {
                peerConnection.add(localAudioTrack, streamIds: ["berrycam"])
                audioState = "Mic on"
            }
        } else {
            audioState = "Mic off"
        }

        self.peerConnection = peerConnection
        self.signaling = SignalingClient(host: host, port: port, accessCode: accessCode)

        let offerConstraints = RTCMediaConstraints(
            mandatoryConstraints: [
                kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
                kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue,
            ],
            optionalConstraints: nil
        )

        peerConnection.offer(for: offerConstraints) { [weak self] offer, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.fail(error)
                    return
                }
                guard let offer else {
                    self.connectionState = "No offer"
                    self.isWatching = false
                    return
                }

                peerConnection.setLocalDescription(offer) { error in
                    Task { @MainActor in
                        if let error {
                            self.fail(error)
                        } else {
                            self.sendOffer(offer)
                        }
                    }
                }
            }
        }
    }

    func disconnect() {
        pollingTask?.cancel()
        pollingTask = nil
        detectionPollingTask?.cancel()
        detectionPollingTask = nil
        peerConnection?.close()
        peerConnection = nil
        signaling = nil
        remoteVideoTrack = nil
        localAudioTrack = nil
        remoteAudioTrack = nil
        isWatching = false
        connectionState = "Idle"
        audioState = "Off"
        detectionEvents = []
        liveDetectionEvent = nil
        historyState = "Not loaded"
    }

    func setMicrophoneEnabled(_ enabled: Bool) {
        isMicrophoneEnabled = enabled
        localAudioTrack?.isEnabled = enabled
        audioState = enabled ? "Mic on" : "Mic off"
    }

    func refreshDetectionEvents() {
        Task {
            do {
                historyState = "Loading"
                updateDetectionEvents(try await signaling?.fetchDetectionEvents() ?? [])
            } catch {
                historyState = "History failed"
            }
        }
    }

    func snapshotURL(filename: String) -> URL? {
        signaling?.snapshotURL(filename: filename)
    }

    func snapshotData(filename: String) async throws -> Data {
        guard let signaling else { throw ViewerError.notConnected }
        return try await signaling.fetchSnapshotData(filename: filename)
    }

    func deleteDetectionEvent(_ event: CatDetectionEventPayload) {
        Task {
            do {
                try await signaling?.deleteDetectionEvent(id: event.id)
                detectionEvents.removeAll { $0.id == event.id }
                if liveDetectionEvent?.id == event.id {
                    liveDetectionEvent = nil
                }
                historyState = detectionEvents.isEmpty ? "No events" : "Loaded"
            } catch {
                historyState = "Delete failed"
                refreshDetectionEvents()
            }
        }
    }

    private func sendOffer(_ offer: RTCSessionDescription) {
        Task {
            do {
                guard let signaling, let peerConnection else { return }
                let answer = try await signaling.sendOffer(offer)
                peerConnection.setRemoteDescription(answer) { [weak self] error in
                    Task { @MainActor in
                        if let error {
                            self?.fail(error)
                        } else {
                            self?.connectionState = "Waiting for media"
                            self?.startCandidatePolling()
                            self?.startDetectionPolling()
                        }
                    }
                }
            } catch {
                fail(error)
            }
        }
    }

    private func startCandidatePolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    guard let self else { return }
                    let candidates = try await self.signaling?.fetchCandidates() ?? []
                    for candidate in candidates {
                        self.peerConnection?.add(candidate) { error in
                            if let error {
                                Task { @MainActor in self.connectionState = "ICE error: \(error.localizedDescription)" }
                            }
                        }
                    }
                } catch {
                    await MainActor.run {
                        guard self?.remoteVideoTrack == nil else { return }
                        self?.connectionState = "Polling failed"
                    }
                }

                try? await Task.sleep(nanoseconds: 700_000_000)
            }
        }
    }

    private func startDetectionPolling() {
        detectionPollingTask?.cancel()
        detectionPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    guard let self else { return }
                    let events = try await self.signaling?.fetchDetectionEvents() ?? []
                    await MainActor.run {
                        self.updateDetectionEvents(events)
                    }
                } catch {
                    await MainActor.run {
                        guard self?.detectionEvents.isEmpty == true else { return }
                        self?.historyState = "History failed"
                    }
                }

                try? await Task.sleep(nanoseconds: 2_500_000_000)
            }
        }
    }

    private func updateDetectionEvents(_ events: [CatDetectionEventPayload]) {
        detectionEvents = events
        historyState = events.isEmpty ? "No events" : "Updated"

        guard
            let latest = events.first,
            Date().timeIntervalSince(latest.timestamp) <= 30
        else {
            liveDetectionEvent = nil
            return
        }
        liveDetectionEvent = latest
    }

    private func fail(_ error: Error) {
        connectionState = connectionMessage(for: error)
        isWatching = false
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
        } catch {
            audioState = "Audio setup failed"
        }
    }

    private func connectionMessage(for error: Error) -> String {
        guard let urlError = error as? URLError else {
            return error.localizedDescription
        }

        switch urlError.code {
        case .timedOut, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
            return "Host unreachable"
        case .notConnectedToInternet:
            return "No network"
        default:
            return urlError.localizedDescription
        }
    }
}

private enum ViewerError: LocalizedError {
    case notConnected

    var errorDescription: String? {
        "BerryCam is not connected to the Mac host."
    }
}

extension ViewerWebRTCService: RTCPeerConnectionDelegate {
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
            try? await self?.signaling?.sendCandidate(candidate)
        }
    }
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams: [RTCMediaStream]) {
        Task { @MainActor [weak self] in
            if let track = rtpReceiver.track as? RTCVideoTrack {
                self?.remoteVideoTrack = track
                self?.connectionState = "Live"
            } else if let track = rtpReceiver.track as? RTCAudioTrack {
                self?.remoteAudioTrack = track
                self?.audioState = "Two-way audio"
            }
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
            return "Live"
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
