import FirebaseCore
import FirebaseAppCheck
import OSLog

/// Configures the shared Firebase Apple app used by iOS and Mac.
///
/// Both apps use bundle ID `com.Ficruty.caocap` and a copy of the same
/// `GoogleService-Info.plist`. Do not register a second Firebase Apple app.
enum FirebaseConfiguration {
    private static let logger = Logger(subsystem: "com.caocap.app", category: "Firebase")
    private static let sharedBundleID = "com.Ficruty.caocap"

    static func configure() {
        guard FirebaseApp.app() == nil else {
            logger.warning("Firebase already configured — skipping duplicate call.")
            return
        }

        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            logger.error("GoogleService-Info.plist is missing from the Mac app bundle. Copy the iOS Firebase plist to apps/macos/caocap/caocap/resources/GoogleService-Info.plist. Keep bundle ID com.Ficruty.caocap; do not register a second Firebase Apple app.")
            return
        }

        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        // Explicit DeviceCheck provider; Mac beta access does not require attestation.
        AppCheck.setAppCheckProviderFactory(DeviceCheckProviderFactory())
        #endif
        FirebaseApp.configure()

        let options = FirebaseApp.app()?.options
        let configuredBundleID = options?.bundleID ?? "missing"
        if configuredBundleID != sharedBundleID {
            logger.error("Firebase BUNDLE_ID \(configuredBundleID, privacy: .public) does not match \(self.sharedBundleID, privacy: .public).")
            return
        }

        logger.info("Firebase configured for project \(options?.projectID ?? "unknown", privacy: .public) using the shared Apple app.")
    }
}
