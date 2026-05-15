import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var webRTC: HostWebRTCService
    @EnvironmentObject private var signaling: SignalingServer
    @State private var accessCode = "berrycam"
    @State private var portText = "3000"

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            previewPane
        }
        .navigationTitle("BerryCam")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if signaling.isRunning {
                    Button {
                        stop()
                    } label: {
                        Label("Stop Host", systemImage: "stop.fill")
                    }
                } else {
                    Button {
                        start()
                    } label: {
                        Label("Start Host", systemImage: "play.fill")
                    }
                }
            }
        }
        .frame(minWidth: 980, minHeight: 620)
    }

    private var sidebar: some View {
        Form {
            Section("Host") {
                SecureField("Access Code", text: $accessCode)
                    .textContentType(.password)

                TextField("Port", text: $portText)
                    .monospacedDigit()
                    .frame(maxWidth: 120)

                Picker("Camera", selection: $webRTC.selectedCameraID) {
                    ForEach(webRTC.cameraOptions) { camera in
                        Text(camera.name).tag(Optional(camera.id))
                    }
                }
                .disabled(webRTC.localVideoTrack != nil)

                HStack {
                    Button {
                        webRTC.refreshCameraOptions()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }

                    Spacer()

                    if signaling.isRunning {
                        Button(role: .destructive) {
                            stop()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                        }
                    } else {
                        Button {
                            start()
                        } label: {
                            Label("Start", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .buttonStyle(.bordered)
            }

            Section("Status") {
                StatusRow(label: "Signaling", value: signaling.status)
                StatusRow(label: "WebRTC", value: webRTC.connectionState)
            }

            Section("iPhone") {
                if signaling.urls.isEmpty {
                    Text("Start the host to show Tailscale and local addresses.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(signaling.urls, id: \.self) { url in
                        AddressRow(value: url.replacingOccurrences(of: "http://", with: ""))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationSplitViewColumnWidth(min: 320, ideal: 360, max: 420)
    }

    private var previewPane: some View {
        VStack(spacing: 0) {
            ZStack {
                CameraPreviewView(session: webRTC.captureSession)
                    .opacity(webRTC.captureSession == nil ? 0 : 1)

                if webRTC.captureSession == nil {
                    ContentUnavailableView(
                        "Camera Preview",
                        systemImage: "video",
                        description: Text("Choose a camera and start the host.")
                    )
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)

            Divider()

            HStack {
                Label("Use the MacBook Tailscale name or 100.x.y.z address in the iPhone app.", systemImage: "network")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .font(.footnote)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
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

private struct StatusRow: View {
    let label: String
    let value: String

    var body: some View {
        LabeledContent(label) {
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct AddressRow: View {
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: value.hasPrefix("100.") ? "network" : "wifi")
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
