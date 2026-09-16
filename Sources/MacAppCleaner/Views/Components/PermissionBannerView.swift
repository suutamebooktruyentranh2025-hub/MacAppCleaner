import SwiftUI
import MacAppCleanerKit

struct PermissionBannerView: View {
    @State private var hasFullDiskAccess: Bool = PermissionManager.shared.hasFullDiskAccess()
    @State private var isShowingGuideModal: Bool = false

    var body: some View {
        if !hasFullDiskAccess {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Chưa cấp quyền Truy cập toàn bộ đĩa (Full Disk Access)")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                    Text("Một số ứng dụng bảo mật (App Store, Root) và thư mục Containers cần quyền này để xóa sạch hoàn toàn.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Button {
                    isShowingGuideModal = true
                } label: {
                    Label("Hướng dẫn cấp quyền", systemImage: "questionmark.circle")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    PermissionManager.shared.openFullDiskAccessSettings()
                } label: {
                    Label("Mở Cài đặt", systemImage: "gearshape.fill")
                        .font(.caption.bold())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.orange.opacity(0.25), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .sheet(isPresented: $isShowingGuideModal) {
                PermissionGuideModal()
            }
            .onAppear {
                checkAccess()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                checkAccess()
            }
        }
    }

    private func checkAccess() {
        withAnimation {
            hasFullDiskAccess = PermissionManager.shared.hasFullDiskAccess()
        }
    }
}
