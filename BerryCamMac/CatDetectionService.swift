import AppKit
import AVFoundation
import CoreImage
import Foundation
import Vision

final class CatDetectionService: ObservableObject, CameraFrameAnalyzer {
    @Published var isEnabled = true {
        didSet {
            analysisQueue.async { [weak self, isEnabled] in
                guard let self else { return }
                if !isEnabled {
                    self.previousBox = nil
                }
                Task { @MainActor in
                    self.status = isEnabled ? "Waiting for camera" : "Off"
                }
            }
        }
    }
    @Published private(set) var status = "Waiting for camera"
    @Published private(set) var lastEvent: CatDetectionEventPayload?

    private let store: DetectionEventStore
    private let analysisQueue = DispatchQueue(label: "berrycam.cat.detection", qos: .utility)
    private let ciContext = CIContext()
    private let detectionEventCooldown: TimeInterval = 60
    private let movementEventCooldown: TimeInterval = 15
    private var lastAnalysisAt = Date.distantPast
    private var previousBox: DetectionBoxPayload?
    private var lastDetectedEventAt = Date.distantPast
    private var lastMovedEventAt = Date.distantPast

    init(store: DetectionEventStore) {
        self.store = store
    }

    func analyze(sampleBuffer: CMSampleBuffer) {
        analysisQueue.async { [weak self] in
            guard let self else { return }
            guard self.isEnabled else { return }
            let now = Date()
            guard now.timeIntervalSince(self.lastAnalysisAt) >= 0.5 else { return }
            self.lastAnalysisAt = now

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let request = VNRecognizeAnimalsRequest()

            do {
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
                try handler.perform([request])
                guard let detection = self.bestCatDetection(from: request.results ?? []) else {
                    self.previousBox = nil
                    Task { @MainActor in
                        self.status = "No cat"
                    }
                    return
                }

                self.recordIfNeeded(detection: detection, pixelBuffer: pixelBuffer, now: now)
            } catch {
                Task { @MainActor in
                    self.status = "Vision error"
                }
            }
        }
    }

    private func bestCatDetection(from observations: [VNRecognizedObjectObservation]) -> CatDetection? {
        observations.compactMap { observation -> CatDetection? in
            guard let label = observation.labels.first(where: { $0.identifier.lowercased().contains("cat") }) else {
                return nil
            }
            guard label.confidence >= 0.55 else { return nil }
            let box = DetectionBoxPayload(
                x: observation.boundingBox.origin.x,
                y: observation.boundingBox.origin.y,
                width: observation.boundingBox.width,
                height: observation.boundingBox.height
            )
            return CatDetection(confidence: Double(label.confidence), box: box)
        }
        .max { $0.confidence < $1.confidence }
    }

    private func recordIfNeeded(detection: CatDetection, pixelBuffer: CVPixelBuffer, now: Date) {
        let moved = previousBox.map { detection.box.isMeaningfullyDifferent(from: $0) } ?? false
        previousBox = detection.box

        let type: CatDetectionEventType?
        if moved, now.timeIntervalSince(lastMovedEventAt) >= movementEventCooldown {
            lastMovedEventAt = now
            type = .catMoved
        } else if now.timeIntervalSince(lastDetectedEventAt) >= detectionEventCooldown {
            lastDetectedEventAt = now
            type = .catDetected
        } else {
            type = nil
        }

        Task { @MainActor in
            self.status = "\(Int(detection.confidence * 100))% cat"
        }

        guard let type else { return }
        let snapshot = jpegData(from: pixelBuffer)
        Task { @MainActor in
            self.store.addEvent(
                type: type,
                confidence: detection.confidence,
                boundingBox: detection.box,
                snapshotData: snapshot
            )
            self.lastEvent = self.store.events.first
        }
    }

    private func jpegData(from pixelBuffer: CVPixelBuffer) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.72])
    }
}

private struct CatDetection {
    var confidence: Double
    var box: DetectionBoxPayload
}

private extension DetectionBoxPayload {
    func isMeaningfullyDifferent(from other: DetectionBoxPayload) -> Bool {
        let centerX = x + width / 2
        let centerY = y + height / 2
        let otherCenterX = other.x + other.width / 2
        let otherCenterY = other.y + other.height / 2
        let centerDistance = hypot(centerX - otherCenterX, centerY - otherCenterY)
        let area = width * height
        let otherArea = other.width * other.height
        let areaDelta = abs(area - otherArea)
        return centerDistance > 0.08 || areaDelta > 0.04
    }
}
