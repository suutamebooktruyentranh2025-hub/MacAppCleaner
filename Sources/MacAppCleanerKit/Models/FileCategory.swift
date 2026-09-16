import Foundation

public enum FileCategory: String, CaseIterable, Sendable, Codable {
    case application = "Ứng dụng gốc (.app)"
    case applicationSupport = "Application Support"
    case caches = "Bộ nhớ đệm (Caches)"
    case preferences = "Tùy chọn cấu hình (Preferences)"
    case savedState = "Trạng thái đã lưu (Saved State)"
    case containers = "Hộp cát (Containers)"
    case groupContainers = "Group Containers"
    case logs = "Nhật ký (Logs)"
    case webKit = "Dữ liệu WebKit"
    case httpStorages = "HTTP Storages"
    case launchAgents = "Khởi động cùng máy (LaunchAgents)"
    case other = "Tệp tàn dư khác"

    public var iconName: String {
        switch self {
        case .application: return "app.badge"
        case .applicationSupport: return "folder.badge.gearshape"
        case .caches: return "trash"
        case .preferences: return "gearshape"
        case .savedState: return "clock.arrow.circlepath"
        case .containers: return "shippingbox"
        case .groupContainers: return "square.stack.3d.down.right"
        case .logs: return "doc.text"
        case .webKit: return "safari"
        case .httpStorages: return "network"
        case .launchAgents: return "bolt"
        case .other: return "doc"
        }
    }
}
