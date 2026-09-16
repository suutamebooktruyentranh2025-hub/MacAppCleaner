import Foundation

public struct DiskStorageInfo: Identifiable, Sendable, Codable, Equatable {
    public var id: String { volumeURL.path }
    public let volumeName: String
    public let totalCapacity: Int64
    public let availableCapacity: Int64
    public let volumeURL: URL

    public var usedCapacity: Int64 {
        if totalCapacity <= 0 { return 0 }
        let used = totalCapacity - availableCapacity
        return max(0, min(totalCapacity, used))
    }

    public var usedPercentage: Double {
        guard totalCapacity > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(usedCapacity) / Double(totalCapacity)))
    }

    public var percentString: String {
        String(format: "%.1f%%", usedPercentage * 100.0)
    }

    public var formattedTotal: String {
        ByteCountFormatter.format(bytes: totalCapacity)
    }

    public var formattedAvailable: String {
        ByteCountFormatter.format(bytes: availableCapacity)
    }

    public var formattedUsed: String {
        ByteCountFormatter.format(bytes: usedCapacity)
    }

    public init(
        volumeName: String,
        totalCapacity: Int64,
        availableCapacity: Int64,
        volumeURL: URL
    ) {
        self.volumeName = volumeName
        self.totalCapacity = max(0, totalCapacity)
        self.availableCapacity = max(0, availableCapacity)
        self.volumeURL = volumeURL
    }
}
