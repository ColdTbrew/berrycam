import Foundation

struct DetectionBoxPayload: Codable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

struct CatDetectionEventPayload: Codable, Identifiable, Hashable {
    var id: UUID
    var timestamp: Date
    var type: CatDetectionEventType
    var confidence: Double
    var boundingBox: DetectionBoxPayload?
    var snapshotFilename: String?
}

enum CatDetectionEventType: String, Codable, CaseIterable {
    case catDetected
    case catMoved

    var title: String {
        switch self {
        case .catDetected:
            return "Cat detected"
        case .catMoved:
            return "Movement"
        }
    }
}
