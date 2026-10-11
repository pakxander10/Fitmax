import FirebaseAppCheck
import FirebaseAuth
import FirebaseCore
import OSLog

enum FirebaseSetup {
    private static let log = Logger(subsystem: "com.adharsh.fitquest", category: "firebase")

    /// Returns false when GoogleService-Info.plist is missing (it is gitignored), so a teammate
    /// without it still gets a working app on sample data instead of a launch crash.
    static func configure() -> Bool {
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            log.notice("GoogleService-Info.plist missing; running without Firebase")
            return false
        }
        AppCheck.setAppCheckProviderFactory(providerFactory)
        FirebaseApp.configure()
        return true
    }

    /// Every phone gets a user ID without a sign-up screen.
    static func signInIfNeeded() async {
        guard FirebaseApp.app() != nil, Auth.auth().currentUser == nil else { return }
        do {
            _ = try await Auth.auth().signInAnonymously()
        } catch {
            log.error("Anonymous sign-in failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // Debug builds print a token in the Xcode console; register it under App Check > Manage debug tokens.
    // Release builds need the App Attest capability added in Signing & Capabilities.
    private static var providerFactory: AppCheckProviderFactory {
        #if DEBUG
        AppCheckDebugProviderFactory()
        #else
        AppAttestFactory()
        #endif
    }
}

private final class AppAttestFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        AppAttestProvider(app: app)
    }
}
