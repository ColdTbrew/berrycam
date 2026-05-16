import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var webRTC: HostWebRTCService
    @EnvironmentObject private var signaling: SignalingServer
    @EnvironmentObject private var sleepPreventer: SleepPreventer
    @EnvironmentObject private var detectionStore: DetectionEventStore
    @EnvironmentObject private var catDetection: CatDetectionService
    @State private var accessCode = "berrycam"
    @State private var portText = "3000"
    private let documentationDemoEvents = CatDetectionEventPayload.documentationDemoEvents

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
        .frame(minWidth: 720, minHeight: 480)
    }

    private var sidebar: some View {
        Form {
            Section("Host") {
                Toggle(isOn: Binding(
                    get: { sleepPreventer.isEnabled },
                    set: { sleepPreventer.setEnabled($0) }
                )) {
                    Label("Keep Mac Awake", systemImage: "moon.zzz")
                }

                TextField("Access Code", text: $accessCode)
                    .font(.system(.body, design: .monospaced))

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
                StatusRow(label: "Viewer", value: signaling.viewerStatus)
                StatusRow(label: "Audio", value: webRTC.audioState)
                StatusRow(label: "Sleep", value: sleepPreventer.status)
            }

            Section("Cat AI") {
                Toggle(isOn: $catDetection.isEnabled) {
                    Label("Detect Cats", systemImage: catDetection.isEnabled ? "pawprint.fill" : "pawprint")
                }

                StatusRow(label: "Vision", value: isDocumentationDemo ? "Cat" : catDetection.status)
                StatusRow(label: "Events", value: "\(displayedDetectionEvents.count)")
                StatusRow(label: "Keep", value: detectionStore.retentionSummary)

                if displayedDetectionEvents.isEmpty {
                    Text("Start the host and BerryCam will record cat detections here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(displayedDetectionEvents.prefix(5)) { event in
                        DetectionEventRow(event: event)
                    }
                }
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
        .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 380)
    }

    private var previewPane: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ZStack {
                    if isDocumentationDemo {
                        DocumentationCatVideoScene()
                    } else {
                        CameraPreviewView(session: webRTC.captureSession)
                            .opacity(webRTC.captureSession == nil ? 0 : 1)
                    }

                    if webRTC.captureSession == nil && !isDocumentationDemo {
                        ContentUnavailableView(
                            "Camera Preview",
                            systemImage: "video",
                            description: Text("Choose a camera and start the host.")
                        )
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(width: proxy.size.width, height: max(0, proxy.size.height - 38))
                .background(.black)

                Divider()

                HStack {
                    Label("Use the MacBook Tailscale name or 100.x.y.z address in the iPhone app.", systemImage: "network")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                }
                .font(.footnote)
                .padding(.horizontal, 16)
                .frame(height: 37)
                .background(.bar)
            }
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

    private var displayedDetectionEvents: [CatDetectionEventPayload] {
        isDocumentationDemo ? documentationDemoEvents : detectionStore.events
    }

    private var isDocumentationDemo: Bool {
        ProcessInfo.processInfo.environment["BERRYCAM_DOCS_DEMO"] == "1"
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

private struct DetectionEventRow: View {
    let event: CatDetectionEventPayload

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: event.type == .catMoved ? "figure.walk" : "pawprint")
                .foregroundStyle(event.type == .catMoved ? .orange : .green)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.type.title)
                    .font(.subheadline.weight(.semibold))
                Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(Int(event.confidence * 100))%")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}
