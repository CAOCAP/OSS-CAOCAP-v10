import Foundation

/// Pure capability rule for exposing the on-device Gemma model.
///
/// Apple hardware identifiers are used instead of the marketing OS version:
/// `iPhone16,1` and `iPhone16,2` are the iPhone 15 Pro family, while later
/// identifier generations represent newer iPhones with the required memory
/// and compute floor. iPads use an explicit allowlist so newer A-series iPads
/// never become eligible merely because their identifier generation is newer.
public struct LocalModelDeviceEligibility: Equatable, Sendable {
    public enum DeviceFamily: Equatable, Sendable {
        case phone
        case pad
        case other
    }

    public enum Status: Equatable, Sendable {
        case supported
        case unsupported
    }

    public let status: Status

    public var isSupported: Bool {
        status == .supported
    }

    public static let current = LocalModelDeviceEligibility(
        family: currentDeviceFamily,
        hardwareIdentifier: currentHardwareIdentifier,
        isSimulator: isRunningInSimulator
    )

    public init(
        family: DeviceFamily,
        hardwareIdentifier: String,
        isSimulator: Bool = false
    ) {
        if isSimulator {
            status = .supported
            return
        }

        switch family {
        case .phone:
            guard let components = Self.iPhoneIdentifierComponents(hardwareIdentifier) else {
                status = .unsupported
                return
            }

            let is15ProFamily = components.major == 16
                && (components.minor == 1 || components.minor == 2)
            let isNewerIPhone = components.major >= 17
            status = is15ProFamily || isNewerIPhone ? .supported : .unsupported
        case .pad:
            status = Self.mSeriesIPadIdentifiers.contains(hardwareIdentifier) ? .supported : .unsupported
        case .other:
            status = .unsupported
        }
    }

    /// M-series iPads through the M5 iPad Pro and M4 iPad Air.
    /// Keep this list explicit: identifier generations also contain A-series iPads.
    private static let mSeriesIPadIdentifiers: Set<String> = [
        // M1 iPad Pro and iPad Air
        "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7",
        "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11",
        "iPad13,16", "iPad13,17",
        // M2 iPad Pro and iPad Air
        "iPad14,3", "iPad14,4", "iPad14,5", "iPad14,6",
        "iPad14,8", "iPad14,9", "iPad14,10", "iPad14,11",
        // M3 iPad Air
        "iPad15,3", "iPad15,4", "iPad15,5", "iPad15,6",
        // M4 iPad Pro and iPad Air
        "iPad16,3", "iPad16,4", "iPad16,5", "iPad16,6",
        "iPad16,8", "iPad16,9", "iPad16,10", "iPad16,11",
        // M5 iPad Pro
        "iPad17,1", "iPad17,2", "iPad17,3", "iPad17,4"
    ]

    private static func iPhoneIdentifierComponents(
        _ identifier: String
    ) -> (major: Int, minor: Int)? {
        guard identifier.hasPrefix("iPhone") else { return nil }

        let version = identifier.dropFirst("iPhone".count)
        let parts = version.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let major = Int(parts[0]),
              let minor = Int(parts[1]) else {
            return nil
        }
        return (major, minor)
    }

    private static var currentDeviceFamily: DeviceFamily {
        let identifier = currentHardwareIdentifier
        if identifier.hasPrefix("iPhone") { return .phone }
        if identifier.hasPrefix("iPad") { return .pad }
        return isRunningInSimulator ? .phone : .other
    }

    private static var currentHardwareIdentifier: String {
        #if targetEnvironment(simulator)
        if let simulatedIdentifier = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulatedIdentifier
        }
        #endif

        var systemInfo = utsname()
        uname(&systemInfo)

        return Mirror(reflecting: systemInfo.machine).children.reduce(into: "") { identifier, element in
            guard let byte = element.value as? Int8, byte != 0 else { return }
            identifier.append(Character(UnicodeScalar(UInt8(byte))))
        }
    }

    private static var isRunningInSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
}

/// Resolves persisted model choices against the current device capability.
public enum CoCaptainModelSelectionPolicy {
    public static let cloudModelName = "gemini-3.7-flash"
    public static let localModelName = "gemma-4-local"

    public static func resolvedModelName(
        _ requestedModelName: String?,
        eligibility: LocalModelDeviceEligibility = .current
    ) -> String {
        guard requestedModelName == localModelName else {
            guard let trimmed = requestedModelName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty else {
                return cloudModelName
            }
            return trimmed
        }

        return eligibility.isSupported ? localModelName : cloudModelName
    }
}
