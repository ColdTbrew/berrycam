import AVFoundation
import LiveKitWebRTC

final class CameraCaptureController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()

    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "berrycam.camera.capture")
    private weak var delegate: RTCVideoCapturerDelegate?
    weak var frameAnalyzer: CameraFrameAnalyzer?
    private var capturer: RTCVideoCapturer?

    init(delegate: RTCVideoCapturerDelegate) {
        self.delegate = delegate
        self.capturer = RTCVideoCapturer(delegate: delegate)
        super.init()
    }

    func start(device: AVCaptureDevice, completion: @escaping (Error?) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }

            do {
                let input = try AVCaptureDeviceInput(device: device)

                self.session.beginConfiguration()
                self.session.sessionPreset = .hd1280x720
                self.session.inputs.forEach { self.session.removeInput($0) }
                self.session.outputs.forEach { self.session.removeOutput($0) }

                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }

                self.output.alwaysDiscardsLateVideoFrames = true
                self.output.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                self.output.setSampleBufferDelegate(self, queue: self.queue)

                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                }

                self.session.commitConfiguration()
                self.session.startRunning()

                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
            let delegate,
            let capturer
        else { return }

        frameAnalyzer?.analyze(sampleBuffer: sampleBuffer)

        let buffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
        let timestamp = Int64(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1_000_000_000)
        let frame = RTCVideoFrame(buffer: buffer, rotation: ._0, timeStampNs: timestamp)
        delegate.capturer(capturer, didCapture: frame)
    }
}
