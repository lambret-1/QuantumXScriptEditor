import SwiftUI

/// GBK编码（Swift标准库未直接提供，需通过CoreFoundation转换获取）
private let gbk编码 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))

/// 应用入口，最低支持iOS14
@main
struct 圈X脚本编辑器App: App {
    var body: some Scene {
        WindowGroup {
            脚本列表页()
                .accentColor(.blue) // 全局强调色，统一导航栏与按钮色调
                .onOpenURL { url in
                    // 判断是文件URL还是自定义URL Scheme
                    if url.scheme == "quantumx" {
                        // 处理共享扩展的导入请求（quantumx://import?name=文件名）
                        处理共享扩展导入(url)
                    } else {
                        // 处理外部打开的.js文件：读取内容并保存到外部导入管理器
                        处理外部打开文件(url)
                    }
                }
        }
    }

    /// 处理外部打开的文件，读取内容并保存到外部导入管理器
    /// 不再使用通知（冷启动时通知可能丢失），改用ObservableObject的@Published让脚本列表页实时观察
    private func 处理外部打开文件(_ url: URL) {
        // 统一支持的扩展名：js/mjs/cjs/txt
        let 支持的扩展名 = ["js", "mjs", "cjs", "txt"]
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
                            String(data: 数据, encoding: gbk编码) ??
                            String(data: 数据, encoding: .ascii) {
            文件内容 = 内容
        } else {
            return // 读取失败，直接返回
        }

        // 提取文件名（不含扩展名）
        let 文件名 = url.deletingPathExtension().lastPathComponent

        // 保存到外部导入管理器，脚本列表页通过@Published实时观察并处理
        外部导入管理器.共享.添加待导入(文件名: 文件名, 内容: 文件内容)
    }

    /// 处理共享扩展的导入请求（quantumx://import?name=文件名）
    /// 共享扩展将文件内容保存到剪贴板，主App读取后创建脚本并清除剪贴板
    private func 处理共享扩展导入(_ url: URL) {
        // 解析文件名参数
        guard let 组件 = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let 查询项 = 组件.queryItems,
              let 文件名项 = 查询项.first(where: { $0.name == "name" }),
              let 文件名 = 文件名项.value else {
            return
        }

        // 读取剪贴板内容（共享扩展写入的文件内容）
        guard let 剪贴板内容 = UIPasteboard.general.string else {
            return
        }

        // 保存到外部导入管理器，脚本列表页通过@Published实时观察并处理
        外部导入管理器.共享.添加待导入(文件名: 文件名, 内容: 剪贴板内容)

        // 延迟1秒清除剪贴板，确保脚本列表页有足够时间读取
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            UIPasteboard.general.string = ""
        }
    }
}
