import Foundation

/// 脚本静态检查服务，基于文本规则扫描常见错误
/// 不执行JS，仅做语法层面的静态分析，附带中文错误解读与修复建议
enum 脚本静态检查服务 {
    /// 单个检查问题项
    struct 检查问题: Identifiable {
        let id = UUID()
        /// 严重级别
        let 级别: 问题级别
        /// 问题描述（中文）
        let 描述: String
        /// 修复建议（中文）
        let 修复建议: String

        /// 问题严重级别
        enum 问题级别 {
            /// 错误，必须修复
            case 错误
            /// 警告，建议修复
            case 警告
            /// 提示，可选优化
            case 提示
        }
    }

    /// 检查结果汇总
    struct 检查结果 {
        /// 是否存在错误级问题
        var 存在错误: Bool { 问题列表.contains { $0.级别 == .错误 } }
        /// 全部问题列表
        let 问题列表: [检查问题]
        /// 汇总描述文本
        var 汇总描述: String {
            if 问题列表.isEmpty {
                return "✅ 静态检查通过（仅文本规则检查，不保证运行时正常）"
            }
            return 问题列表.map { 问题 in
                let 级别符号: String
                switch 问题.级别 {
                case .错误: 级别符号 = "❌"
                case .警告: 级别符号 = "⚠️"
                case .提示: 级别符号 = "💡"
                }
                return "\(级别符号) \(问题.描述)\n   修复建议：\(问题.修复建议)"
            }.joined(separator: "\n")
        }
    }

    /// 执行完整静态检查
    /// - Parameter 内容: JS脚本源代码
    /// - Returns: 检查结果
    static func 检查(内容: String) -> 检查结果 {
        var 问题: [检查问题] = []
        let 行数 = 内容.components(separatedBy: .newlines).count

        // 超长脚本仅做基础检查，避免性能问题
        guard 行数 <= 应用常量.静态检查最大行数 else {
            return 检查结果(问题列表: [
                检查问题(级别: .提示,
                          描述: "脚本行数超过\(应用常量.静态检查最大行数)行，已跳过深度检查",
                          修复建议: "建议拆分脚本为多个模块，或手动检查关键逻辑")
            ])
        }

        检查是否缺少Done(内容, 追加到: &问题)
        检查括号匹配(内容, 追加到: &问题)
        检查异步回调Done(内容, 追加到: &问题)
        检查引号配对(内容, 追加到: &问题)
        检查控制台日志(内容, 追加到: &问题)

        return 检查结果(问题列表: 问题)
    }

    // MARK: - 各项检查规则

    /// 检查是否缺少 $done() 调用
    private static func 检查是否缺少Done(_ 内容: String, 追加到 列表: inout [检查问题]) {
        if !内容.contains("$done") {
            列表.append(检查问题(
                级别: .错误,
                描述: "未检测到 $done() 调用",
                修复建议: "圈X脚本必须在执行结束时调用 $done() 或 $done(返回值)，否则请求会卡住不返回。在脚本末尾添加 $done();"
            ))
        }
    }

    /// 检查大括号与圆括号数量是否匹配
    private static func 检查括号匹配(_ 内容: String, 追加到 列表: inout [检查问题]) {
        // 移除字符串与注释中的括号，避免误判
        let 清理后 = 移除字符串和注释(内容)
        let 左大括号 = 清理后.filter { $0 == "{" }.count
        let 右大括号 = 清理后.filter { $0 == "}" }.count
        if 左大括号 != 右大括号 {
            列表.append(检查问题(
                级别: .错误,
                描述: "大括号不匹配：左括号\(左大括号)个，右括号\(右大括号)个",
                修复建议: "检查函数体、if/for代码块是否漏写 }，通常是嵌套层级少了一个右大括号"
            ))
        }
        let 左圆括号 = 清理后.filter { $0 == "(" }.count
        let 右圆括号 = 清理后.filter { $0 == ")" }.count
        if 左圆括号 != 右圆括号 {
            列表.append(检查问题(
                级别: .错误,
                描述: "圆括号不匹配：左括号\(左圆括号)个，右括号\(右圆括号)个",
                修复建议: "检查函数调用、条件判断是否漏写 )，例如 $done( 缺少右括号"
            ))
        }
        let 左方括号 = 清理后.filter { $0 == "[" }.count
        let 右方括号 = 清理后.filter { $0 == "]" }.count
        if 左方括号 != 右方括号 {
            列表.append(检查问题(
                级别: .错误,
                描述: "方括号不匹配：左括号\(左方括号)个，右括号\(右方括号)个",
                修复建议: "检查数组或对象下标是否漏写 ]"
            ))
        }
    }

    /// 检查异步请求回调内是否调用了 $done
    private static func 检查异步回调Done(_ 内容: String, 追加到 列表: inout [检查问题]) {
        // 若使用了 $httpClient 但 $done 出现在回调外的顶层，可能遗漏
        if 内容.contains("$httpClient") {
            // 简单判断：$done 是否在 function/回调 代码块内
            let 行数组 = 内容.components(separatedBy: .newlines)
            var 回调内有Done = false
            var 括号深度 = 0
            for 行 in 行数组 {
                括号深度 += 行.filter { $0 == "{" }.count
                括号深度 -= 行.filter { $0 == "}" }.count
                if 行.contains("$done") && 括号深度 > 0 {
                    回调内有Done = true
                }
            }
            if !回调内有Done {
                列表.append(检查问题(
                    级别: .警告,
                    描述: "使用了 $httpClient 异步请求，但未在回调内检测到 $done()",
                    修复建议: "异步请求的回调函数内必须调用 $done()，否则脚本会在请求返回前就结束。示例：$httpClient.get(url, {}, function(err, resp) { $done(resp); });"
                ))
            }
        }
    }

    /// 检查引号是否配对（简单统计）
    private static func 检查引号配对(_ 内容: String, 追加到 列表: inout [检查问题]) {
        // 移除注释后统计引号
        let 无注释 = 移除单行注释(内容)
        let 双引号数 = 无注释.filter { $0 == "\"" }.count
        if 双引号数 % 2 != 0 {
            列表.append(检查问题(
                级别: .错误,
                描述: "双引号未配对（共\(双引号数)个）",
                修复建议: "检查字符串是否漏写闭合的双引号，注意中文引号与英文引号不可混用"
            ))
        }
        let 单引号数 = 无注释.filter { $0 == "'" }.count
        if 单引号数 % 2 != 0 {
            列表.append(检查问题(
                级别: .错误,
                描述: "单引号未配对（共\(单引号数)个）",
                修复建议: "检查字符串是否漏写闭合的单引号"
            ))
        }
    }

    /// 检查是否残留 console.log 调试代码
    private static func 检查控制台日志(_ 内容: String, 追加到 列表: inout [检查问题]) {
        if 内容.contains("console.log") {
            列表.append(检查问题(
                级别: .提示,
                描述: "检测到 console.log 调试输出",
                修复建议: "圈X环境中 console.log 不会显示，建议改用 $notify() 弹窗提示，发布前移除调试代码"
            ))
        }
    }

    // MARK: - 辅助方法

    /// 移除文本中的字符串字面量与注释，避免括号统计误判
    private static func 移除字符串和注释(_ 文本: String) -> String {
        var 结果 = 文本
        // 移除块注释
        if let 正则 = try? NSRegularExpression(pattern: "/\\*[\\s\\S]*?\\*/") {
            结果 = 正则.stringByReplacingMatches(in: 结果, range: NSRange(结果.startIndex..., in: 结果), withTemplate: "")
        }
        // 移除单行注释
        结果 = 移除单行注释(结果)
        // 移除双引号字符串
        if let 正则 = try? NSRegularExpression(pattern: "\"(?:\\\\.|[^\"\\\\])*\"") {
            结果 = 正则.stringByReplacingMatches(in: 结果, range: NSRange(结果.startIndex..., in: 结果), withTemplate: "\"\"")
        }
        // 移除单引号字符串
        if let 正则 = try? NSRegularExpression(pattern: "'(?:\\\\.|[^'\\\\])*'") {
            结果 = 正则.stringByReplacingMatches(in: 结果, range: NSRange(结果.startIndex..., in: 结果), withTemplate: "''")
        }
        return 结果
    }

    /// 仅移除单行注释
    private static func 移除单行注释(_ 文本: String) -> String {
        var 结果 = ""
        let 行数组 = 文本.components(separatedBy: .newlines)
        for 行 in 行数组 {
            if let 范围 = 行.range(of: "//") {
                结果 += String(行[..<范围.lowerBound]) + "\n"
            } else {
                结果 += 行 + "\n"
            }
        }
        return 结果
    }
}
