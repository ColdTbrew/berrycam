import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewer: ViewerWebRTCService
    @State private var host = "100.x.y.z"
    @State private var port = "3000"
    @State private var accessCode = "berrycam"

    var body: some View {
        NavigationStack {
            Group {
                if viewer.isWatching {
                    watchingView
                } else {
                    setupView
                }
            }
            .navigationTitle("BerryCam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    statusBadge
                }
            }
        }
    }

    private var setupView: some View {
        Form {
            Section {
                TextField("Mac Tailscale host", text: $host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                TextField("Port", text: $port)
                    .keyboardType(.numberPad)

                SecureField("Access code", text: $accessCode)
            } header: {
                Text("Host")
            } footer: {
                Text("Use the Mac's Tailscale name or 100.x.y.z address.")
            }

            Section {
                Button {
                    viewer.connect(host: host, port: UInt16(port) ?? 3000, accessCode: accessCode)
                } label: {
                    Label("Connect", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var watchingView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            WebRTCVideoView(track: viewer.remoteVideoTrack)
                .ignoresSafeArea()
                .opacity(viewer.remoteVideoTrack == nil ? 0 : 1)

            if viewer.remoteVideoTrack == nil {
                ContentUnavailableView(
                    "Waiting for Video",
                    systemImage: "video",
                    description: Text("BerryCam is connected and waiting for the Mac camera stream.")
                )
                .foregroundStyle(.white.secondary)
            }

            Button {
                viewer.disconnect()
            } label: {
                Label("Disconnect", systemImage: "stop.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 10)
            .padding(.leading, 12)
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var statusBadge: some View {
        Text(viewer.connectionState)
            .font(.caption.weight(.semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor.opacity(0.14), in: Capsule())
            .accessibilityLabel("Connection status \(viewer.connectionState)")
    }

    private var statusColor: Color {
        switch viewer.connectionState.lowercased() {
        case "connected", "watching":
            .green
        case "connecting", "checking":
            .orange
        case "failed", "disconnected", "closed":
            .red
        default:
            .secondary
        }
    }
}
