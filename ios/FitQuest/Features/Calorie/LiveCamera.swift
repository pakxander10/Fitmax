import SwiftUI

#if os(iOS)
import AVFoundation
import UIKit

/// Owns the capture session behind the in-app viewfinder.
@MainActor @Observable
final class CameraModel {
    enum State { case idle, running, unavailable }

    private(set) var state = State.idle

    @ObservationIgnored let session = AVCaptureSession()
    @ObservationIgnored private let output = AVCapturePhotoOutput()
    @ObservationIgnored private let queue = DispatchQueue(label: "fitquest.camera")
    @ObservationIgnored private var configured = false
    @ObservationIgnored private var delegate: PhotoDelegate?

    /// Asks for permission if needed, then starts the live preview. Settles on `.unavailable`
    /// when there is no camera (simulator) or access was denied.
    func start() async {
        guard state != .running else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { state = .unavailable; return }
        default:
            state = .unavailable
            return
        }
        guard configureIfNeeded() else { state = .unavailable; return }
        let session = session
        await withCheckedContinuation { continuation in
            queue.async {
                session.startRunning()
                continuation.resume()
            }
        }
        state = .running
    }

    func stop() {
        guard state == .running else { return }
        state = .idle
        let session = session
        queue.async { session.stopRunning() }
    }

    /// Grabs a still from the running session as a downscaled JPEG.
    func capture() async -> Data? {
        guard state == .running else { return nil }
        return await withCheckedContinuation { continuation in
            let delegate = PhotoDelegate { [weak self] data in
                self?.delegate = nil
                continuation.resume(returning: data)
            }
            self.delegate = delegate
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
        }
    }

    private func configureIfNeeded() -> Bool {
        if configured { return true }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return false }
        session.beginConfiguration()
        session.sessionPreset = .photo
        defer { session.commitConfiguration() }
        guard session.canAddInput(input), session.canAddOutput(output) else { return false }
        session.addInput(input)
        session.addOutput(output)
        configured = true
        return true
    }

    private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
        let done: @MainActor (Data?) -> Void
        init(done: @escaping @MainActor (Data?) -> Void) { self.done = done }

        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            let jpeg = photo.fileDataRepresentation().flatMap(UIImage.init(data:)).flatMap { $0.fqJPEG(maxSide: 1024) }
            Task { @MainActor in done(jpeg) }
        }
    }
}

/// Live camera feed filling its frame.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.layer.session = session
        view.layer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        override var layer: AVCaptureVideoPreviewLayer { super.layer as! AVCaptureVideoPreviewLayer }
    }
}
#else
/// No camera off iOS; the flow falls back to the placeholder.
@MainActor @Observable
final class CameraModel {
    enum State { case idle, running, unavailable }
    private(set) var state = State.unavailable
    func start() async {}
    func stop() {}
    func capture() async -> Data? { nil }
}
#endif
