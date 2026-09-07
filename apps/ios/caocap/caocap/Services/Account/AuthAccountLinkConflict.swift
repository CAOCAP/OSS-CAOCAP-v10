import FirebaseAuth
import Foundation

/// Thrown when a provider identity already belongs to another Firebase user.
struct AccountLinkConflict: LocalizedError, Equatable {
    let provider: String

    var errorDescription: String? {
        "This \(provider) account already belongs to another CAOCAP account."
    }
}

/// Detects Firebase link failures that mean the credential has an existing owner.
enum AuthAccountLinkConflict {
    static func isExistingOwner(_ error: NSError) -> Bool {
        guard error.domain == AuthErrorDomain else { return false }
        guard let code = AuthErrorCode(rawValue: error.code) else { return false }
        switch code {
        case .credentialAlreadyInUse, .emailAlreadyInUse, .accountExistsWithDifferentCredential:
            return true
        default:
            return false
        }
    }
}
