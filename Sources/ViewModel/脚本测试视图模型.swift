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
    /// 【核心逻辑】点击运行时自动真实请求目标网址获取响应体（有缓存则用缓存），然后注入$response.body执行脚本
    /// 这样脚本中的$response.body就是动态从目标网址获取的真实响应，与圈X真实运行环境一致
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
        // 检查脚本内容是否为空（去除空白后），为空则不执行
        let 清理后脚本 = 脚本内容.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !清理后脚本.isEmpty else {
            测试输出 = "⚠️ 请先在编辑器中输入脚本代码，再运行测试\n"
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
            let 注入代码 = "// [测试注入] 请求体\nif (typeof $request !== 'undefined') { $request.body = \(请求体文本.debugDescription); }\n\n"
            最终脚本 = 注入代码 + 脚本内容
        }

        // 检查缓存：相同网址直接使用缓存，不重复请求
        if let 缓存 = 真实响应体, 响应体来源网址 == 网址, !缓存.isEmpty {
            测试输出 += "⚡ 使用缓存响应体（\(缓存.count)字符），跳过网络请求\n"
            沙箱.执行脚本(代码: 最终脚本, 目标网址: 网址, 请求头: 解析请求头, 请求方法: 方法, 响应体: 缓存)
            return
        }

        // 自动真实请求目标网址获取响应体，获取成功后执行脚本
        测试输出 += "🌐 正在请求目标网址获取真实响应体：\(网址)\n"
        请求真实响应体(网址: 网址, 方法: 方法) { [weak self] 结果 in
            guard let 自身 = self else { return }
            switch 结果 {
            case .success(let 响应体):
                // 缓存响应体供后续使用
                自身.真实响应体 = 响应体
                自身.响应体来源网址 = 网址
                自身.测试输出 += "✅ 获取成功，响应体\(响应体.count)字符（Unicode转义已解码）\n"
                // 用真实响应体执行脚本
                自身.沙箱.执行脚本(代码: 最终脚本, 目标网址: 网址, 请求头: 自身.解析请求头, 请求方法: 方法, 响应体: 响应体)
            case .failure(let 错误):
                自身.测试输出 += "❌ 获取响应体失败：\(错误.localizedDescription)\n"
                自身.测试输出 += "💡 提示：请检查网址是否正确、网络是否连通，或点击\"获取响应体\"按钮手动获取\n"
                自身.正在执行 = false
            }
        }
    }

    // MARK: - 通用网络请求方法

    /// 通用：真实请求目标网址获取响应体（自动完整解码所有JSON转义序列）
    /// - Parameters:
    ///   - 网址: 目标URL
    ///   - 方法: HTTP方法
    ///   - 完成: 完成回调，成功返回解码后的响应体字符串，失败返回错误
    private func 请求真实响应体(网址: String, 方法: String, 完成: @escaping (Result<String, Error>) -> Void) {
        guard let 请求URL = URL(string: 网址) else {
            完成(.failure(NSError(domain: "测试错误", code: -1, userInfo: [NSLocalizedDescriptionKey: "网址格式无效"])))
            return
        }
        var 请求 = URLRequest(url: 请求URL)
        请求.httpMethod = 方法
        请求.allHTTPHeaderFields = 解析请求头
        请求.timeoutInterval = 8 // 8秒超时

        // POST/PUT/PATCH时附加请求体
        if !请求体文本.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
           (方法 == "POST" || 方法 == "PUT" || 方法 == "PATCH") {
            请求.httpBody = 请求体文本.data(using: .utf8)
        }

        let 任务 = URLSession.shared.dataTask(with: 请求) { 数据, 响应, 错误 in
            DispatchQueue.main.async {
                if let 错误 = 错误 {
                    完成(.failure(错误))
                    return
                }
                guard let 数据 = 数据, let 响应体文本 = String(data: 数据, encoding: .utf8) else {
                    完成(.failure(NSError(domain: "测试错误", code: -2, userInfo: [NSLocalizedDescriptionKey: "响应体解析失败（可能是二进制数据）"])))
                    return
                }
                // 完整解码所有JSON转义序列（\uXXXX中文 + \" \\ \/ \n \r \t等）
                let 解码后文本 = 脚本测试视图模型.解码JSON转义(响应体文本)
                完成(.success(解码后文本))
            }
        }
        当前网络任务 = 任务
        任务.resume()
    }

    /// 一键获取真实响应体（手动预获取，缓存结果供后续脚本执行使用）
    /// 复用通用请求方法，获取成功后缓存并显示预览
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

        // 如果缓存的响应体来源网址与当前网址相同，直接使用缓存
        if let 缓存 = 真实响应体, 响应体来源网址 == 网址, !缓存.isEmpty {
            测试输出 = "⚡ 使用缓存响应体（来源：\(网址)），长度\(缓存.count)字符\n"
            return
        }

        正在获取响应体 = true
        测试输出 = "🌐 正在请求真实响应体：\(网址)\n"

        请求真实响应体(网址: 网址, 方法: 请求方法) { [weak self] 结果 in
            guard let 自身 = self else { return }
            自身.正在获取响应体 = false
            switch 结果 {
            case .success(let 响应体):
                自身.真实响应体 = 响应体
                自身.响应体来源网址 = 网址
                自身.测试输出 += "✅ 获取成功！响应体\(响应体.count)字符（Unicode转义已解码）\n"
                自身.测试输出 += "📦 响应体已缓存，执行脚本时将直接使用\n"
                let 预览 = 响应体.count > 200 ? String(响应体.prefix(200)) + "..." : 响应体
                自身.测试输出 += "[响应体预览]\n\(预览)\n"
            case .failure(let 错误):
                自身.测试输出 += "❌ 请求失败：\(错误.localizedDescription)\n"
            }
        }
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

    // MARK: - JSON转义解码

    /// 完整解码JSON字符串中的所有转义序列（包括\uXXXX和其他标准转义）
    /// 处理范围：\uXXXX(Unicode)、\"(双引号)、\\(反斜杠)、\/(正斜杠)、\n(换行)、\r(回车)、\t(制表符)、\b(退格)、\f(换页)
    /// 很多服务器返回的JSON会把中文和特殊字符转义，此方法将其全部还原为可读文本
    /// - Parameter 文本: 含JSON转义的原始字符串
    /// - Returns: 完全解码后的可读字符串
    static func 解码JSON转义(_ 文本: String) -> String {
        var 结果 = 文本
        // 统一匹配所有JSON转义序列：
        // 第一捕获组：普通转义字符（\ " / b f n r t）
        // 第二捕获组：\u后面的4位十六进制数字
        let 模式 = "\\\\(?:([\\\\\"/bfnrt])|u([0-9a-fA-F]{4}))"
        guard let 正则 = try? NSRegularExpression(pattern: 模式, options: []) else {
            return 文本
        }
        let 完整范围 = NSRange(结果.startIndex..., in: 结果)
        // 从后往前替换，避免替换后范围偏移
        let 匹配列表 = 正则.matches(in: 结果, options: [], range: 完整范围).reversed()
        for 匹配 in 匹配列表 {
            guard let 转义范围 = Range(匹配.range, in: 结果) else { continue }
            var 替换字符 = ""
            // 判断是普通转义还是\u转义
            if let 普通范围 = Range(匹配.range(at: 1), in: 结果) {
                let 类型 = String(结果[普通范围])
                switch 类型 {
                case "\\": 替换字符 = "\\"       // 反斜杠
                case "\"": 替换字符 = "\""       // 双引号
                case "/": 替换字符 = "/"          // 正斜杠
                case "b": 替换字符 = "\u{0008}"  // 退格
                case "f": 替换字符 = "\u{000C}"  // 换页
                case "n": 替换字符 = "\n"         // 换行
                case "r": 替换字符 = "\r"         // 回车
                case "t": 替换字符 = "\t"         // 制表符
                default: continue
                }
            } else if let 十六进制范围 = Range(匹配.range(at: 2), in: 结果) {
                // \uXXXX Unicode转义
                let 十六进制 = String(结果[十六进制范围])
                if let 码点 = UInt32(十六进制, radix: 16),
                   let 字符 = UnicodeScalar(码点) {
                    替换字符 = String(Character(字符))
                } else {
                    continue
                }
            } else {
                continue
            }
            结果.replaceSubrange(转义范围, with: 替换字符)
        }
        return 结果
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
