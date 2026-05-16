import SwiftUI

@main
struct BerryCamWatchApp: App {
    @StateObject private var viewer = ViewerWebRTCService()
    @StateObject private var recentHosts = RecentHostStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewer)
                .environmentObject(recentHosts)
        }
    }
}
