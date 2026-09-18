import Foundation
import SwiftUI

/// 脚本测试面板视图模型，管理URL输入、请求头、测试环境、沙箱执行
@MainActor
final class 脚本测试视图模型: ObservableObject {
    /// 目标测试URL
    @Published var 目标网址 = ""
    /// 测试输出文本
    @Published var 测试输出 = ""
    /// 是否正在执行测试
    @Published var 正在执行 = false
    /// 是否显示网址管理弹窗
    @Published var 显示网址管理 = false
    /// 是否显示测试环境管理弹窗
    @Published var 显示环境管理 = false
    /// 请求头编辑文本（key:value 一行一个）
    @Published var 请求头文本 = ""
    /// 新建环境名称输入
    @Published var 新环境名称 = ""

    /// 网址记录存储
    let 网址存储 = 网址记录存储()
    /// 测试环境存储
    let 环境存储 = 测试环境存储()
    /// JS沙箱服务
    private let 沙箱 = 脚本沙箱服务()

    /// 初始化，设置沙箱输出回调
    init() {
        沙箱.输出更新回调 = { [weak self] 输出 in
            DispatchQueue.main.async {
                self?.测试输出 = 输出
            }
        }
        沙箱.完成回调 = { [weak self] in
            DispatchQueue.main.async {
                self?.正在执行 = false
            }
        }
    }

    /// 解析请求头文本为字典
    private var 解析请求头: [String: String] {
        var 字典: [String: String] = [:]
        let 行数组 = 请求头文本.components(separatedBy: .newlines)
        for 行 in 行数组 {
            let 部分 = 行.split(separator: ":", maxSplits: 1)
            guard 部分.count == 2 else { continue }
            let 键 = String(部分[0]).trimmingCharacters(in: .whitespaces)
            let 值 = String(部分[1]).trimmingCharacters(in: .whitespaces)
            guard !键.isEmpty else { continue }
            字典[键] = 值
        }
        return 字典
    }

    /// 执行脚本测试
    /// - Parameter 脚本内容: JS源代码
    func 执行测试(脚本内容: String) {
        guard !正在执行 else { return }
        let 网址 = 目标网址.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !网址.isEmpty else {
            测试输出 = "❌ 错误：测试网址不能为空\n"
            return
        }
        guard URL(string: 网址) != nil else {
            测试输出 = "❌ 错误：网址格式无效，请输入以 http:// 或 https:// 开头的完整网址\n"
            return
        }

        正在执行 = true
        测试输出 = ""
        网址存储.添加网址(网址)

        沙箱.执行脚本(代码: 脚本内容, 目标网址: 网址, 请求头: 解析请求头)
    }

    /// 清空测试输出
    func 清空输出() {
        测试输出 = ""
    }

    /// 应用选中的测试环境
    /// - Parameter 环境: 测试环境模型
    func 应用环境(_ 环境: 测试环境模型) {
        目标网址 = 环境.目标网址
        请求头文本 = 环境.请求头.map { "\($0.key):\($0.value)" }.joined(separator: "\n")
    }

    /// 将当前URL与请求头保存为新环境
    func 保存为新环境() {
        let 名称 = 新环境名称.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !名称.isEmpty else { return }
        let 新环境 = 测试环境模型(环境名称: 名称, 目标网址: 目标网址, 请求头: 解析请求头)
        环境存储.新增环境(新环境)
        新环境名称 = ""
    }
}
