#if canImport(UIKit)
import SwiftUI
import UIKit

/// Full-screen system camera. Falls back to the photo library where there is no camera (the simulator).
struct CameraPicker: UIViewControllerRepresentable {
    /// JPEG, downscaled so the upload stays small.
    var onCapture: (Data) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage, let jpeg = image.fqJPEG(maxSide: 1024) {
                parent.onCapture(jpeg)
            } else {
                parent.onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.onCancel() }
    }
}

extension UIImage {
    /// JPEG with the longest side capped at `maxSide`, orientation baked in.
    func fqJPEG(maxSide: CGFloat) -> Data? {
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format)
            .jpegData(withCompressionQuality: 0.8) { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}
#endif
