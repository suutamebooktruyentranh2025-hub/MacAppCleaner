import Foundation

public struct DiskItem: Identifiable, Sendable, Codable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let size: Int64
    public var children: [DiskItem]?
    public let isProtected: Bool
    public let modificationDate: Date?
    public let isHidden: Bool

    public init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        isDirectory: Bool,
        size: Int64,
        children: [DiskItem]? = nil,
        isProtected: Bool = false,
        modificationDate: Date? = nil,
        isHidden: Bool? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.children = children
        self.isProtected = isProtected
        self.modificationDate = modificationDate
        if let explicitHidden = isHidden {
            self.isHidden = explicitHidden
        } else {
            self.isHidden = name.hasPrefix(".")
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, url, name, isDirectory, size, children, isProtected, modificationDate, isHidden
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        url = try container.decode(URL.self, forKey: .url)
        name = try container.decode(String.self, forKey: .name)
        isDirectory = try container.decode(Bool.self, forKey: .isDirectory)
        size = try container.decode(Int64.self, forKey: .size)
        children = try container.decodeIfPresent([DiskItem].self, forKey: .children)
        isProtected = try container.decodeIfPresent(Bool.self, forKey: .isProtected) ?? false
        modificationDate = try container.decodeIfPresent(Date.self, forKey: .modificationDate)
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? name.hasPrefix(".")
    }
}
