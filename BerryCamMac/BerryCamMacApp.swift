import SwiftUI

@main
struct BerryCamMacApp: App {
    @StateObject private var webRTC = HostWebRTCService()
    @StateObject private var signaling = SignalingServer()
    @StateObject private var sleepPreventer = SleepPreventer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(webRTC)
                .environmentObject(signaling)
                .environmentObject(sleepPreventer)
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
