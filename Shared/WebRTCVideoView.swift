import SwiftUI
import LiveKitWebRTC

#if os(iOS)
struct WebRTCVideoView: UIViewRepresentable {
    let track: RTCVideoTrack?

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView(frame: .zero)
        view.videoContentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        context.coordinator.update(track: track, renderer: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}

final class Coordinator {
    private weak var currentTrack: RTCVideoTrack?

    func update(track: RTCVideoTrack?, renderer: RTCVideoRenderer) {
        guard currentTrack !== track else { return }
        currentTrack?.remove(renderer)
        currentTrack = track
        track?.add(renderer)
    }
}
#else
struct WebRTCVideoView: NSViewRepresentable {
    let track: RTCVideoTrack?

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
