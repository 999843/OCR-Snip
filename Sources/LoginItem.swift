import Foundation
import ServiceManagement

/// 开机启动。真相来源是系统的登录项状态，不在本地存一份——
/// 用户随时可能在「系统设置 → 登录项」里直接改，存了必然漂移。
enum LoginItem {
    enum State {
        case off /// 未登记
        case on /// 已启用
        case needsApproval /// 已登记，但要用户在系统设置里亲自批准才真正生效
    }

    static var state: State {
        switch SMAppService.mainApp.status {
        case .enabled: return .on
        case .requiresApproval: return .needsApproval
        default: return .off // notRegistered / notFound
        }
    }

    /// 勾选框的显示状态。待批准也算已登记，所以勾是勾上的。
    static var isEnabled: Bool { state != .off }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// 打开「系统设置 → 通用 → 登录项」。待批准时引导用户过去。
    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
