import FirebaseAuth
import Foundation
import Testing
@testable import caocap

struct AuthAccountLinkConflictTests {
    @Test func ownershipCodesAreConflicts() {
        let codes: [AuthErrorCode] = [
            .credentialAlreadyInUse,
            .emailAlreadyInUse,
            .accountExistsWithDifferentCredential
        ]

        for code in codes {
            let error = NSError(domain: AuthErrorDomain, code: code.rawValue)
            #expect(AuthAccountLinkConflict.isExistingOwner(error))
        }
    }

    @Test func unrelatedAuthErrorsAreNotConflicts() {
        let error = NSError(domain: AuthErrorDomain, code: AuthErrorCode.networkError.rawValue)
        #expect(!AuthAccountLinkConflict.isExistingOwner(error))
    }

    @Test func unknownDomainsAreNotConflicts() {
        let error = NSError(domain: "unrelated", code: AuthErrorCode.credentialAlreadyInUse.rawValue)
        #expect(!AuthAccountLinkConflict.isExistingOwner(error))
    }
}
