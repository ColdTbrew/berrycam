import SwiftUI

@main
struct BerryCamWatchApp: App {
    @StateObject private var viewer = ViewerWebRTCService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewer)
        }
    }
}
