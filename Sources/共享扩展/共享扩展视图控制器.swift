import UIKit
import Social
import MobileCoreServices

/// 共享扩展主视图控制器
/// 继承自SLComposeServiceViewController（iOS标准分享扩展视图控制器）
/// 处理从其他App分享的.js文件，读取内容后通过URL Scheme打开主App导入
@objc(共享扩展视图控制器)
class 共享扩展视图控制器: SLComposeServiceViewController {

    /// 保存读取到的文件内容
    private var 文件内容: String = ""
    /// 保存文件名
    private var 文件名: String = "导入的脚本"

    override func viewDidLoad() {
        super.viewDidLoad()
        // 修改占位符文字
        textView.text = "正在读取文件内容..."
        textView.isEditable = false
        // 修改发布按钮文字为"导入"
        if let 导航栏 = navigationController?.navigationBar,
           let 按钮 = 导航栏.topItem?.rightBarButtonItem {
            按钮.title = "导入"
        }
    }

    override func presentationAnimationDidFinish() {
        super.presentationAnimationDidFinish()
        // 界面显示完成后，处理共享内容
        处理共享内容()
    }

    /// 验证内容是否有效（决定发布按钮是否可点击）
    override func isContentValid() -> Bool {
        return !文件内容.isEmpty
    }

    /// 用户点击"导入"按钮时的处理
    override func didSelectPost() {
        // 保存到剪贴板（主App会读取后清除）
        UIPasteboard.general.string = 文件内容

        // 构造URL Scheme打开主App，传递文件名
        let 编码文件名 = 文件名.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? 文件名
        let urlScheme = "quantumx://import?name=\(编码文件名)"

        // 延迟一小段时间确保剪贴板写入完成，然后打开主App
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let url = URL(string: urlScheme) {
                self.通过响应者链打开URL(url)
            }
            // 完成扩展
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }

    /// 处理共享的内容
    private func 处理共享内容() {
        guard let 扩展项 = extensionContext?.inputItems.first as? NSExtensionItem else {
            textView.text = "无法获取共享内容"
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
                        DispatchQueue.main.async {
                            self.textView.text = "文件读取失败"
                        }
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
                        DispatchQueue.main.async {
                            self.textView.text = "文本读取失败"
                        }
                    }
                }
                break
            }
        }

        if !找到文件 {
            textView.text = "未找到可导入的文件或文本"
        }
    }

    /// 处理文件URL
    private func 处理文件(_ 文件URL: URL) {
        // 只处理.js/.mjs/.cjs/.txt文件
        let 支持的扩展名 = ["js", "mjs", "cjs", "txt"]
        let 扩展名 = 文件URL.pathExtension.lowercased()
        guard 支持的扩展名.contains(扩展名) else {
            DispatchQueue.main.async {
                self.textView.text = "不支持的文件格式：.\(扩展名)\n仅支持 .js / .mjs / .cjs / .txt"
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
        var 读取内容 = ""
        if let 内容 = try? String(contentsOf: 文件URL, encoding: .utf8) {
            读取内容 = 内容
        } else if let 数据 = try? Data(contentsOf: 文件URL),
                  let 内容 = String(data: 数据, encoding: .utf8) ??
                            String(data: 数据, encoding: gbk编码) ??
                            String(data: 数据, encoding: .ascii) {
            读取内容 = 内容
        } else {
            DispatchQueue.main.async {
                self.textView.text = "文件读取失败"
            }
            return
        }

        let 提取文件名 = 文件URL.deletingPathExtension().lastPathComponent
        处理文本内容(读取内容, 文件名: 提取文件名)
    }

    /// 处理文本内容
    private func 处理文本内容(_ 内容: String, 文件名: String) {
        self.文件内容 = 内容
        self.文件名 = 文件名

        DispatchQueue.main.async {
            // 显示文件信息
            let 预览长度 = min(内容.count, 500)
            let 预览 = String(内容.prefix(预览长度))
            self.textView.text = "文件名：\(文件名)\n字符数：\(内容.count)\n\n--- 内容预览 ---\n\(预览)\(内容.count > 500 ? "\n...（已截断）" : "")"
            // 验证内容有效，启用导入按钮
            self.validateContent()
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
        // 备用方案
        let 选择器 = Selector(("openURL:"))
        if UIApplication.shared.responds(to: 选择器) {
            UIApplication.shared.perform(选择器, with: url)
        }
    }
}
