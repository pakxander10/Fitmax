import SwiftUI
#if os(iOS)
import SafariServices
#endif

extension View {
    /// Shows a web page in a browser sheet inside the app whenever `url` is set.
    /// Handing links to the system instead failed on device ("Failed to open URL", LaunchServices error 115).
    func webSheet(_ url: Binding<URL?>) -> some View {
        modifier(WebSheet(url: url))
    }
}

private struct WebSheet: ViewModifier {
    @Binding var url: URL?
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .sheet(item: Binding(get: { url.flatMap(WebPage.init) }, set: { url = $0?.url })) { page in
                SafariView(url: page.url).ignoresSafeArea()
            }
            // The in-app browser only takes web addresses; anything else still goes to the system.
            .onChange(of: url) {
                if let url, WebPage(url: url) == nil {
                    openURL(url)
                    self.url = nil
                }
            }
        #else
        content.onChange(of: url) {
            if let url {
                openURL(url)
                self.url = nil
            }
        }
        #endif
    }
}

#if os(iOS)
private struct WebPage: Identifiable {
    let url: URL
    var id: URL { url }

    init?(url: URL) {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        self.url = url
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
#endif
