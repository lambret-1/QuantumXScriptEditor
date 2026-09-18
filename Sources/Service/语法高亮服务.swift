import Foundation
import UIKit

/// JS语法高亮服务，基于正则匹配实现轻量着色
/// 支持：单行注释、字符串、JS关键字、圈X内置对象
/// 不引入重型JS解析器，保证iOS14设备上的性能
final class 语法高亮服务 {
    /// 对纯文本进行语法高亮，返回富文本
    /// - Parameter 文本: 原始JS源代码
    /// - Returns: 带颜色属性的富文本
    func 高亮(文本: String) -> NSAttributedString {
        let 富文本 = NSMutableAttributedString(string: 文本)
        let 全范围 = NSRange(文本.startIndex..., in: 文本)
        富文本.addAttribute(.foregroundColor, value: 语法颜色.普通文本, range: 全范围)

        // 单行注释（// 开头到行尾，含中文注释）
        正则匹配(模式: "//[^\\n]*", 文本: 文本) { 范围 in
            富文本.addAttribute(.foregroundColor, value: 语法颜色.注释, range: 范围)
        }
        // 块注释 /* ... */
        正则匹配(模式: "/\\*[\\s\\S]*?\\*/", 文本: 文本) { 范围 in
            富文本.addAttribute(.foregroundColor, value: 语法颜色.注释, range: 范围)
        }
        // 单引号与双引号字符串
        正则匹配(模式: #"(["'])(?:(?=(\\?))\2.)*?\1"#, 文本: 文本) { 范围 in
            富文本.addAttribute(.foregroundColor, value: 语法颜色.字符串, range: 范围)
        }
        // JS语言关键字
        for 关键字 in 语法关键字.JS关键字列表 {
            正则匹配(模式: "\\b\(关键字)\\b", 文本: 文本) { 范围 in
                富文本.addAttribute(.foregroundColor, value: 语法颜色.JS关键字, range: 范围)
            }
        }
        // 圈X内置全局对象（$开头需转义）
        for 对象 in 语法关键字.圈X对象列表 {
            let 转义对象 = 对象.replacingOccurrences(of: "$", with: "\\$")
            正则匹配(模式: "\(转义对象)\\b", 文本: 文本) { 范围 in
                富文本.addAttribute(.foregroundColor, value: 语法颜色.圈X对象, range: 范围)
            }
        }
        return 富文本
    }

    /// 执行正则匹配并对每个匹配范围执行回调
    /// - Parameters:
    ///   - 模式: 正则表达式
    ///   - 文本: 待匹配文本
    ///   - 回调: 匹配到的范围处理
    private func 正则匹配(模式: String, 文本: String, 回调: (NSRange) -> Void) {
        guard let 正则 = try? NSRegularExpression(pattern: 模式, options: []) else { return }
        let 全范围 = NSRange(文本.startIndex..., in: 文本)
        正则.enumerateMatches(in: 文本, options: [], range: 全范围) { 结果, _, _ in
            guard let 匹配 = 结果 else { return }
            回调(匹配.range)
        }
    }
}
