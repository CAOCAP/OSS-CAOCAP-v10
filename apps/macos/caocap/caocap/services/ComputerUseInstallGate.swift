import Observation
import OSLog

/// Tracks whether cua-driver is installed and running, so the UI can gate a computer-use
/// attempt on real driver availability instead of hoping for the best.
@MainActor
@Observable
final class ComputerUseInstallGate {
    static let installCommand = "curl -fsSL https://cua.ai/driver/install.sh | sh"

    private(set) var status: ComputerUseDriverStatus?

    @ObservationIgnored
    private let helperClient: ComputerUseHelperClient
    @ObservationIgnored
    private let logger = Logger(subsystem: "com.caocap.app", category: "ComputerUseInstallGate")

    var isReady: Bool {
        status?.installed == true
            && status?.running == true
            && status?.accessibilityGranted == true
            && status?.screenRecordingGranted == true
    }

    init(helperClient: ComputerUseHelperClient) {
        self.helperClient = helperClient
    }

    func refresh() async {
        do {
            status = try await helperClient.status()
        } catch {
            logger.error("Failed to read computer-use driver status: \(error.localizedDescription, privacy: .public)")
            status = ComputerUseDriverStatus(installed: false, running: false, accessibilityGranted: false, screenRecordingGranted: false)
        }
    }

    func requestPermissions() async {
        do {
            try await helperClient.requestPermissions()
        } catch {
            logger.error("Failed to request permissions: \(error.localizedDescription, privacy: .public)")
        }
        await refresh()
    }
}
