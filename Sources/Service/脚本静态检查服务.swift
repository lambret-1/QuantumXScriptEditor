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
                return "✅ 静态检查通过（共\(检查项数量)项检查，仅文本规则检查，不保证运行时正常）"
            }
            let 错误数 = 问题列表.filter { $0.级别 == .错误 }.count
            let 警告数 = 问题列表.filter { $0.级别 == .警告 }.count
            let 提示数 = 问题列表.filter { $0.级别 == .提示 }.count
            var 头部 = "📊 检查完成：\(错误数)个错误，\(警告数)个警告，\(提示数)个提示\n"
            头部 += 问题列表.map { 问题 in
                let 级别符号: String
                switch 问题.级别 {
                case .错误: 级别符号 = "❌"
                case .警告: 级别符号 = "⚠️"
                case .提示: 级别符号 = "💡"
                }
                return "\(级别符号) \(问题.描述)\n   修复建议：\(问题.修复建议)"
            }.joined(separator: "\n")
            return 头部
        }
    }

    /// 检查项总数（用于汇总显示）
    private static let 检查项数量 = 16

    /// 执行完整静态检查
    /// - Parameter 内容: JS脚本源代码
    /// - Returns: 检查结果
    static func 检查(内容: String) -> 检查结果 {
        var 问题: [检查问题] = []
        let 行数 = 内容.components(separatedBy: .newlines).count

        // 空脚本直接返回
        guard !内容.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return 检查结果(问题列表: [
                检查问题(级别: .提示, 描述: "脚本内容为空", 修复建议: "请输入脚本代码后再检查")
            ])
        }

        // 超长脚本仅做基础检查，避免性能问题
        guard 行数 <= 应用常量.静态检查最大行数 else {
            return 检查结果(问题列表: [
                检查问题(级别: .提示,
                          描述: "脚本行数超过\(应用常量.静态检查最大行数)行，已跳过深度检查",
                          修复建议: "建议拆分脚本为多个模块，或手动检查关键逻辑")
            ])
        }

        // 基础语法检查
        检查是否缺少Done(内容, 追加到: &问题)
        检查括号匹配(内容, 追加到: &问题)
        检查引号配对(内容, 追加到: &问题)
        检查Done重复调用(内容, 追加到: &问题)

        // 圈X专项检查
        检查圈XAPI误用(内容, 追加到: &问题)
        检查响应体存在性(内容, 追加到: &问题)
        检查JSONParse安全(内容, 追加到: &问题)
        检查异步回调Done(内容, 追加到: &问题)
        检查Notify参数(内容, 追加到: &问题)
        检查敏感信息硬编码(内容, 追加到: &问题)

        // 代码质量检查
        检查IIFE包裹(内容, 追加到: &问题)
        检查严格相等(内容, 追加到: &问题)
        检查分号缺失(内容, 追加到: &问题)
        检查控制台日志(内容, 追加到: &问题)
        检查模板字符串兼容性(内容, 追加到: &问题)
        检查未使用变量(内容, 追加到: &问题)

        return 检查结果(问题列表: 问题)
    }

    // MARK: - 基础语法检查

    /// 检查是否缺少 $done() 调用
    private static func 检查是否缺少Done(_ 内容: String, 追加到 列表: inout [检查问题]) {
        if !内容.contains("$done") {
            列表.append(检查问题(
                级别: .错误,
                描述: "未检测到 $done() 调用",
                修复建议: "圈X脚本必须在执行结束时调用 $done() 或 $done(返回值)，否则请求会卡住不返回。在脚本末尾添加 $done({});"
            ))
        }
    }

    /// 检查 $done 是否被重复调用（可能导致多次返回）
    private static func 检查Done重复调用(_ 内容: String, 追加到 列表: inout [检查问题]) {
        // 统计 $done( 出现次数（排除注释中的）
        let 无注释 = 移除单行注释(内容)
        let 正则 = try? NSRegularExpression(pattern: "\\$done\\s*\\(")
        let 次数 = 正则?.numberOfMatches(in: 无注释, range: NSRange(无注释.startIndex..., in: 无注释)) ?? 0
        if 次数 > 1 {
            列表.append(检查问题(
                级别: .警告,
                描述: "检测到 \(次数) 处 $done() 调用",
                修复建议: "确保每个执行路径只调用一次 $done()，多次调用可能导致重复返回或异常。使用 if/else 分支时注意每个分支都有且仅有一个 $done()"
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
        // 检查反引号（模板字符串）
        let 反引号数 = 无注释.filter { $0 == "`" }.count
        if 反引号数 % 2 != 0 {
            列表.append(检查问题(
                级别: .错误,
                描述: "反引号未配对（共\(反引号数)个，模板字符串）",
                修复建议: "检查模板字符串是否漏写闭合的反引号 `"
            ))
        }
    }

    // MARK: - 圈X专项检查

    /// 检查圈X API误用（Surge API混淆等）
    private static func 检查圈XAPI误用(_ 内容: String, 追加到 列表: inout [检查问题]) {
        // $console.log 是错误写法，圈X中 console 前面不加 $
        if 内容.contains("$console") {
            列表.append(检查问题(
                级别: .错误,
                描述: "检测到 $console，圈X中 console 前面无需加 $",
                修复建议: "将 $console.log 改为 console.log，圈X标准调试输出是 console.log()，不是 $console.log()"
            ))
        }
        // $persistentStore 是 Surge 的API，圈X用 $prefs
        if 内容.contains("$persistentStore") {
            列表.append(检查问题(
                级别: .错误,
                描述: "检测到 $persistentStore，这是 Surge 的API，圈X不支持",
                修复建议: "圈X持久化存储使用 $prefs.setValueForKey(value, key) 和 $prefs.valueForKey(key)，不是 $persistentStore"
            ))
        }
        // $httpClient 是 Surge 的API，圈X用 $task.fetch
        if 内容.contains("$httpClient") {
            列表.append(检查问题(
                级别: .错误,
                描述: "检测到 $httpClient，这是 Surge 的API，圈X不支持",
                修复建议: "圈X网络请求使用 $task.fetch({url:..., method:..., headers:..., body:...})，Promise风格回调，不是 $httpClient"
            ))
        }
        // $argument 是 Surge 的API，圈X用 $environment
        if 内容.contains("$argument") {
            列表.append(检查问题(
                级别: .警告,
                描述: "检测到 $argument，这是 Surge 的API，圈X中使用 $environment",
                修复建议: "圈X获取脚本参数使用 $environment，例如 $environment['key']，不是 $argument"
            ))
        }
    }

    /// 检查响应体脚本是否检查了 $response 存在性
    private static func 检查响应体存在性(_ 内容: String, 追加到 列表: inout [检查问题]) {
        // 只有使用了 $response 的脚本才检查
        guard 内容.contains("$response") else { return }

        // 检查是否有 $response 存在性判断
        let 有存在性检查 = 内容.contains("typeof $response") ||
                          内容.contains("$response ===") ||
                          内容.contains("$response !==") ||
                          内容.contains("$response == null") ||
                          内容.contains("$response != null") ||
                          内容.contains("!$response")

        if !有存在性检查 {
            列表.append(检查问题(
                级别: .警告,
                描述: "使用了 $response 但未检查其是否存在",
                修复建议: "脚本可能挂在请求阶段导致 $response 未定义。添加检查：if (typeof $response === 'undefined' || !$response) { $done({}); return; }"
            ))
        }

        // 检查是否检查了响应体为空
        if 内容.contains("$response.body") && !内容.contains("!body") && !内容.contains("body ===") && !内容.contains("!$response.body") {
            列表.append(检查问题(
                级别: .警告,
                描述: "使用了 $response.body 但未检查响应体是否为空",
                修复建议: "接口可能返回204/304或空响应体。添加检查：var body = $response.body; if (!body) { console.log('响应体为空'); $done({}); return; }"
            ))
        }
    }

    /// 检查 JSON.parse 是否在 try-catch 中
    private static func 检查JSONParse安全(_ 内容: String, 追加到 列表: inout [检查问题]) {
        guard 内容.contains("JSON.parse") else { return }

        // 简单判断：JSON.parse 附近是否有 try
        let 行数组 = 内容.components(separatedBy: .newlines)
        var 有Try = false
        var 括号深度 = 0
        for 行 in 行数组 {
            if 行.contains("try") {
                有Try = true
            }
            括号深度 += 行.filter { $0 == "{" }.count
            括号深度 -= 行.filter { $0 == "}" }.count
            if 行.contains("JSON.parse") && 有Try && 括号深度 > 0 {
                return // 找到了在try-catch中的JSON.parse
            }
        }

        列表.append(检查问题(
            级别: .警告,
            描述: "JSON.parse 未包裹在 try-catch 中",
            修复建议: "响应体可能不是合法JSON（如HTML错误页），JSON.parse会抛异常导致脚本崩溃。用 try { var obj = JSON.parse(body); } catch(e) { console.log('解析失败:'+e); $done({body: body}); }"
        ))
    }

    /// 检查异步请求回调内是否调用了 $done
    private static func 检查异步回调Done(_ 内容: String, 追加到 列表: inout [检查问题]) {
        // 圈X使用 $task.fetch，检查Promise回调中是否有$done
        if 内容.contains("$task") {
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
                    描述: "使用了 $task 异步请求，但未在回调内检测到 $done()",
                    修复建议: "$task.fetch是Promise风格，必须在.then()回调中调用$done()。示例：$task.fetch({url:url}).then(resp => { $done({body: resp.body}); }).catch(err => { $done({}); });"
                ))
            }
        }
    }

    /// 检查 $notify 调用参数是否正确
    private static func 检查Notify参数(_ 内容: String, 追加到 列表: inout [检查问题]) {
        guard 内容.contains("$notify") else { return }

        // 匹配 $notify( 调用，检查参数数量
        let 正则 = try? NSRegularExpression(pattern: "\\$notify\\s*\\(([^)]*)\\)")
        let 匹配列表 = 正则?.matches(in: 内容, range: NSRange(内容.startIndex..., in: 内容)) ?? []
        for 匹配 in 匹配列表 {
            if let 参数范围 = Range(匹配.range(at: 1), in: 内容) {
                let 参数 = String(内容[参数范围])
                let 参数数 = 参数.isEmpty ? 0 : 参数.components(separatedBy: ",").count
                if 参数数 < 2 {
                    列表.append(检查问题(
                        级别: .警告,
                        描述: "$notify 调用参数不足（仅\(参数数)个参数）",
                        修复建议: "$notify(title, subtitle, message, opts) 至少需要2个参数（标题和副标题），完整格式：$notify('标题', '副标题', '详细内容', {})"
                    ))
                }
            }
        }
    }

    /// 检查是否硬编码了敏感信息（token、密码、密钥等）
    private static func 检查敏感信息硬编码(_ 内容: String, 追加到 列表: inout [检查问题]) {
        let 敏感关键词 = ["password", "passwd", "secret", "api_key", "apikey", "private_key", "token =", "token=", "authorization"]
        for 关键词 in 敏感关键词 {
            if 内容.localizedCaseInsensitiveContains(关键词) {
                列表.append(检查问题(
                    级别: .警告,
                    描述: "可能硬编码了敏感信息（包含 \"\(关键词)\"）",
                    修复建议: "避免在脚本中硬编码密码、密钥、Token等敏感信息。建议使用 $prefs 持久化存储，或通过 $environment 从外部传入参数"
                ))
                break // 只提示一次
            }
        }
    }

    // MARK: - 代码质量检查

    /// 检查脚本是否使用 IIFE 包裹（推荐做法）
    private static func 检查IIFE包裹(_ 内容: String, 追加到 列表: inout [检查问题]) {
        let 清理后 = 内容.trimmingCharacters(in: .whitespacesAndNewlines)
        let 以IIFE开头 = 清理后.hasPrefix("(function") || 清理后.hasPrefix("( async") || 清理后.hasPrefix("(()=>") || 清理后.hasPrefix("( () =>")
        if !以IIFE开头 && 内容.contains("$done") {
            列表.append(检查问题(
                级别: .提示,
                描述: "脚本未使用 IIFE（立即执行函数）包裹",
                修复建议: "推荐用 (function() { ... })(); 包裹脚本，避免变量污染全局作用域。这是圈X脚本的标准写法"
            ))
        }
    }

    /// 检查是否使用了 == 而不是 ===（严格相等）
    private static func 检查严格相等(_ 内容: String, 追加到 列表: inout [检查问题]) {
        let 无注释 = 移除单行注释(内容)
        let 无字符串 = 移除字符串和注释(无注释)
        // 匹配 == 但不匹配 ===、!= 但不匹配 !==
        let 正则 = try? NSRegularExpression(pattern: "[^=!]==[^=]|[^=!]!=[^=]")
        let 次数 = 正则?.numberOfMatches(in: 无字符串, range: NSRange(无字符串.startIndex..., in: 无字符串)) ?? 0
        if 次数 > 0 {
            列表.append(检查问题(
                级别: .警告,
                描述: "检测到 \(次数) 处使用了 == 或 !=（非严格相等）",
                修复建议: "推荐使用 === 和 !== 进行严格相等比较，避免类型隐式转换导致的意外结果。例如 if (x === 1) 而不是 if (x == 1)"
            ))
        }
    }

    /// 检查语句末尾是否缺少分号（仅提示，不强制）
    private static func 检查分号缺失(_ 内容: String, 追加到 列表: inout [检查问题]) {
        let 行数组 = 内容.components(separatedBy: .newlines)
        var 缺分号行数 = 0
        for 行 in 行数组 {
            let 清理后 = 行.trimmingCharacters(in: .whitespaces)
            // 跳过空行、注释、以{/}/(/[/,/:/;结尾的行、控制语句行
            guard !清理后.isEmpty,
                  !清理后.hasPrefix("//"),
                  !清理后.hasPrefix("/*"),
                  !清理后.hasPrefix("*"),
                  !清理后.hasPrefix("#"),
                  !清理后.hasSuffix("{"),
                  !清理后.hasSuffix("}"),
                  !清理后.hasSuffix("("),
                  !清理后.hasSuffix("["),
                  !清理后.hasSuffix(","),
                  !清理后.hasSuffix(":"),
                  !清理后.hasSuffix(";"),
                  !清理后.hasSuffix("`"),
                  !清理后.contains("function ") || 清理后.contains("="),
                  !清理后.hasPrefix("if "),
                  !清理后.hasPrefix("for "),
                  !清理后.hasPrefix("while "),
                  !清理后.hasPrefix("else"),
                  !清理后.hasPrefix("try"),
                  !清理后.hasPrefix("catch"),
                  !清理后.hasPrefix("switch"),
                  !清理后.hasPrefix("case "),
                  !清理后.hasPrefix("return ") == false || 清理后.hasSuffix(";")
            else { continue }

            // 检查是否是变量声明或赋值语句
            if 清理后.contains("var ") || 清理后.contains("let ") || 清理后.contains("const ") ||
               清理后.contains(" = ") || 清理后.contains("$done") || 清理后.contains("console.log") ||
               清理后.contains("return ") || 清理后.contains("break") || 清理后.contains("continue") {
                缺分号行数 += 1
            }
        }
        if 缺分号行数 > 3 {
            列表.append(检查问题(
                级别: .提示,
                描述: "约 \(缺分号行数) 行语句末尾可能缺少分号",
                修复建议: "虽然JS有自动分号插入(ASI)机制，但建议在语句末尾显式添加分号，避免换行导致的意外解析错误"
            ))
        }
    }

    /// 检查是否残留 console.log 调试代码
    private static func 检查控制台日志(_ 内容: String, 追加到 列表: inout [检查问题]) {
        if 内容.contains("console.log") {
            let 正则 = try? NSRegularExpression(pattern: "console\\.log")
            let 次数 = 正则?.numberOfMatches(in: 内容, range: NSRange(内容.startIndex..., in: 内容)) ?? 0
            列表.append(检查问题(
                级别: .提示,
                描述: "检测到 \(次数) 处 console.log 调试输出",
                修复建议: "console.log是圈X标准调试写法，会输出到圈X日志。发布前可移除调试代码保持脚本简洁，或保留用于排查问题"
            ))
        }
    }

    /// 检查模板字符串兼容性（旧版JS引擎可能不支持）
    private static func 检查模板字符串兼容性(_ 内容: String, 追加到 列表: inout [检查问题]) {
        if 内容.contains("`") && 内容.contains("${") {
            列表.append(检查问题(
                级别: .提示,
                描述: "使用了模板字符串（反引号+${}插值）",
                修复建议: "模板字符串是ES6特性，圈X的JavaScriptCore引擎支持。但如果脚本需要在其他旧环境运行，建议改用字符串拼接：'变量值：' + 变量"
            ))
        }
    }

    /// 检查声明了但未使用的变量（简单检查）
    private static func 检查未使用变量(_ 内容: String, 追加到 列表: inout [检查问题]) {
        let 无注释 = 移除单行注释(内容)
        let 正则 = try? NSRegularExpression(pattern: "\\b(?:var|let|const)\\s+(\\w+)")
        let 匹配列表 = 正则?.matches(in: 无注释, range: NSRange(无注释.startIndex..., in: 无注释)) ?? []
        var 未使用列表: [String] = []
        for 匹配 in 匹配列表 {
            if let 变量名范围 = Range(匹配.range(at: 1), in: 无注释) {
                let 变量名 = String(无注释[变量名范围])
                // 跳过常见的通用变量名
                guard !["i", "j", "k", "err", "error", "e", "resp", "response", "data", "body", "obj", "result"].contains(变量名) else { continue }
                // 统计变量出现次数（声明+使用）
                let 出现正则 = try? NSRegularExpression(pattern: "\\b\(NSRegularExpression.escapedPattern(for: 变量名))\\b")
                let 出现次数 = 出现正则?.numberOfMatches(in: 无注释, range: NSRange(无注释.startIndex..., in: 无注释)) ?? 0
                if 出现次数 == 1 {
                    未使用列表.append(变量名)
                }
            }
        }
        if !未使用列表.isEmpty {
            列表.append(检查问题(
                级别: .提示,
                描述: "可能声明了未使用的变量：\(未使用列表.prefix(5).joined(separator: "、"))\(未使用列表.count > 5 ? "等" : "")",
                修复建议: "移除未使用的变量声明，保持代码整洁。如果是预留变量，可添加注释说明用途"
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
        // 移除模板字符串
        if let 正则 = try? NSRegularExpression(pattern: "`(?:\\\\.|[^`\\\\])*`") {
            结果 = 正则.stringByReplacingMatches(in: 结果, range: NSRange(结果.startIndex..., in: 结果), withTemplate: "``")
        }
        return 结果
    }

    /// 仅移除单行注释
    private static func 移除单行注释(_ 文本: String) -> String {
        var 结果 = ""
        let 行数组 = 文本.components(separatedBy: .newlines)
        for 行 in 行数组 {
            // 简单处理：找到 // 且不在字符串中（简化处理）
            if let 范围 = 行.range(of: "//") {
                结果 += String(行[..<范围.lowerBound]) + "\n"
            } else {
                结果 += 行 + "\n"
            }
        }
        return 结果
    }
}
