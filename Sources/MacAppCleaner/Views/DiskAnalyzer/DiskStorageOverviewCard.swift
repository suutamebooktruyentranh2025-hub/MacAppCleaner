import SwiftUI
import MacAppCleanerKit

struct DiskStorageOverviewCard: View {
    let storageInfo: DiskStorageInfo?
    let scope: DiskAnalyzerViewModel.ScanScope
    var onRefresh: (() -> Void)? = nil

    private var usageGradient: LinearGradient {
        guard let info = storageInfo else {
            return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
        }
        if info.usedPercentage >= 0.90 {
            return LinearGradient(colors: [Color.red, Color.pink], startPoint: .leading, endPoint: .trailing)
        } else if info.usedPercentage >= 0.75 {
            return LinearGradient(colors: [Color.orange, Color.yellow], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .leading, endPoint: .trailing)
        }
    }

    private var statusColor: Color {
        guard let info = storageInfo else { return .blue }
        if info.usedPercentage >= 0.90 {
            return .red
        } else if info.usedPercentage >= 0.75 {
            return .orange
        } else {
            return .blue
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                // Disk Drive Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(statusColor.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(statusColor)
                }

                // Volume Name & Scope
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(storageInfo?.volumeName ?? "Ổ đĩa Macintosh")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("APFS")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                            .foregroundStyle(.secondary)
                    }

                    Text("Phạm vi quét: \(scope.rawValue)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Compact Stat Chips
                if let info = storageInfo {
                    HStack(spacing: 16) {
                        // Used stat
                        VStack(alignment: .trailing, spacing: 1) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 6, height: 6)
                                Text("Đã dùng")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(info.formattedUsed) (\(info.percentString))")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                        }

                        // Free stat
                        VStack(alignment: .trailing, spacing: 1) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text("Còn trống")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                            }
                            Text(info.formattedAvailable)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.green)
                        }

                        // Total stat
                        VStack(alignment: .trailing, spacing: 1) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.secondary)
                                    .frame(width: 6, height: 6)
                                Text("Tổng dung lượng")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                            }
                            Text(info.formattedTotal)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Disk Usage Progress Bar (Gauge)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.14))
                        .frame(height: 7)

                    if let info = storageInfo, info.totalCapacity > 0 {
                        let fillWidth = max(6, geo.size.width * CGFloat(info.usedPercentage))
                        Capsule()
                            .fill(usageGradient)
                            .frame(width: fillWidth, height: 7)
                            .shadow(color: statusColor.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                }
            }
            .frame(height: 7)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
