import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var webRTC: HostWebRTCService
    @EnvironmentObject private var signaling: SignalingServer
    @State private var accessCode = "berrycam"
    @State private var portText = "3000"

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                WebRTCVideoView(track: webRTC.localVideoTrack)
                    .opacity(webRTC.localVideoTrack == nil ? 0 : 1)

                if webRTC.localVideoTrack == nil {
                    VStack(spacing: 12) {
                        Image(systemName: "video")
                            .font(.system(size: 54, weight: .semibold))
                        Text("Camera preview")
                            .font(.title2.weight(.bold))
                    }
                    .foregroundStyle(.white.opacity(0.78))
                }
            }
            .frame(width: 760, height: 480)
            .background(Color.black)
            .clipped()

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BerryCam")
                        .font(.largeTitle.weight(.bold))
                    Text("Mac host over WebRTC")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Access code") {
                    SecureField("Access code", text: $accessCode)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                }

                LabeledContent("Port") {
                    TextField("3000", text: $portText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                }

                HStack {
                    Button {
                        start()
                    } label: {
                        Label("Start host", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(signaling.isRunning)

                    Button {
                        stop()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .disabled(!signaling.isRunning)
                }

                Divider()

                StatRow(label: "Signaling", value: signaling.status)
                StatRow(label: "WebRTC", value: webRTC.connectionState)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Use in iPhone app")
                        .font(.headline)
                    ForEach(signaling.urls, id: \.self) { url in
                        Text(url.replacingOccurrences(of: "http://", with: ""))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                Text("For travel, enter the MacBook Tailscale name or 100.x.y.z address in the iPhone app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(24)
            .frame(width: 410, height: 480)
        }
    }

    private func start() {
        let port = UInt16(portText) ?? 3000
        webRTC.startCamera()
        signaling.start(port: port, accessCode: accessCode)
    }

    private func stop() {
        signaling.stop()
        webRTC.stop()
    }
}

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}
