import SwiftUI

@main
struct BerryCamMacApp: App {
    @StateObject private var webRTC = HostWebRTCService()
    @StateObject private var signaling = SignalingServer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(webRTC)
                .environmentObject(signaling)
                .onAppear {
                    signaling.onOffer = { offer, completion in
                        webRTC.answer(offer: offer, completion: completion)
                    }
                    signaling.onRemoteCandidate = { candidate in
                        webRTC.addRemoteCandidate(candidate)
                    }
                    webRTC.onLocalCandidate = { candidate in
                        signaling.addHostCandidate(candidate)
                    }
                }
        }
        .windowResizability(.contentSize)
    }
}
