import SwiftUI
import LiveKitWebRTC
#if os(iOS)
import AVKit
import UIKit
#endif

#if os(iOS)
struct WebRTCVideoView: UIViewRepresentable {
    let track: RTCVideoTrack?
    let letterboxColor: UIColor

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView(frame: .zero)
        view.videoContentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.backgroundColor = letterboxColor
        context.coordinator.configurePictureInPicture(sourceView: view, letterboxColor: letterboxColor)
        return view
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        uiView.backgroundColor = letterboxColor
        context.coordinator.update(track: track, renderer: uiView)
        context.coordinator.updatePictureInPicture(track: track, letterboxColor: letterboxColor)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}

final class Coordinator {
    private weak var currentTrack: RTCVideoTrack?
    private let pictureInPicture = WebRTCPictureInPictureController()

    func update(track: RTCVideoTrack?, renderer: RTCVideoRenderer) {
        guard currentTrack !== track else { return }
        currentTrack?.remove(renderer)
        currentTrack = track
        track?.add(renderer)
    }

    func configurePictureInPicture(sourceView: UIView, letterboxColor: UIColor) {
        pictureInPicture.configure(sourceView: sourceView, letterboxColor: letterboxColor)
    }

    func updatePictureInPicture(track: RTCVideoTrack?, letterboxColor: UIColor) {
        pictureInPicture.update(track: track, letterboxColor: letterboxColor)
    }
}

private final class WebRTCPictureInPictureController: NSObject, AVPictureInPictureControllerDelegate {
    private weak var currentTrack: RTCVideoTrack?
    private var pipController: AVPictureInPictureController?
    private var pipRenderer: RTCMTLVideoView?

    func configure(sourceView: UIView, letterboxColor: UIColor) {
        guard pipController == nil, AVPictureInPictureController.isPictureInPictureSupported() else { return }

        let renderer = RTCMTLVideoView(frame: .zero)
        renderer.videoContentMode = .scaleAspectFit
        renderer.clipsToBounds = true
        renderer.backgroundColor = letterboxColor
        pipRenderer = renderer

        let contentViewController = AVPictureInPictureVideoCallViewController()
        contentViewController.preferredContentSize = CGSize(width: 480, height: 270)
        renderer.translatesAutoresizingMaskIntoConstraints = false
        contentViewController.view.backgroundColor = letterboxColor
        contentViewController.view.addSubview(renderer)
        NSLayoutConstraint.activate([
            renderer.leadingAnchor.constraint(equalTo: contentViewController.view.leadingAnchor),
            renderer.trailingAnchor.constraint(equalTo: contentViewController.view.trailingAnchor),
            renderer.topAnchor.constraint(equalTo: contentViewController.view.topAnchor),
            renderer.bottomAnchor.constraint(equalTo: contentViewController.view.bottomAnchor),
        ])

        let source = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: sourceView,
            contentViewController: contentViewController
        )
        let controller = AVPictureInPictureController(contentSource: source)
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.delegate = self
        pipController = controller
    }

    func update(track: RTCVideoTrack?, letterboxColor: UIColor) {
        pipRenderer?.backgroundColor = letterboxColor
        pipRenderer?.superview?.backgroundColor = letterboxColor

        guard currentTrack !== track else { return }
        if let pipRenderer {
            currentTrack?.remove(pipRenderer)
            track?.add(pipRenderer)
        }
        currentTrack = track
    }

    deinit {
        if let pipRenderer {
            currentTrack?.remove(pipRenderer)
        }
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
