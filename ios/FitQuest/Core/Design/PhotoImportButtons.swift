import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// "Library" and "Files" buttons that hand back a photo in the same shape the camera does:
/// a downscaled JPEG. Nothing is saved; the photo goes straight to the caller.
struct PhotoImportButtons: View {
    var onPhoto: (Data) -> Void
    var onError: (String) -> Void

    @State private var libraryItem: PhotosPickerItem?
    @State private var showingFiles = false

    var body: some View {
        HStack(spacing: 12) {
            // The system picker runs outside the app, so no photo-library permission is needed.
            PhotosPicker(selection: $libraryItem, matching: .images) {
                pill("Library", symbol: "photo.on.rectangle")
            }
            Button { showingFiles = true } label: {
                pill("Files", symbol: "folder")
            }
        }
        .buttonStyle(PressStyle())
        .onChange(of: libraryItem) { _, item in loadLibraryItem(item) }
        .fileImporter(isPresented: $showingFiles, allowedContentTypes: [.image]) { result in
            loadFile(result)
        }
    }

    private func pill(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(Theme.caption(14))
            .foregroundStyle(Theme.link)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background { Glossy(shape: Capsule(), fill: Theme.pearlGloss) }
            .overlay(Capsule().strokeBorder(Theme.aqua.opacity(0.6), lineWidth: 1))
            .contentShape(Capsule())
    }

    private func loadLibraryItem(_ item: PhotosPickerItem?) {
        guard let item else { return }
        libraryItem = nil  // so the same photo can be picked again
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    onError(PhotoImport.unreadable)
                    return
                }
                deliver(data)
            } catch {
                onError(PhotoImport.unreadable)
            }
        }
    }

    private func loadFile(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            onError(PhotoImport.unreadable)
            return
        }
        // Files from iCloud Drive and other apps are only readable inside this access window.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            deliver(try Data(contentsOf: url))
        } catch {
            onError(PhotoImport.unreadable)
        }
    }

    private func deliver(_ data: Data) {
        guard let jpeg = PhotoImport.jpeg(from: data) else {
            onError(PhotoImport.unreadable)
            return
        }
        onPhoto(jpeg)
    }
}

enum PhotoImport {
    static let maxSide: CGFloat = 1024
    static let unreadable = "Couldn’t open that photo. Try a different one."

    /// Any image iOS can read (HEIC, PNG, JPEG…) as a JPEG with the long side capped, because the
    /// food analyzer and the scan worker both expect small JPEGs, and HEIC breaks the worker.
    static func jpeg(from data: Data) -> Data? {
        #if canImport(UIKit)
        UIImage(data: data)?.fqJPEG(maxSide: maxSide)
        #else
        nil
        #endif
    }
}
