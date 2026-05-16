import SwiftUI

@main
struct BerryCamMacApp: App {
    @StateObject private var webRTC = HostWebRTCService()
    @StateObject private var signaling = SignalingServer()
    @StateObject private var sleepPreventer = SleepPreventer()
    @StateObject private var detectionStore: DetectionEventStore
    @StateObject private var catDetection: CatDetectionService

    init() {
        let detectionStore = DetectionEventStore()
        _detectionStore = StateObject(wrappedValue: detectionStore)
        _catDetection = StateObject(wrappedValue: CatDetectionService(store: detectionStore))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(webRTC)
                .environmentObject(signaling)
                .environmentObject(sleepPreventer)
                .environmentObject(detectionStore)
                .environmentObject(catDetection)
                .onAppear {
                    webRTC.frameAnalyzer = catDetection
                    signaling.detectionStore = detectionStore
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
