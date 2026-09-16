import SwiftUI
import MacAppCleanerKit

public struct LibraryManagerView: View {
    @Bindable var viewModel: LibraryManagerViewModel

    public init(viewModel: LibraryManagerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HSplitView {
            LibraryListView(viewModel: viewModel)
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)

            LibraryDetailView(viewModel: viewModel)
                .frame(minWidth: 400)
        }
        .task {
            if viewModel.libraries.isEmpty {
                await viewModel.loadLibraries()
            }
        }
    }
}
