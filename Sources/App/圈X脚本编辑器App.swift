import SwiftUI

/// 应用入口，最低支持iOS14
@main
struct 圈X脚本编辑器App: App {
    var body: some Scene {
        WindowGroup {
            脚本列表页()
                .accentColor(.blue) // 全局强调色，统一导航栏与按钮色调
                .onOpenURL { url in
                    // 处理外部打开的.js文件：读取内容并发送通知给脚本列表页创建新脚本
                    处理外部打开文件(url)
                }
        }
    }

    /// 处理外部打开的文件，读取内容并发送通知
    private func 处理外部打开文件(_ url: URL) {
        // 只处理.js/.mjs/.cjs文件
        let 支持的扩展名 = ["js", "mjs", "cjs"]
        guard 支持的扩展名.contains(url.pathExtension.lowercased()) else { return }

        // 开始访问安全范围资源（App Group或外部文件需要）
        let 是否安全范围 = url.startAccessingSecurityScopedResource()
        defer {
            if 是否安全范围 {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // 读取文件内容（支持UTF-8编码，失败时尝试GBK等其他编码）
        var 文件内容 = ""
        if let 内容 = try? String(contentsOf: url, encoding: .utf8) {
            文件内容 = 内容
        } else if let 数据 = try? Data(contentsOf: url),
                  let 内容 = String(data: 数据, encoding: .utf8) ??
                            String(data: 数据, encoding: .gbk) ??
                            String(data: 数据, encoding: .ascii) {
            文件内容 = 内容
        } else {
            return // 读取失败，直接返回
        }

        // 提取文件名（不含扩展名）
        let 文件名 = url.deletingPathExtension().lastPathComponent

        // 发送通知给脚本列表页，创建新脚本并打开编辑器
        NotificationCenter.default.post(
            name: NSNotification.Name("打开外部JS文件通知"),
            object: nil,
            userInfo: ["文件名": 文件名, "内容": 文件内容]
        )
    }
}
