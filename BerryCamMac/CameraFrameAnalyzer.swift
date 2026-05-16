import AVFoundation

protocol CameraFrameAnalyzer: AnyObject {
    func analyze(sampleBuffer: CMSampleBuffer)
}
