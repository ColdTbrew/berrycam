import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewer: ViewerWebRTCService
    @State private var host = ""
    @State private var port = "3000"
    @State private var accessCode = "berrycam"
    @State private var connectionAlert: ConnectionAlert?

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
                if viewer.isWatching {
                    ToolbarItem(placement: .topBarTrailing) {
                        statusBadge
                    }
                }
            }
            .alert(item: $connectionAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
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
                Text("Use the Mac's Tailscale name or 100.x.y.z address shown in BerryCam Mac.")
            }

            Section {
                Button {
                    connect()
                } label: {
                    Label("Connect", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .center)

                if viewer.connectionState != "Idle" {
                    Text(viewer.connectionState)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .listRowInsets(EdgeInsets(top: 18, leading: 36, bottom: 18, trailing: 36))
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

            VStack {
                Spacer()
                Text(viewer.audioState)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.secondary)
                    .padding(.bottom, 14)
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
        case "connected", "watching", "live":
            .green
        case "connecting", "checking":
            .orange
        case "failed", "disconnected", "closed":
            .red
        default:
            .secondary
        }
    }

    private func connect() {
        let normalizedHost = host
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedHost.isEmpty, normalizedHost != "100.x.y.z" else {
            connectionAlert = ConnectionAlert(
                title: "Mac Address Needed",
                message: "Enter the real Tailscale address shown in BerryCam Mac, for example 100.119.92.102."
            )
            return
        }

        host = normalizedHost
        viewer.connect(host: normalizedHost, port: UInt16(port) ?? 3000, accessCode: accessCode)
    }
}

private struct ConnectionAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
