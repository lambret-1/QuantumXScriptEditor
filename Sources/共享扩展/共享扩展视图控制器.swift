import UIKit
import MobileCoreServices

/// 共享扩展主视图控制器
/// 处理从其他App分享的.js文件，读取内容后通过URL Scheme打开主App导入
class 共享扩展视图控制器: UIViewController {

    /// 活动指示器（显示正在导入）
    private let 活动指示器 = UIActivityIndicatorView(style: .large)
    /// 提示标签
    private let 提示标签 = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        设置界面()
        处理共享内容()
    }

    /// 设置界面元素
    private func 设置界面() {
        // 活动指示器
        活动指示器.translatesAutoresizingMaskIntoConstraints = false
        活动指示器.startAnimating()
        view.addSubview(活动指示器)

        // 提示标签
        提示标签.translatesAutoresizingMaskIntoConstraints = false
        提示标签.text = "正在导入脚本..."
        提示标签.textAlignment = .center
        提示标签.font = .systemFont(ofSize: 16)
        提示标签.textColor = .secondaryLabel
        view.addSubview(提示标签)

        // 布局约束
        NSLayoutConstraint.activate([
            活动指示器.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            活动指示器.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            提示标签.topAnchor.constraint(equalTo: 活动指示器.bottomAnchor, constant: 16),
            提示标签.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            提示标签.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    /// 处理共享的内容
    private func 处理共享内容() {
        guard let 扩展项 = extensionContext?.inputItems.first as? NSExtensionItem else {
            完成导入(成功: false)
            return
        }

        // 遍历附件，查找文件
        var 找到文件 = false
        for 附件 in 扩展项.attachments ?? [] {
            // 检查是否是文件URL（kUTTypeFileURL）
            if 附件.hasItemConformingToTypeIdentifier: kUTTypeFileURL as String {
                找到文件 = true
                附件.loadItem(forTypeIdentifier: kUTTypeFileURL as String, options: nil) { [weak self] 结果, 错误 in
                    guard let self = self else { return }
                    if let 文件URL = 结果 as? URL {
                        self.处理文件(文件URL)
                    } else {
                        self.完成导入(成功: false)
                    }
                }
                break
            }
            // 检查是否是文本内容
            if 附件.hasItemConformingToTypeIdentifier: kUTTypePlainText as String {
                找到文件 = true
                附件.loadItem(forTypeIdentifier: kUTTypePlainText as String, options: nil) { [weak self] 结果, 错误 in
                    guard let self = self else { return }
                    if let 文本 = 结果 as? String {
                        self.处理文本内容(文本, 文件名: "导入的脚本")
                    } else {
                        self.完成导入(成功: false)
                    }
                }
                break
            }
        }

        if !找到文件 {
            完成导入(成功: false)
        }
    }

    /// 处理文件URL
    private func 处理文件(_ 文件URL: URL) {
        // 只处理.js/.mjs/.cjs/.txt文件
        let 支持的扩展名 = ["js", "mjs", "cjs", "txt"]
        let 扩展名 = 文件URL.pathExtension.lowercased()
        guard 支持的扩展名.contains(扩展名) else {
            DispatchQueue.main.async {
                self.提示标签.text = "不支持的文件格式"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.完成导入(成功: false)
            }
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
        var 文件内容 = ""
        if let 内容 = try? String(contentsOf: 文件URL, encoding: .utf8) {
            文件内容 = 内容
        } else if let 数据 = try? Data(contentsOf: 文件URL),
                  let 内容 = String(data: 数据, encoding: .utf8) ??
                            String(data: 数据, encoding: gbk编码) ??
                            String(data: 数据, encoding: .ascii) {
            文件内容 = 内容
        } else {
            DispatchQueue.main.async {
                self.提示标签.text = "文件读取失败"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.完成导入(成功: false)
            }
            return
        }

        let 文件名 = 文件URL.deletingPathExtension().lastPathComponent
        处理文本内容(文件内容, 文件名: 文件名)
    }

    /// 处理文本内容（保存到剪贴板，打开主App）
    private func 处理文本内容(_ 内容: String, 文件名: String) {
        // 保存到剪贴板（主App会读取后清除）
        UIPasteboard.general.string = 内容

        // 构造URL Scheme打开主App，传递文件名
        let 编码文件名 = 文件名.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? 文件名
        let urlScheme = "quantumx://import?name=\(编码文件名)"

        DispatchQueue.main.async {
            self.提示标签.text = "正在打开圈X脚本编辑器..."
        }

        // 延迟一小段时间确保剪贴板写入完成，然后打开主App
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let url = URL(string: urlScheme) {
                // 通过UIApplication的shared实例打开URL（在扩展中也可以用）
                self.通过响应者链打开URL(url)
            }
            // 延迟完成，让主App有时间启动
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.完成导入(成功: true)
            }
        }
    }

    /// 通过响应者链找到UIApplication并打开URL（Share Extension中没有直接的UIApplication.shared.open）
    private func 通过响应者链打开URL(_ url: URL) {
        var 响应者: UIResponder? = self
        while 响应者 != nil {
            if let 应用 = 响应者 as? UIApplication {
                应用.open(url, options: [:], completionHandler: nil)
                return
            }
            响应者 = 响应者?.next
        }
        // 备用方案：通过selenium调用
        let 选择器 = Selector(("openURL:"))
        if UIApplication.shared.responds(to: 选择器) {
            UIApplication.shared.perform(选择器, with: url)
        }
    }

    /// 完成导入，关闭扩展
    private func 完成导入(成功: Bool) {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
