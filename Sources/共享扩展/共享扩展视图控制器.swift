import UIKit
import MobileCoreServices

/// 共享扩展主视图控制器
/// 简单的自动导入界面：显示活动指示器，自动读取文件后通过URL Scheme打开主App
/// 不使用SLComposeServiceViewController，避免其复杂的UI和发布按钮逻辑导致卡死
@objc(ShareViewController)
class ShareViewController: UIViewController {

    /// 活动指示器
    private let 活动指示器 = UIActivityIndicatorView(style: .large)
    /// 状态标签
    private let 状态标签 = UILabel()
    /// 超时计时器（防止文件读取卡住导致扩展永远不关闭）
    private var 超时计时器: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        设置界面()
        启动超时保护()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 界面显示完成后，自动处理共享内容
        处理共享内容()
    }

    deinit {
        超时计时器?.invalidate()
    }

    /// 设置界面布局
    private func 设置界面() {
        view.backgroundColor = .systemBackground

        // 活动指示器
        活动指示器.translatesAutoresizingMaskIntoConstraints = false
        活动指示器.startAnimating()
        view.addSubview(活动指示器)

        // 状态标签
        状态标签.translatesAutoresizingMaskIntoConstraints = false
        状态标签.text = "正在导入脚本..."
        状态标签.textAlignment = .center
        状态标签.font = .systemFont(ofSize: 16) // 16pt字号，清晰易读
        状态标签.textColor = .secondaryLabel
        状态标签.numberOfLines = 0 // 允许多行显示错误信息
        view.addSubview(状态标签)

        // 约束
        NSLayoutConstraint.activate([
            活动指示器.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            活动指示器.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20), // 向上偏移20pt，给标签留空间
            状态标签.topAnchor.constraint(equalTo: 活动指示器.bottomAnchor, constant: 16), // 标签在指示器下方16pt
            状态标签.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), // 左右各留20pt边距
            状态标签.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    /// 启动超时保护（10秒后自动关闭，防止卡死）
    private func 启动超时保护() {
        DispatchQueue.main.async {
            self.超时计时器 = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.完成导入(失败原因: "导入超时，请重试")
            }
        }
    }

    /// 停止超时计时器
    private func 停止超时保护() {
        DispatchQueue.main.async {
            self.超时计时器?.invalidate()
            self.超时计时器 = nil
        }
    }

    /// 更新状态文字（确保在主线程执行）
    private func 更新状态(_ 文字: String) {
        DispatchQueue.main.async {
            self.状态标签.text = 文字
        }
    }

    /// 处理共享的内容
    private func 处理共享内容() {
        guard let 扩展项 = extensionContext?.inputItems.first as? NSExtensionItem else {
            完成导入(失败原因: "无法获取共享内容")
            return
        }

        // 遍历附件，查找文件或文本
        var 找到内容 = false
        for 附件 in 扩展项.attachments ?? [] {
            // 【优先级1】检查文件URL（kUTTypeFileURL）
            if 附件.hasItemConformingToTypeIdentifier(kUTTypeFileURL as String) {
                找到内容 = true
                附件.loadItem(forTypeIdentifier: kUTTypeFileURL as String, options: nil) { [weak self] 结果, 错误 in
                    guard let self = self else { return }
                    if let 文件URL = 结果 as? URL {
                        self.处理文件URL(文件URL)
                    } else {
                        self.完成导入(失败原因: "文件读取失败")
                    }
                }
                break
            }
            // 【优先级2】检查文件数据（kUTTypeData）—— 从文件App分享时最常见的类型
            if 附件.hasItemConformingToTypeIdentifier(kUTTypeData as String) {
                找到内容 = true
                附件.loadItem(forTypeIdentifier: kUTTypeData as String, options: nil) { [weak self] 结果, 错误 in
                    guard let self = self else { return }
                    if let 数据 = 结果 as? Data {
                        self.处理文件数据(数据)
                    } else if let 文件URL = 结果 as? URL {
                        // 有时data类型也会返回URL
                        self.处理文件URL(文件URL)
                    } else {
                        self.完成导入(失败原因: "文件数据读取失败")
                    }
                }
                break
            }
            // 【优先级3】检查纯文本（kUTTypePlainText）
            if 附件.hasItemConformingToTypeIdentifier(kUTTypePlainText as String) {
                找到内容 = true
                附件.loadItem(forTypeIdentifier: kUTTypePlainText as String, options: nil) { [weak self] 结果, 错误 in
                    guard let self = self else { return }
                    if let 文本 = 结果 as? String {
                        self.导入完成(内容: 文本, 文件名: "导入的脚本")
                    } else {
                        self.完成导入(失败原因: "文本读取失败")
                    }
                }
                break
            }
        }

        if !找到内容 {
            完成导入(失败原因: "未找到可导入的文件或文本")
        }
    }

    /// 处理文件URL
    private func 处理文件URL(_ 文件URL: URL) {
        // 只处理.js/.mjs/.cjs/.txt文件
        let 支持的扩展名 = ["js", "mjs", "cjs", "txt"]
        let 扩展名 = 文件URL.pathExtension.lowercased()
        guard 支持的扩展名.contains(扩展名) else {
            完成导入(失败原因: "不支持的文件格式：.\(扩展名)")
            return
        }

        // 开始访问安全范围资源
        let 是否安全范围 = 文件URL.startAccessingSecurityScopedResource()
        defer {
            if 是否安全范围 {
                文件URL.stopAccessingSecurityScopedResource()
            }
        }

        // 读取文件内容（支持UTF-8/GBK/ASCII）
        let gbk编码 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        var 读取内容 = ""
        if let 内容 = try? String(contentsOf: 文件URL, encoding: .utf8) {
            读取内容 = 内容
        } else if let 数据 = try? Data(contentsOf: 文件URL),
                  let 内容 = String(data: 数据, encoding: .utf8) ??
                            String(data: 数据, encoding: gbk编码) ??
                            String(data: 数据, encoding: .ascii) {
            读取内容 = 内容
        } else {
            完成导入(失败原因: "文件读取失败")
            return
        }

        let 提取文件名 = 文件URL.deletingPathExtension().lastPathComponent
        导入完成(内容: 读取内容, 文件名: 提取文件名)
    }

    /// 处理文件数据（从kUTTypeData获取的Data）
    private func 处理文件数据(_ 数据: Data) {
        // 从Data中读取文本内容（支持UTF-8/GBK/ASCII）
        let gbk编码 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        guard let 内容 = String(data: 数据, encoding: .utf8) ??
                          String(data: 数据, encoding: gbk编码) ??
                          String(data: 数据, encoding: .ascii) else {
            完成导入(失败原因: "文件数据解析失败")
            return
        }

        导入完成(内容: 内容, 文件名: "导入的脚本")
    }

    /// 导入完成：保存到剪贴板并打开主App
    private func 导入完成(内容: String, 文件名: String) {
        停止超时保护()
        更新状态("正在打开主App...")

        // 保存到剪贴板（主App会读取后清除）
        UIPasteboard.general.string = 内容

        // 构造URL Scheme打开主App，传递文件名
        let 编码文件名 = 文件名.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? 文件名
        let urlScheme = "quantumx://import?name=\(编码文件名)"

        guard let url = URL(string: urlScheme) else {
            完成导入(失败原因: "URL构造失败")
            return
        }

        // 【关键修复】不依赖open的completionHandler（分享扩展中可能不被调用）
        // 先尝试打开主App，无论成功与否，延迟0.5秒后自动关闭扩展
        extensionContext?.open(url)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }

    /// 导入失败：显示错误并延迟关闭
    private func 完成导入(失败原因: String) {
        停止超时保护()
        DispatchQueue.main.async {
            self.状态标签.text = 失败原因
            self.活动指示器.stopAnimating()
        }
        // 显示错误2秒后自动关闭扩展
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}
