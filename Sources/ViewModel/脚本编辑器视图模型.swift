import Foundation
import SwiftUI

/// 脚本编辑器页面视图模型，管理编辑状态、保存、静态检查、格式化、模板插入
@MainActor
final class 脚本编辑器视图模型: ObservableObject {
    /// 当前编辑的脚本
    @Published var 脚本: 脚本模型
    /// 编辑器字体大小
    @Published var 字体大小: CGFloat = 应用常量.编辑器基础字体大小
    /// 静态检查结果
    @Published var 检查结果: 脚本静态检查服务.检查结果?
    /// 格式化提示文本
    @Published var 格式化提示: String?
    /// 是否显示模板选择弹窗
    @Published var 显示模板弹窗 = false
    /// 是否显示代码补全弹窗（工具栏手动触发）
    @Published var 显示补全弹窗 = false
    /// 是否显示重命名弹窗
    @Published var 显示重命名弹窗 = false
    /// 重命名输入
    @Published var 重命名输入 = ""
    /// 保存成功提示
    @Published var 保存提示: String?

    /// 脚本存储服务
    private let 存储: 脚本存储

    /// 初始化
    /// - Parameters:
    ///   - 脚本: 待编辑的脚本
    ///   - 存储: 脚本存储服务
    init(脚本: 脚本模型, 存储: 脚本存储) {
        self.脚本 = 脚本
        self.存储 = 存储
        self.重命名输入 = 脚本.名称
    }

    /// 保存脚本到本地
    func 保存脚本() {
        var 副本 = 脚本
        副本.修改时间 = Date()
        do {
            try 存储.保存脚本(副本)
            脚本 = 副本
            保存提示 = "✅ 已保存"
            // 3秒后清除提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.保存提示 = nil
            }
        } catch {
            保存提示 = "❌ 保存失败：\(error.localizedDescription)"
        }
    }

    /// 执行静态检查
    func 执行静态检查() {
        检查结果 = 脚本静态检查服务.检查(内容: 脚本.内容)
    }

    /// 执行代码格式化
    func 执行格式化() {
        let 结果 = 代码格式化服务.格式化(代码: 脚本.内容)
        if 结果.成功 {
            脚本.内容 = 结果.格式化代码
            格式化提示 = 结果.提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                self?.格式化提示 = nil
            }
        }
    }

    /// 在光标位置插入模板代码（简化处理：追加到末尾并换行）
    /// - Parameter 模板: 选中的代码模板
    func 插入模板(_ 模板: 圈X代码模板) {
        脚本.内容 += "\n" + 模板.代码 + "\n"
    }

    /// 插入代码补全项（追加到末尾，实际编辑器内可通过inputAccessoryView在光标处插入）
    /// - Parameter 补全项: 选中的补全项
    func 插入补全项(_ 补全项: 代码补全项) {
        脚本.内容 += 补全项.插入代码
    }

    /// 重命名脚本
    func 重命名脚本() {
        let 新名称 = 重命名输入.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !新名称.isEmpty else { return }
        do {
            try 存储.重命名脚本(脚本, 新名称: 新名称)
            脚本.名称 = 新名称
            显示重命名弹窗 = false
        } catch {
            保存提示 = "❌ 重命名失败：\(error.localizedDescription)"
        }
    }
}
