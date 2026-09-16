import Foundation

public enum AppArchitecture: String, Sendable, Codable {
    case arm64 = "Apple Silicon"
    case intel = "Intel (x86_64)"
    case universal = "Universal 2"
    case unknown = "Không xác định"
}

public struct InstalledApp: Identifiable, Sendable, Codable {
    public let id: UUID
    public let name: String
    public let bundleURL: URL
    public let bundleIdentifier: String?
    public let version: String?
    public let architecture: AppArchitecture
    public let installDate: Date?
    public let appSize: Int64
    public var residualFiles: [RelatedFile]
    public let isSystemApp: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        bundleURL: URL,
        bundleIdentifier: String?,
        version: String?,
        architecture: AppArchitecture = .arm64,
        installDate: Date? = nil,
        appSize: Int64 = 0,
        residualFiles: [RelatedFile] = [],
        isSystemApp: Bool = false
    ) {
        self.id = id
        self.name = name
        self.bundleURL = bundleURL
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.architecture = architecture
        self.installDate = installDate
        self.appSize = appSize
        self.residualFiles = residualFiles
        self.isSystemApp = isSystemApp
    }

    public var totalSize: Int64 {
        appSize + residualFiles.reduce(0) { $0 + $1.size }
    }

    public var selectedSize: Int64 {
        appSize + residualFiles.filter(\.isSelectedForDeletion).reduce(0) { $0 + $1.size }
    }
}
