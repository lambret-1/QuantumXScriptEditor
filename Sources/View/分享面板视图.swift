import SwiftUI
import UIKit

/// 系统分享服务，直接从当前最顶层视图控制器弹出 UIActivityViewController
/// 【设计原则】不使用任何中间容器控制器，避免出现多余的透明/全屏窗口
/// 使用方式：分享服务.分享文件(文件URL:) 或 分享服务.分享文本(文本:)
enum 分享服务 {
    /// 分享文件（如IPA、脚本文件）
    /// - Parameters:
    ///   - 文件URL: 要分享的本地文件URL
    ///   - 完成回调: 用户选择活动或取消后回调
    static func 分享文件(文件URL: URL, 完成回调: (() -> Void)? = nil) {
        弹出分享面板(活动项: [文件URL], 完成回调: 完成回调)
    }

    /// 分享纯文本内容（如测试输出、代码片段）
    /// - Parameters:
    ///   - 文本: 要分享的文本字符串
    ///   - 完成回调: 用户选择活动或取消后回调
    static func 分享文本(文本: String, 完成回调: (() -> Void)? = nil) {
        弹出分享面板(活动项: [文本], 完成回调: 完成回调)
    }

    // MARK: - 核心实现

    /// 从顶层视图控制器直接 present 系统分享面板
    private static func 弹出分享面板(活动项: [Any], 完成回调: (() -> Void)?) {
        DispatchQueue.main.async {
            guard let 顶层控制器 = 获取顶层视图控制器() else {
                // 无法获取顶层控制器时直接回调，避免调用方卡死
                完成回调?()
                return
            }

            let 活动视图控制器 = UIActivityViewController(activityItems: 活动项, applicationActivities: nil)
            活动视图控制器.completionWithItemsHandler = { _, _, _, _ in
                // 用户选择了某个活动或取消分享后回调
                完成回调?()
            }

            // iPad适配：从屏幕中间弹出，避免崩溃
            if let 弹窗 = 活动视图控制器.popoverPresentationController {
                弹窗.sourceView = 顶层控制器.view
                弹窗.sourceRect = CGRect(
                    x: 顶层控制器.view.bounds.midX,
                    y: 顶层控制器.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                弹窗.permittedArrowDirections = []
            }

            // 【关键】直接从顶层控制器 present，无中间容器，无多余窗口
            顶层控制器.present(活动视图控制器, animated: true)
        }
    }

    /// 递归获取当前最顶层的视图控制器（沿 presentedViewController 链查找）
    /// - Returns: 最顶层的 UIViewController，获取失败返回 nil
    private static func 获取顶层视图控制器() -> UIViewController? {
        // iOS14兼容：使用 connectedScenes 获取 keyWindow
        guard let 窗口场景 = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return nil
        }
        guard let 窗口 = 窗口场景.windows.first(where: { $0.isKeyWindow }) ?? 窗口场景.windows.first else {
            return nil
        }

        var 顶层控制器 = 窗口.rootViewController
        // 沿 presentedViewController 链递归找到最顶层
        while let 已弹出控制器 = 顶层控制器?.presentedViewController {
            顶层控制器 = 已弹出控制器
        }
        return 顶层控制器
    }
}
