import Photos
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var viewer: ViewerWebRTCService
    @EnvironmentObject private var recentHosts: RecentHostStore
    @State private var host = ""
    @State private var port = "3000"
    @State private var accessCode = "berrycam"
    @State private var microphoneEnabled = false
    @State private var connectionAlert: ConnectionAlert?
    @State private var isShowingHistory = false
    @State private var isInlineHistoryVisible = true

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
                        connectionToolbarControl
                    }
                }
            }
            .sheet(isPresented: $isShowingHistory) {
                DetectionHistoryView(viewer: viewer)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Host")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                VStack(spacing: 0) {
                TextField("Mac Tailscale host", text: $host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .padding(.vertical, 13)

                    Divider()

                TextField("Port", text: $port)
                    .keyboardType(.numberPad)
                    .padding(.vertical, 13)

                    Divider()

                TextField("Access code", text: $accessCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .padding(.vertical, 13)

                    Divider()

                    Toggle(isOn: $microphoneEnabled) {
                        Label("Microphone", systemImage: microphoneEnabled ? "mic.fill" : "mic.slash.fill")
                    }
                    .padding(.vertical, 11)
                }
                .font(.body)
                .padding(.horizontal, 16)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))

                Text("Use the Mac's Tailscale name or 100.x.y.z address shown in BerryCam Mac.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !recentHosts.hosts.isEmpty {
                    recentHostsView
                }

                Button {
                    connect()
                } label: {
                    Text("Connect")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.top, 8)

                if viewer.connectionState != "Idle" {
                    Text(viewer.connectionState)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var recentHostsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Hosts")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(recentHosts.hosts) { recent in
                    Button {
                        host = recent.host
                        port = String(recent.port)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: recent.host.hasPrefix("100.") ? "network" : "wifi")
                                .foregroundStyle(.secondary)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(recent.displayAddress)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Text(recent.lastUsedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            recentHosts.remove(recent)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }

                    if recent.id != recentHosts.hosts.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var watchingView: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height

            if isLandscape {
                liveVideoPane
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 0) {
                    liveVideoPane
                        .frame(height: portraitVideoHeight(in: proxy.size, showingHistory: isInlineHistoryVisible))
                        .clipped()

                    if isInlineHistoryVisible {
                        Divider()

                        InlineDetectionHistoryView(
                            viewer: viewer,
                            collapseHistory: {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                                    isInlineHistoryVisible = false
                                }
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .background(Color(.systemBackground))
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 28)
                        .onEnded { value in
                            guard !isInlineHistoryVisible, value.translation.height < -44 else { return }
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                                isInlineHistoryVisible = true
                            }
                        }
                )
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: viewer.liveDetectionEvent?.id)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: isInlineHistoryVisible)
    }

    private var liveVideoPane: some View {
        ZStack {
            liveLetterboxColor

            WebRTCVideoView(track: viewer.remoteVideoTrack, letterboxColor: uiLiveLetterboxColor)
                .opacity(viewer.remoteVideoTrack == nil ? 0 : 1)

            if viewer.remoteVideoTrack == nil {
                ContentUnavailableView(
                    "Waiting for Video",
                    systemImage: "video",
                    description: Text("BerryCam is connected and waiting for the Mac camera stream.")
                )
                .foregroundStyle(.white.secondary)
            }

            if let event = viewer.liveDetectionEvent {
                CatDetectionOverlay(event: event)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 72)
                    .padding(.trailing, 16)
                    .padding(.leading, 16)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            VStack {
                Spacer()
                HStack(spacing: 10) {
                    Button {
                        viewer.setMicrophoneEnabled(!viewer.isMicrophoneEnabled)
                    } label: {
                        Label(
                            viewer.isMicrophoneEnabled ? "Mic On" : "Mic Off",
                            systemImage: viewer.isMicrophoneEnabled ? "mic.fill" : "mic.slash.fill"
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(viewer.isMicrophoneEnabled ? .green : .red)

                    Text(viewer.audioState)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.secondary)
                }
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
        .background(liveLetterboxColor)
    }

    private func portraitVideoHeight(in size: CGSize, showingHistory: Bool) -> CGFloat {
        showingHistory ? max(220, size.width * 9 / 16) : size.height
    }

    private var liveLetterboxColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var uiLiveLetterboxColor: UIColor {
        colorScheme == .dark ? .black : .white
    }

    private var connectionToolbarControl: some View {
        HStack(spacing: 9) {
            Button {
                isShowingHistory = true
                viewer.refreshDetectionEvents()
            } label: {
                Image(systemName: "clock")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open cat history")

            Text(viewer.connectionState)
                .font(.caption.weight(.bold))
                .foregroundStyle(statusColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
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
        let selectedPort = UInt16(port) ?? 3000
        recentHosts.record(host: normalizedHost, port: selectedPort)
        viewer.connect(
            host: normalizedHost,
            port: selectedPort,
            accessCode: accessCode,
            microphoneEnabled: microphoneEnabled
        )
    }
}

private struct ConnectionAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct DetectionHistoryView: View {
    @ObservedObject var viewer: ViewerWebRTCService
    @State private var selectedEvent: CatDetectionEventPayload?

    var body: some View {
        NavigationStack {
            Group {
                if viewer.detectionEvents.isEmpty {
                    ContentUnavailableView(
                        "No Cat Events",
                        systemImage: "pawprint",
                        description: Text(viewer.historyState)
                    )
                } else {
                    List(viewer.detectionEvents) { event in
                        Button {
                            selectedEvent = event
                        } label: {
                            DetectionEventCell(event: event, snapshotURL: snapshotURL(for: event))
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewer.deleteDetectionEvent(event)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Cat History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewer.refreshDetectionEvents()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            viewer.refreshDetectionEvents()
        }
        .sheet(item: $selectedEvent) { event in
            SnapshotDetailView(viewer: viewer, events: viewer.detectionEvents, initialEventID: event.id)
        }
    }

    private func snapshotURL(for event: CatDetectionEventPayload) -> URL? {
        guard let filename = event.snapshotFilename else { return nil }
        return viewer.snapshotURL(filename: filename)
    }
}

private struct InlineDetectionHistoryView: View {
    @ObservedObject var viewer: ViewerWebRTCService
    let collapseHistory: () -> Void
    @State private var selectedEvent: CatDetectionEventPayload?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Cat History", systemImage: "clock")
                    .font(.headline.weight(.semibold))

                Spacer()

                Button {
                    viewer.refreshDetectionEvents()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Refresh cat history")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            if viewer.detectionEvents.isEmpty {
                ContentUnavailableView(
                    "No Cat Events",
                    systemImage: "pawprint",
                    description: Text(viewer.historyState)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewer.detectionEvents) { event in
                    Button {
                        selectedEvent = event
                    } label: {
                        DetectionEventCell(event: event, snapshotURL: snapshotURL(for: event))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowSeparatorTint(.black.opacity(0.12))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewer.deleteDetectionEvent(event)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    viewer.refreshDetectionEvents()
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 28)
                        .onEnded { value in
                            guard value.translation.height > 44 else { return }
                            collapseHistory()
                        }
                )
            }
        }
        .task {
            viewer.refreshDetectionEvents()
        }
        .sheet(item: $selectedEvent) { event in
            SnapshotDetailView(viewer: viewer, events: viewer.detectionEvents, initialEventID: event.id)
        }
    }

    private func snapshotURL(for event: CatDetectionEventPayload) -> URL? {
        guard let filename = event.snapshotFilename else { return nil }
        return viewer.snapshotURL(filename: filename)
    }
}

private struct CatDetectionOverlay: View {
    let event: CatDetectionEventPayload

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: event.type == .catMoved ? "figure.walk" : "pawprint.fill")
                .font(.headline)
                .foregroundStyle(event.type == .catMoved ? .orange : .green)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.type == .catMoved ? "Cat movement detected" : "Cat detected")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text("\(Int(event.confidence * 100))% confidence")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: 300)
        .background(.black.opacity(0.74), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
        .accessibilityLabel("Cat detection \(Int(event.confidence * 100)) percent confidence")
    }
}

private struct DetectionEventCell: View {
    let event: CatDetectionEventPayload
    let snapshotURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            snapshot

            VStack(alignment: .leading, spacing: 4) {
                Text(event.type.title)
                    .font(.headline)
                Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(Int(event.confidence * 100))% confidence")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var snapshot: some View {
        if let snapshotURL {
            AsyncImage(url: snapshotURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 74, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: "pawprint")
                .foregroundStyle(.secondary)
                .frame(width: 74, height: 54)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

private struct SnapshotDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewer: ViewerWebRTCService
    let events: [CatDetectionEventPayload]
    let initialEventID: UUID

    @State private var selection: UUID
    @State private var images: [UUID: UIImage] = [:]
    @State private var loadStates: [UUID: String] = [:]
    @State private var saveMessage: String?

    init(viewer: ViewerWebRTCService, events: [CatDetectionEventPayload], initialEventID: UUID) {
        self.viewer = viewer
        self.events = events
        self.initialEventID = initialEventID
        _selection = State(initialValue: initialEventID)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { proxy in
                TabView(selection: $selection) {
                    ForEach(events) { event in
                        SnapshotPageView(
                            event: event,
                            image: images[event.id],
                            loadState: loadStates[event.id] ?? "Loading"
                        )
                        .tag(event.id)
                        .task(id: event.id) {
                            await loadImage(for: event)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .frame(
                        width: proxy.size.width,
                        height: max(1, proxy.size.height - 132),
                        alignment: .center
                    )
                    .padding(.top, 72)
                    .padding(.bottom, 60)
            }

            topControls
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            bottomInfo
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .onChange(of: selection) { _, _ in
            saveMessage = nil
        }
    }

    private var currentEvent: CatDetectionEventPayload? {
        events.first { $0.id == selection } ?? events.first
    }

    private var currentImage: UIImage? {
        guard let currentEvent else { return nil }
        return images[currentEvent.id]
    }

    private var topControls: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2.weight(.bold))
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(.white.opacity(0.12), in: Circle())

            Spacer()

            Button {
                saveImage()
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.title3.weight(.bold))
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(.white.opacity(currentImage == nil ? 0.05 : 0.12), in: Circle())
            .disabled(currentImage == nil)
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
    }

    private var bottomInfo: some View {
        VStack(spacing: 4) {
            if let currentEvent {
                Text(currentEvent.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote.weight(.semibold))
                Text(saveMessage ?? "\(Int(currentEvent.confidence * 100))% confidence")
                    .font(.caption)
                    .foregroundStyle(.white.secondary)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.black.opacity(0.72))
    }

    private func loadImage(for event: CatDetectionEventPayload) async {
        guard images[event.id] == nil else { return }

        guard let filename = event.snapshotFilename else {
            loadStates[event.id] = "No snapshot was saved for this event."
            return
        }

        do {
            let data = try await viewer.snapshotData(filename: filename)
            guard let loadedImage = UIImage(data: data) else {
                loadStates[event.id] = "Could not open this snapshot."
                return
            }
            images[event.id] = loadedImage
            loadStates[event.id] = "Loaded"
        } catch {
            loadStates[event.id] = "Could not load this snapshot."
        }
    }

    private func saveImage() {
        guard let image = currentImage else { return }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in
                    saveMessage = "Photos permission is needed to save."
                }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                Task { @MainActor in
                    saveMessage = success ? "Saved to Photos" : "Save failed"
                }
            }
        }
    }
}

private struct SnapshotPageView: View {
    let event: CatDetectionEventPayload
    let image: UIImage?
    let loadState: String

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "Snapshot",
                    systemImage: "photo",
                    description: Text(loadState)
                )
                .foregroundStyle(.white.secondary)
            }
        }
        .padding(.horizontal, 16)
        .accessibilityLabel("\(event.type.title) snapshot")
    }
}
