import Foundation

public protocol LibraryProvider: Sendable {
    var category: LibraryCategory { get }
    func scanLibraries() async -> [InstalledLibrary]
}
