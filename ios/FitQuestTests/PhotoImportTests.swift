import XCTest
@testable import FitQuest

#if canImport(UIKit)
import UIKit

/// UIKit image decoding only exists on iOS, so these run under `xcodebuild test`, not `swift test`.
final class PhotoImportTests: XCTestCase {
    /// Drawn at 1× so the pixel size is exactly width × height, whatever the simulator's screen scale.
    private func png(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).pngData { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    func testLibraryOrFilePhotoBecomesASmallJPEG() throws {
        let jpeg = try XCTUnwrap(PhotoImport.jpeg(from: png(width: 3000, height: 2000)))
        XCTAssertEqual(Array(jpeg.prefix(2)), [0xFF, 0xD8], "JPEG magic bytes")
        let image = try XCTUnwrap(UIImage(data: jpeg))
        XCTAssertEqual(max(image.size.width, image.size.height), PhotoImport.maxSide, accuracy: 1)
    }

    func testSmallPhotosAreNotEnlarged() throws {
        let image = try XCTUnwrap(PhotoImport.jpeg(from: png(width: 400, height: 300)).flatMap(UIImage.init(data:)))
        XCTAssertEqual(image.size.width, 400, accuracy: 1)
    }

    func testNonImageFilesAreRejected() {
        XCTAssertNil(PhotoImport.jpeg(from: Data("not a photo".utf8)))
    }
}
#endif
