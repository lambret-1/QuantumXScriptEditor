import SwiftUI
import UIKit

/// iOS系统分享面板（UIActivityViewController）的SwiftUI封装
/// 用于下载IPA完成后弹出分享面板，用户可通过AltStore/TrollStore/文件等方式安装
struct 分享面板视图: UIViewControllerRepresentable {
    /// 要分享的文件URL
    let 文件URL: URL
    /// 分享完成回调（用户选择了某个活动或取消）
    var 完成回调: (() -> Void)?

    func makeUIViewController(context: Context) -> 分享面板容器控制器 {
        let 容器 = 分享面板容器控制器()
        容器.文件URL = 文件URL
        容器.完成回调 = 完成回调
        return 容器
    }

    func updateUIViewController(_ 容器: 分享面板容器控制器, context: Context) {
        // 无需更新
    }
}

/// 分享面板容器控制器，负责present UIActivityViewController
final class 分享面板容器控制器: UIViewController {
    /// 要分享的文件URL
    var 文件URL: URL?
    /// 分享完成回调
    var 完成回调: (() -> Void)?
    /// 是否已弹出分享面板（防止重复弹出）
    private var 已弹出 = false

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        // 【关键修复】设置为overFullScreen，避免sheet卡片背景在活动视图消失后留下空白窗口
        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        modalPresentationStyle = .overFullScreen
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear // 透明背景，只显示系统分享面板
    }

    override func viewDidAppear(_ 动画: Bool) {
        super.viewDidAppear(动画)
        guard !已弹出, let 文件URL = 文件URL else { return }
        已弹出 = true

        let 活动视图控制器 = UIActivityViewController(activityItems: [文件URL], applicationActivities: nil)
        活动视图控制器.completionWithItemsHandler = { [weak self] _, _, _, _ in
            // 先回调让SwiftUI更新状态关闭sheet
            self?.完成回调?()
            // 【关键修复】活动视图消失后，立即dismiss容器自身，避免透明空白窗口残留
            DispatchQueue.main.async {
                self?.dismiss(animated: false)
            }
        }

        // iPad适配：从中间弹出
        if let 弹窗 = 活动视图控制器.popoverPresentationController {
            弹窗.sourceView = view
            弹窗.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            弹窗.permittedArrowDirections = []
        }

        present(活动视图控制器, animated: true)
    }
}

// MARK: - 文本分享视图

/// iOS系统分享面板（文本版），用于分享纯文本内容
struct 分享文本视图: UIViewControllerRepresentable {
    /// 要分享的文本内容
    let 文本: String
    /// 分享完成回调
    var 完成回调: (() -> Void)?

    func makeUIViewController(context: Context) -> 文本分享容器控制器 {
        let 容器 = 文本分享容器控制器()
        容器.文本 = 文本
        容器.完成回调 = 完成回调
        return 容器
    }

    func updateUIViewController(_ 容器: 文本分享容器控制器, context: Context) {
        // 无需更新
    }
}

/// 文本分享面板容器控制器
final class 文本分享容器控制器: UIViewController {
    /// 要分享的文本
    var 文本: String?
    /// 分享完成回调
    var 完成回调: (() -> Void)?
    /// 是否已弹出分享面板（防止重复弹出）
    private var 已弹出 = false

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        // 【关键修复】设置为overFullScreen，避免sheet卡片背景在活动视图消失后留下空白窗口
        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        modalPresentationStyle = .overFullScreen
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear // 透明背景，只显示系统分享面板
    }

    override func viewDidAppear(_ 动画: Bool) {
        super.viewDidAppear(动画)
        guard !已弹出, let 文本 = 文本 else { return }
        已弹出 = true

        let 活动视图控制器 = UIActivityViewController(activityItems: [文本], applicationActivities: nil)
        活动视图控制器.completionWithItemsHandler = { [weak self] _, _, _, _ in
            // 先回调让SwiftUI更新状态关闭sheet
            self?.完成回调?()
            // 【关键修复】活动视图消失后，立即dismiss容器自身，避免透明空白窗口残留
            DispatchQueue.main.async {
                self?.dismiss(animated: false)
            }
        }

        // iPad适配：从中间弹出
        if let 弹窗 = 活动视图控制器.popoverPresentationController {
            弹窗.sourceView = view
            弹窗.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            弹窗.permittedArrowDirections = []
        }

        present(活动视图控制器, animated: true)
    }
}
