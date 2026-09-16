import XCTest
@testable import MacAppCleanerKit

final class DiskStorageInfoTests: XCTestCase {
    func testDiskStorageInfoCalculations() {
        let info = DiskStorageInfo(
            volumeName: "Macintosh HD",
            totalCapacity: 500_000_000_000,
            availableCapacity: 100_000_000_000,
            volumeURL: URL(fileURLWithPath: "/")
        )

        XCTAssertEqual(info.volumeName, "Macintosh HD")
        XCTAssertEqual(info.totalCapacity, 500_000_000_000)
        XCTAssertEqual(info.availableCapacity, 100_000_000_000)
        XCTAssertEqual(info.usedCapacity, 400_000_000_000)
        XCTAssertEqual(info.usedPercentage, 0.8, accuracy: 0.001)
        XCTAssertEqual(info.percentString, "80.0%")
        XCTAssertFalse(info.formattedTotal.isEmpty)
        XCTAssertFalse(info.formattedAvailable.isEmpty)
        XCTAssertFalse(info.formattedUsed.isEmpty)
    }

    func testDiskStorageInfoZeroTotalCapacityHandlesGracefully() {
        let info = DiskStorageInfo(
            volumeName: "Empty Volume",
            totalCapacity: 0,
            availableCapacity: 0,
            volumeURL: URL(fileURLWithPath: "/")
        )

        XCTAssertEqual(info.usedCapacity, 0)
        XCTAssertEqual(info.usedPercentage, 0.0)
        XCTAssertEqual(info.percentString, "0.0%")
    }

    func testDiskStorageInfoAvailableLargerThanTotalClampsGracefully() {
        let info = DiskStorageInfo(
            volumeName: "Anomalous Volume",
            totalCapacity: 100,
            availableCapacity: 200,
            volumeURL: URL(fileURLWithPath: "/")
        )

        XCTAssertEqual(info.usedCapacity, 0)
        XCTAssertEqual(info.usedPercentage, 0.0)
    }

    func testGetStorageInfoForRootDirectory() {
        let service = DiskScannerService.shared
        let info = service.getStorageInfo(for: URL(fileURLWithPath: "/"))

        XCTAssertFalse(info.volumeName.isEmpty)
        XCTAssertGreaterThan(info.totalCapacity, 0)
        XCTAssertGreaterThan(info.availableCapacity, 0)
        XCTAssertGreaterThanOrEqual(info.usedCapacity, 0)
        XCTAssertLessThanOrEqual(info.usedCapacity, info.totalCapacity)
        XCTAssertGreaterThanOrEqual(info.usedPercentage, 0.0)
        XCTAssertLessThanOrEqual(info.usedPercentage, 1.0)
    }
}
