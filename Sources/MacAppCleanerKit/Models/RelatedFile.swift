import Foundation

public struct RelatedFile: Identifiable, Sendable, Codable {
    public let id: UUID
    public let url: URL
    public let size: Int64
    public let category: FileCategory
    public var isSelectedForDeletion: Bool

    public init(id: UUID = UUID(), url: URL, size: Int64, category: FileCategory, isSelectedForDeletion: Bool = true) {
        self.id = id
        self.url = url
        self.size = size
        self.category = category
        self.isSelectedForDeletion = isSelectedForDeletion
    }
}
