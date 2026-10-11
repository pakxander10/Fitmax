import Foundation

/// API keys for the demo build: read from the environment first, then from the gitignored
/// `Secrets.plist` in the app bundle. For release these belong on a backend, not in the app.
enum Secrets {
    static func value(_ name: String, bundle: Bundle = .main) -> String? {
        var value = ProcessInfo.processInfo.environment[name]
        if value?.isEmpty != false,
           let url = bundle.url(forResource: "Secrets", withExtension: "plist"),
           let dict = NSDictionary(contentsOf: url) {
            value = dict[name] as? String
        }
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty, !value.hasPrefix("paste-") else { return nil }
        return value
    }
}
