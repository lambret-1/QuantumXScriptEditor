import SwiftUI

/// 应用入口，最低支持iOS14
@main
struct 圈X脚本编辑器App: App {
    var body: some Scene {
        WindowGroup {
            脚本列表页()
                .accentColor(.blue) // 全局强调色，统一导航栏与按钮色调
        }
    }
}
