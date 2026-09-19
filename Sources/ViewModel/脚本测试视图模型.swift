import Foundation
import SwiftUI

/// 测试面板弹窗类型枚举（iOS14兼容：单sheet+枚举）
enum 测试面板弹窗类型: String, Identifiable {
    case 网址管理 = "网址管理"
    case 环境管理 = "环境管理"
    var id: String { rawValue }
}

/// 脚本测试面板视图模型，管理URL输入、请求头、测试环境、沙箱执行
@MainActor
final class 脚本测试视图模型: ObservableObject {
    /// 目标测试URL（默认值，用户首次点击输入框时自动清除）
    @Published var 目标网址 = "https://h5.xxoox20.org/api/init"
    /// 测试输出文本
    @Published var 测试输出 = ""
    /// 是否正在执行测试
    @Published var 正在执行 = false
    /// 当前弹出的弹窗类型（iOS14兼容：单sheet+枚举）
    @Published var 当前弹窗: 测试面板弹窗类型? = nil
    /// 请求头编辑文本（key:value 一行一个）
    @Published var 请求头文本 = ""
    /// 请求体编辑文本（POST/PUT时使用）
    @Published var 请求体文本 = ""
    /// 是否展开请求体编辑区（默认折叠，用户手动展开）
    @Published var 展开请求体 = false
    /// 输出区域是否自动滚动到底部（默认开启）
    @Published var 自动滚动 = true
    /// 输出区域是否自动换行（默认开启）
    @Published var 自动换行 = true
    /// 新建环境名称输入
    @Published var 新环境名称 = ""
    /// 选中的HTTP方法
    @Published var 请求方法 = "GET"
    /// 最后一次执行耗时（秒）
    @Published var 最后耗时: TimeInterval?
    /// 是否显示复制成功提示
    @Published var 显示复制成功 = false
    /// 真实响应体（一键获取后缓存，执行脚本时直接使用，避免脚本中重复网络请求）
    @Published var 真实响应体: String?
    /// 是否正在获取真实响应体
    @Published var 正在获取响应体 = false
    /// 真实响应体来源网址（用于判断缓存是否有效）
    @Published var 响应体来源网址 = ""
    /// 当前网络任务（用于取消获取响应体）
    private var 当前网络任务: URLSessionDataTask?

    /// 可用HTTP方法列表
    let 可用方法 = ["GET", "POST", "PUT", "DELETE", "PATCH"]

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
        沙箱.完成回调 = { [weak self] 耗时 in
            DispatchQueue.main.async {
                self?.正在执行 = false
                self?.最后耗时 = 耗时
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
        最后耗时 = nil
        网址存储.添加网址(网址)

        // 如果有请求体且方法为POST/PUT/PATCH，将请求体注入到脚本中
        var 最终脚本 = 脚本内容
        let 方法 = 请求方法
        if !请求体文本.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
           (方法 == "POST" || 方法 == "PUT" || 方法 == "PATCH") {
            // 在脚本开头注入 $request.body
            let 注入代码 = "// [测试注入] 请求体\nif (typeof $request !== 'undefined') { $request.body = \(请求体文本.debugDescription); }\n\n"
            最终脚本 = 注入代码 + 脚本内容
        }

        沙箱.执行脚本(代码: 最终脚本, 目标网址: 网址, 请求头: 解析请求头, 请求方法: 方法, 响应体: 真实响应体)
    }

    /// 一键获取真实响应体（真实请求目标网址，缓存结果供脚本执行使用）
    /// 【性能优化】预先获取响应体后，脚本直接使用缓存数据，无需在脚本中重复发起网络请求
    func 获取真实响应体() {
        guard !正在获取响应体 else { return }
        let 网址 = 目标网址.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !网址.isEmpty else {
            测试输出 = "❌ 错误：测试网址不能为空\n"
            return
        }
        guard URL(string: 网址) != nil else {
            测试输出 = "❌ 错误：网址格式无效\n"
            return
        }

        // 如果缓存的响应体来源网址与当前网址相同，直接使用缓存，不重复请求
        if let 缓存 = 真实响应体, 响应体来源网址 == 网址, !缓存.isEmpty {
            测试输出 = "⚡ 使用缓存响应体（来源：\(网址)），长度\(缓存.count)字符\n"
            return
        }

        正在获取响应体 = true
        测试输出 = "🌐 正在请求真实响应体：\(网址)\n"

        var 请求 = URLRequest(url: URL(string: 网址)!)
        请求.httpMethod = 请求方法
        请求.allHTTPHeaderFields = 解析请求头
        请求.timeoutInterval = 8 // 8秒超时，平衡响应速度和网络容忍度

        // POST/PUT/PATCH时附加请求体
        if !请求体文本.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
           (请求方法 == "POST" || 请求方法 == "PUT" || 请求方法 == "PATCH") {
            请求.httpBody = 请求体文本.data(using: .utf8)
        }

        let 任务 = URLSession.shared.dataTask(with: 请求) { [weak self] 数据, 响应, 错误 in
            DispatchQueue.main.async {
                guard let 自身 = self else { return }
                自身.正在获取响应体 = false
                自身.当前网络任务 = nil

                if let 错误 = 错误 as? URLError, 错误.code == .cancelled {
                    自身.测试输出 += "⚠️ 请求已取消\n"
                    return
                }
                if let 错误 = 错误 {
                    自身.测试输出 += "❌ 请求失败：\(错误.localizedDescription)\n"
                    return
                }
                guard let http响应 = 响应 as? HTTPURLResponse else {
                    自身.测试输出 += "❌ 无效的服务器响应\n"
                    return
                }
                guard let 数据 = 数据, let 响应体文本 = String(data: 数据, encoding: .utf8) else {
                    自身.测试输出 += "❌ 响应体解析失败（可能是二进制数据）\n"
                    return
                }

                // 缓存响应体
                自身.真实响应体 = 响应体文本
                自身.响应体来源网址 = 网址

                自身.测试输出 += "✅ 获取成功！状态码\(http响应.statusCode)，响应体\(响应体文本.count)字符\n"
                自身.测试输出 += "📦 响应体已缓存，执行脚本时将直接使用\n"
                // 预览前200字符
                let 预览 = 响应体文本.count > 200 ? String(响应体文本.prefix(200)) + "..." : 响应体文本
                自身.测试输出 += "[响应体预览]\n\(预览)\n"
            }
        }
        当前网络任务 = 任务
        任务.resume()
    }

    /// 清除响应体缓存（使用默认模拟数据）
    func 清除响应体缓存() {
        真实响应体 = nil
        响应体来源网址 = ""
        测试输出 += "🗑️ 已清除响应体缓存，将使用默认模拟数据\n"
    }

    /// 取消获取响应体
    func 取消获取响应体() {
        当前网络任务?.cancel()
        当前网络任务 = nil
        正在获取响应体 = false
    }

    /// 停止当前执行
    func 停止执行() {
        guard 正在执行 else { return }
        沙箱.停止执行()
        正在执行 = false
    }

    /// 清空测试输出
    func 清空输出() {
        测试输出 = ""
        最后耗时 = nil
    }

    /// 复制测试输出到剪贴板
    func 复制输出() {
        guard !测试输出.isEmpty else { return }
        UIPasteboard.general.string = 测试输出
        显示复制成功 = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.显示复制成功 = false
        }
    }

    /// 输出文本行数统计
    var 输出行数: Int {
        if 测试输出.isEmpty { return 0 }
        return 测试输出.components(separatedBy: .newlines).count
    }

    /// 分享测试输出（直接弹出系统分享面板，无中间窗口）
    func 分享输出() {
        guard !测试输出.isEmpty else { return }
        分享服务.分享文本(文本: 测试输出)
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
