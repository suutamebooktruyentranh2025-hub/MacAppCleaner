import Foundation

public enum LibraryCategory: String, CaseIterable, Identifiable, Sendable, Equatable, Codable {
    case all = "Tất cả"
    case frameworks = "Frameworks macOS"
    case audioPlugins = "Audio Plugins (VST/AU)"
    case homebrew = "Homebrew"
    case node = "Node.js (npm)"
    case python = "Python (pip)"
    case quickLook = "QuickLook / Panes"
    case aiModels = "AI Models & Cache"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .frameworks: return "shippingbox.fill"
        case .audioPlugins: return "waveform.badge.magnifyingglass"
        case .homebrew: return "mug.fill"
        case .node: return "shippingbox.circle.fill"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .quickLook: return "eye.fill"
        case .aiModels: return "brain.head.profile"
        }
    }
}

public enum LibraryRiskLevel: String, Sendable, Equatable, Codable {
    case safe = "An toàn để xóa"
    case caution = "Cần lưu ý (Có công cụ phụ thuộc)"
    case systemProtected = "Được bảo vệ bởi hệ thống"
}

public struct InstalledLibrary: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public let name: String
    public let version: String?
    public let category: LibraryCategory
    public let installPath: URL
    public let size: Int64
    public let riskLevel: LibraryRiskLevel
    public let dependencies: [String]
    public let requiredBy: [String]
    public let descriptionText: String?
    public let isSystemProtected: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        version: String?,
        category: LibraryCategory,
        installPath: URL,
        size: Int64,
        riskLevel: LibraryRiskLevel,
        dependencies: [String] = [],
        requiredBy: [String] = [],
        descriptionText: String? = nil,
        isSystemProtected: Bool = false
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.category = category
        self.installPath = installPath
        self.size = size
        self.riskLevel = riskLevel
        self.dependencies = dependencies
        self.requiredBy = requiredBy
        self.descriptionText = descriptionText
        self.isSystemProtected = isSystemProtected
    }
}
