import Foundation

final class DetectionEventStore: ObservableObject {
    @Published private(set) var events: [CatDetectionEventPayload] = []

    let maxEventCount = 200
    let retentionDays = 14

    var retentionSummary: String {
        "\(retentionDays) days / \(maxEventCount) latest"
    }

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let baseURL: URL
    private let eventsURL: URL
    private let snapshotsURL: URL
    private var retentionInterval: TimeInterval {
        TimeInterval(retentionDays * 24 * 60 * 60)
    }

    init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        baseURL = appSupport.appending(path: "BerryCam", directoryHint: .isDirectory)
        eventsURL = baseURL.appending(path: "detection-events.json")
        snapshotsURL = baseURL.appending(path: "snapshots", directoryHint: .isDirectory)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        load()
    }

    func addEvent(
        type: CatDetectionEventType,
        confidence: Double,
        boundingBox: DetectionBoxPayload?,
        snapshotData: Data?
    ) {
        let snapshotFilename: String?
        if let snapshotData {
            let filename = "\(UUID().uuidString).jpg"
            snapshotFilename = filename
            try? ensureDirectories()
            try? snapshotData.write(to: snapshotsURL.appending(path: filename), options: [.atomic])
        } else {
            snapshotFilename = nil
        }

        let event = CatDetectionEventPayload(
            id: UUID(),
            timestamp: Date(),
            type: type,
            confidence: confidence,
            boundingBox: boundingBox,
            snapshotFilename: snapshotFilename
        )
        events.insert(event, at: 0)
        pruneExpiredEvents()
        save()
    }

    func snapshotData(filename: String) -> Data? {
        try? Data(contentsOf: snapshotsURL.appending(path: filename))
    }

    func deleteEvent(id: UUID) -> Bool {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return false }
        let event = events.remove(at: index)
        if let filename = event.snapshotFilename {
            try? fileManager.removeItem(at: snapshotsURL.appending(path: filename))
        }
        save()
        return true
    }

    private func load() {
        do {
            try ensureDirectories()
            guard fileManager.fileExists(atPath: eventsURL.path) else { return }
            let data = try Data(contentsOf: eventsURL)
            events = try decoder.decode([CatDetectionEventPayload].self, from: data)
            pruneExpiredEvents()
            save()
        } catch {
            events = []
        }
    }

    private func save() {
        do {
            try ensureDirectories()
            let data = try encoder.encode(events)
            try data.write(to: eventsURL, options: [.atomic])
        } catch {
            // The live stream should keep running even if local history cannot be persisted.
        }
    }

    private func ensureDirectories() throws {
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: snapshotsURL, withIntermediateDirectories: true)
    }

    private func pruneExpiredEvents() {
        let cutoff = Date().addingTimeInterval(-retentionInterval)
        let keptEvents = Array(events.filter { $0.timestamp >= cutoff }.prefix(maxEventCount))
        let keptSnapshots = Set(keptEvents.compactMap(\.snapshotFilename))
        let removedSnapshots = Set(events.compactMap(\.snapshotFilename)).subtracting(keptSnapshots)

        events = keptEvents

        for filename in removedSnapshots {
            try? fileManager.removeItem(at: snapshotsURL.appending(path: filename))
        }
        removeOrphanSnapshots(keeping: keptSnapshots)
    }

    private func removeOrphanSnapshots(keeping keptSnapshots: Set<String>) {
        guard let files = try? fileManager.contentsOfDirectory(
            at: snapshotsURL,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files where !keptSnapshots.contains(file.lastPathComponent) {
            try? fileManager.removeItem(at: file)
        }
    }
}
