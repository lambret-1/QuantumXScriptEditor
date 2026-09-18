import Foundation
import SwiftUI

/// 脚本列表页视图模型，管理脚本列表的加载、新建、删除等操作
@MainActor
final class 脚本列表视图模型: ObservableObject {
    /// 脚本存储服务
    let 存储: 脚本存储
    /// 是否显示新建脚本弹窗
    @Published var 显示新建弹窗 = false
    /// 新建脚本名称输入
    @Published var 新脚本名称 = ""
    /// 错误提示文本
    @Published var 错误提示: String?

    /// 初始化，注入脚本存储服务
    /// - Parameter 存储: 脚本存储服务，默认新建
    init(存储: 脚本存储 = 脚本存储()) {
        self.存储 = 存储
    }

    /// 新建空白脚本
    func 新建脚本() {
        let 名称 = 新脚本名称.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !名称.isEmpty else {
            错误提示 = "脚本名称不能为空"
            return
        }
        let 默认内容 = "// \(名称)\n// 在这里编写圈X脚本，输入 $ 可唤起代码补全\n\n"
        let 新脚本 = 脚本模型(名称: 名称, 内容: 默认内容)
        do {
            try 存储.保存脚本(新脚本)
            新脚本名称 = ""
            显示新建弹窗 = false
            错误提示 = nil
        } catch {
            错误提示 = error.localizedDescription
        }
    }

    /// 删除指定脚本
    /// - Parameter 脚本: 待删除的脚本
    func 删除脚本(_ 脚本: 脚本模型) {
        do {
            try 存储.删除脚本(脚本)
        } catch {
            错误提示 = error.localizedDescription
        }
    }

    /// 重新加载脚本列表
    func 刷新列表() {
        存储.加载全部脚本()
    }
}
