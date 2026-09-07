import Foundation
import Testing
@testable import caocap

struct DevicePresenceMappingTests {
    @Test func snapshotIgnoresLocalDevice() {
        let local = "local-id"
        let otherSeen = Date(timeIntervalSince1970: 1_700_000_000)
        let devices = DevicePresenceMapping.linkedDevices(
            documents: [
                (id: local, data: ["platform": "ios", "lastSeen": Date()]),
                (id: "mac-id", data: ["platform": "macos", "lastSeen": otherSeen])
            ],
            excluding: local
        )

        #expect(devices.count == 1)
        #expect(devices[0].id == "mac-id")
        #expect(devices[0].platform == "macos")
        #expect(devices[0].lastSeen == otherSeen)
        #expect(devices[0].displayName == "Mac")
    }

    @Test func missingPlatformIsSkipped() {
        let devices = DevicePresenceMapping.linkedDevices(
            documents: [
                (id: "other", data: ["lastSeen": Date()])
            ],
            excluding: "local"
        )
        #expect(devices.isEmpty)
    }

    @Test func recentLastSeenIsJustNow() {
        let now = Date()
        let label = DevicePresenceMapping.lastSeenLabel(
            from: now.addingTimeInterval(-10),
            now: now
        )
        #expect(label == "just now")
    }
}
