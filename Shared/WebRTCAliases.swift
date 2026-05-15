import Foundation
import LiveKitWebRTC

typealias RTCConfiguration = LKRTCConfiguration
typealias RTCDataChannel = LKRTCDataChannel
typealias RTCDefaultVideoDecoderFactory = LKRTCDefaultVideoDecoderFactory
typealias RTCDefaultVideoEncoderFactory = LKRTCDefaultVideoEncoderFactory
typealias RTCAudioSource = LKRTCAudioSource
typealias RTCAudioTrack = LKRTCAudioTrack
typealias RTCIceCandidate = LKRTCIceCandidate
typealias RTCIceConnectionState = LKRTCIceConnectionState
typealias RTCIceGatheringState = LKRTCIceGatheringState
typealias RTCIceServer = LKRTCIceServer
typealias RTCMediaConstraints = LKRTCMediaConstraints
typealias RTCMediaStream = LKRTCMediaStream
typealias RTCPeerConnection = LKRTCPeerConnection
typealias RTCPeerConnectionDelegate = LKRTCPeerConnectionDelegate
typealias RTCPeerConnectionFactory = LKRTCPeerConnectionFactory
typealias RTCRtpReceiver = LKRTCRtpReceiver
typealias RTCSdpSemantics = LKRTCSdpSemantics
typealias RTCSdpType = LKRTCSdpType
typealias RTCSessionDescription = LKRTCSessionDescription
typealias RTCSignalingState = LKRTCSignalingState
typealias RTCCameraVideoCapturer = LKRTCCameraVideoCapturer
typealias RTCVideoRenderer = LKRTCVideoRenderer
typealias RTCVideoTrack = LKRTCVideoTrack
typealias RTCCVPixelBuffer = LKRTCCVPixelBuffer
typealias RTCVideoCapturer = LKRTCVideoCapturer
typealias RTCVideoCapturerDelegate = LKRTCVideoCapturerDelegate
typealias RTCVideoFrame = LKRTCVideoFrame
typealias RTCVideoRotation = LKRTCVideoRotation

#if os(iOS)
typealias RTCMTLVideoView = LKRTCMTLVideoView
#else
typealias RTCDesktopCapturer = LKRTCDesktopCapturer
typealias RTCMTLNSVideoView = LKRTCMTLNSVideoView
#endif

let kRTCMediaConstraintsOfferToReceiveAudio = kLKRTCMediaConstraintsOfferToReceiveAudio
let kRTCMediaConstraintsOfferToReceiveVideo = kLKRTCMediaConstraintsOfferToReceiveVideo
let kRTCMediaConstraintsValueFalse = kLKRTCMediaConstraintsValueFalse
let kRTCMediaConstraintsValueTrue = kLKRTCMediaConstraintsValueTrue

@discardableResult
func RTCInitializeSSL() -> Bool {
    LKRTCInitializeSSL()
}
