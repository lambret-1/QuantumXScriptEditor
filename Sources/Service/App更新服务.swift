import Foundation
import UIKit

/// App更新检测服务，通过GitHub API检测最新Release版本
/// 支持自动检测（启动时每日一次）与手动检测
final class App更新服务 {
    /// GitHub仓库所有者
    private static let 仓库所有者 = "lambret-1"
    /// GitHub仓库名称
    private static let 仓库名称 = "QuantumXScriptEditor"
    /// 最新Release API地址
    private static var 最新版本API: String {
        "https://api.github.com/repos/\(仓库所有者)/\(仓库名称)/releases/latest"
    }
    /// UserDefaults键：上次自动检测时间
    private static let 上次检测时间键 = "App上次自动更新检测时间"
    /// UserDefaults键：忽略的版本号
    private static let 忽略版本键 = "App忽略更新版本号"
    /// 自动检测间隔（秒）：24小时
    private static let 自动检测间隔: TimeInterval = 24 * 60 * 60

    /// 获取当前App版本号（从Info.plist读取）
    static var 当前版本号: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// 检查是否需要自动检测（距离上次检测超过24小时）
    static var 需要自动检测: Bool {
        guard let 上次时间 = UserDefaults.standard.object(forKey: 上次检测时间键) as? Date else {
            return true // 从未检测过
        }
        return Date().timeIntervalSince(上次时间) > 自动检测间隔
    }

    /// 记录本次检测时间
    static func 记录检测时间() {
        UserDefaults.standard.set(Date(), forKey: 上次检测时间键)
    }

    /// 获取被忽略的版本号
    static var 忽略版本号: String? {
        UserDefaults.standard.string(forKey: 忽略版本键)
    }

    /// 设置忽略某个版本
    static func 忽略版本(_ 版本号: String) {
        UserDefaults.standard.set(版本号, forKey: 忽略版本键)
    }

    /// 比较版本号，判断是否有新版本
    /// - Parameters:
    ///   - 最新版本: 最新版本号（如 "0.5.0"）
    ///   - 当前版本: 当前版本号（如 "0.4.0"）
    /// - Returns: 有新版本返回true
    static func 有新版本(最新版本: String, 当前版本: String) -> Bool {
        let 最新组件 = 最新版本.split(separator: ".").compactMap { Int($0) }
        let 当前组件 = 当前版本.split(separator: ".").compactMap { Int($0) }
        let 最大长度 = max(最新组件.count, 当前组件.count)
        for i in 0..<最大长度 {
            let 最新位 = i < 最新组件.count ? 最新组件[i] : 0
            let 当前位 = i < 当前组件.count ? 当前组件[i] : 0
            if 最新位 > 当前位 { return true }
            if 最新位 < 当前位 { return false }
        }
        return false
    }

    /// 检测最新版本（异步网络请求）
    /// - Parameter 完成回调: 检测完成回调，参数为更新信息（nil表示无更新或失败）
    static func 检测最新版本(完成回调: @escaping (App更新模型?) -> Void) {
        guard let url = URL(string: 最新版本API) else {
            完成回调(nil)
            return
        }

        var 请求 = URLRequest(url: url)
        请求.httpMethod = "GET"
        请求.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        请求.timeoutInterval = 10 // 10秒超时，避免长时间等待

        URLSession.shared.dataTask(with: 请求) { 数据, 响应, 错误 in
            DispatchQueue.main.async {
                guard 错误 == nil,
                      let http响应 = 响应 as? HTTPURLResponse,
                      http响应.statusCode == 200,
                      let 数据 = 数据 else {
                    完成回调(nil)
                    return
                }

                guard let json = try? JSONSerialization.jsonObject(with: 数据) as? [String: Any] else {
                    完成回调(nil)
                    return
                }

                // 解析版本标签（如 v0.5.0）
                let 标签 = json["tag_name"] as? String ?? ""
                let 版本号 = 标签.hasPrefix("v") ? String(标签.dropFirst()) : 标签

                // 解析发布说明
                let 发布说明 = json["body"] as? String ?? "暂无更新说明"

                // 解析发布时间
                let 发布时间原始 = json["published_at"] as? String ?? ""
                let 发布时间 = 格式化发布时间(发布时间原始)

                // 解析下载地址（第一个asset）
                var 下载地址 = ""
                if let assets = json["assets"] as? [[String: Any]],
                   let 第一个 = assets.first,
                   let 下载 = 第一个["browser_download_url"] as? String {
                    下载地址 = 下载
                }

                // Release页面地址
                let 页面地址 = json["html_url"] as? String ?? ""

                let 更新信息 = App更新模型(
                    版本号: 版本号,
                    标签: 标签,
                    发布说明: 发布说明,
                    下载地址: 下载地址,
                    页面地址: 页面地址,
                    发布时间: 发布时间
                )
                完成回调(更新信息)
            }
        }.resume()
    }

    /// 格式化GitHub发布时间为可读字符串
    private static func 格式化发布时间(_ 原始: String) -> String {
        let 格式化器 = DateFormatter()
        格式化器.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        guard let 日期 = 格式化器.date(from: 原始) else { return 原始 }
        let 输出格式化器 = DateFormatter()
        输出格式化器.dateFormat = "yyyy-MM-dd"
        return 输出格式化器.string(from: 日期)
    }

    /// 打开下载地址（在Safari中打开）
    static func 打开下载地址(_ 地址: String) {
        guard let url = URL(string: 地址), !地址.isEmpty else { return }
        UIApplication.shared.open(url)
    }

    /// 打开Release页面（在Safari中打开）
    static func 打开Release页面(_ 地址: String) {
        guard let url = URL(string: 地址), !地址.isEmpty else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - IPA下载

    /// 下载IPA文件到临时目录，带进度回调
    /// - Parameters:
    ///   - 下载地址: IPA下载URL
    ///   - 进度回调: 下载进度（0.0~1.0），主线程回调
    ///   - 完成回调: 下载完成回调，参数为本地文件URL（失败时为nil）
    static func 下载IPA(下载地址: String, 进度回调: @escaping (Double) -> Void, 完成回调: @escaping (URL?) -> Void) {
        guard let url = URL(string: 下载地址), !下载地址.isEmpty else {
            完成回调(nil)
            return
        }
        let 下载器 = IPA下载器(进度回调: 进度回调, 完成回调: 完成回调)
        下载器.开始下载(url: url)
        // 持有下载器引用防止被释放
        objc_setAssociatedObject(self, "IPA下载器_\(url.absoluteString.hashValue)", 下载器, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// MARK: - IPA下载器（URLSessionDownloadDelegate实现）

/// IPA文件下载器，处理下载进度与文件保存
final class IPA下载器: NSObject, URLSessionDownloadDelegate {
    /// 进度回调
    private let 进度回调: (Double) -> Void
    /// 完成回调
    private let 完成回调: (URL?) -> Void
    /// 下载会话
    private var 会话: URLSession?

    init(进度回调: @escaping (Double) -> Void, 完成回调: @escaping (URL?) -> Void) {
        self.进度回调 = 进度回调
        self.完成回调 = 完成回调
        super.init()
    }

    /// 开始下载
    func 开始下载(url: URL) {
        let 配置 = URLSessionConfiguration.default
        会话 = URLSession(configuration: 配置, delegate: self, delegateQueue: .main)
        var 请求 = URLRequest(url: url)
        请求.timeoutInterval = 60 // 60秒超时，IPA文件较大
        会话?.downloadTask(with: 请求).resume()
    }

    // MARK: - URLSessionDownloadDelegate

    /// 下载进度更新
    func urlSession(_ 会话: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let 进度 = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        进度回调(min(进度, 1.0))
    }

    /// 下载完成
    func urlSession(_ 会话: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // 检查HTTP状态码
        if let http响应 = downloadTask.response as? HTTPURLResponse,
           http响应.statusCode != 200 {
            完成回调(nil)
            return
        }

        // 将临时文件移动到Caches目录，文件名保留原始名称
        let 文件名 = downloadTask.response?.suggestedFilename ?? "QuantumXScriptEditor.ipa"
        let 目标路径 = FileManager.default.temporaryDirectory.appendingPathComponent(文件名)

        do {
            // 如果目标文件已存在，先删除
            if FileManager.default.fileExists(atPath: 目标路径.path) {
                try FileManager.default.removeItem(at: 目标路径)
            }
            try FileManager.default.moveItem(at: location, to: 目标路径)
            完成回调(目标路径)
        } catch {
            完成回调(nil)
        }
    }

    /// 下载失败
    func urlSession(_ 会话: URLSession, task: URLSessionTask, didCompleteWithError 错误: Error?) {
        if 错误 != nil {
            完成回调(nil)
        }
        会话.invalidateAndCancel()
    }
}
