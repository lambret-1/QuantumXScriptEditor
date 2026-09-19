import SwiftUI

// MARK: - 富文本视图（iOS14兼容，用UITextView渲染NSAttributedString）

/// 富文本显示视图，支持Markdown格式的发布说明
/// iOS14兼容：SwiftUI的Text不支持Markdown，使用UITextView+NSAttributedString渲染
struct 富文本视图: UIViewRepresentable {
    /// 显示的文本（支持简单Markdown格式）
    let 文本: String
    /// 字体大小
    var 字体大小: CGFloat = 13
    /// 文本颜色
    var 文字颜色: UIColor = .label

    func makeUIView(context: Context) -> UITextView {
        let 文本视图 = UITextView()
        文本视图.isEditable = false
        文本视图.isSelectable = true
        文本视图.isScrollEnabled = false
        文本视图.backgroundColor = .clear
        文本视图.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        文本视图.textContainer.lineFragmentPadding = 0
        文本视图.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return 文本视图
    }

    func updateUIView(_ 文本视图: UITextView, context: Context) {
        let 富文本 = Markdown解析器.解析(文本, 字体大小: 字体大小, 文字颜色: 文字颜色)
        文本视图.attributedText = 富文本
    }
}

// MARK: - Markdown解析器

/// 简单Markdown解析器，将Markdown文本转换为NSAttributedString
/// 支持：标题、粗体、斜体、行内代码、代码块、无序列表、有序列表、链接、分割线
enum Markdown解析器 {
    /// 解析Markdown文本为富文本
    /// - Parameters:
    ///   - 文本: Markdown格式文本
    ///   - 字体大小: 基础字体大小
    ///   - 文字颜色: 基础文字颜色
    /// - Returns: 格式化后的NSAttributedString
    static func 解析(_ 文本: String, 字体大小: CGFloat = 13, 文字颜色: UIColor = .label) -> NSAttributedString {
        let 结果 = NSMutableAttributedString()
        let 行列表 = 文本.components(separatedBy: .newlines)
        var 在代码块中 = false
        var 代码块内容 = ""

        for 行 in 行列表 {
            // 代码块开始/结束
            if 行.hasPrefix("```") {
                if 在代码块中 {
                    // 结束代码块，添加代码内容
                    let 代码属性: [NSAttributedString.Key: Any] = [
                        .font: UIFont(name: "Menlo-Regular", size: 字体大小 - 1) ?? UIFont.monospacedSystemFont(ofSize: 字体大小 - 1, weight: .regular),
                        .foregroundColor: UIColor.systemGreen,
                        .backgroundColor: UIColor.systemGray6
                    ]
                    结果.append(NSAttributedString(string: 代码块内容, attributes: 代码属性))
                    结果.append(NSAttributedString(string: "\n"))
                    代码块内容 = ""
                    在代码块中 = false
                } else {
                    在代码块中 = true
                    代码块内容 = ""
                }
                continue
            }

            if 在代码块中 {
                代码块内容 += 行 + "\n"
                continue
            }

            // 空行
            if 行.trimmingCharacters(in: .whitespaces).isEmpty {
                结果.append(NSAttributedString(string: "\n"))
                continue
            }

            // 分割线
            if 行.trimmingCharacters(in: .whitespaces) == "---" || 行.trimmingCharacters(in: .whitespaces) == "***" {
                let 分割线属性: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 字体大小 - 4),
                    .foregroundColor: UIColor.systemGray3
                ]
                结果.append(NSAttributedString(string: "———————————————————\n", attributes: 分割线属性))
                continue
            }

            // 标题
            if 行.hasPrefix("### ") {
                let 内容 = String(行.dropFirst(4))
                let 标题属性: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 字体大小 + 1),
                    .foregroundColor: 文字颜色
                ]
                结果.append(NSAttributedString(string: 内容 + "\n", attributes: 标题属性))
                continue
            }
            if 行.hasPrefix("## ") {
                let 内容 = String(行.dropFirst(3))
                let 标题属性: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 字体大小 + 3),
                    .foregroundColor: 文字颜色
                ]
                结果.append(NSAttributedString(string: 内容 + "\n", attributes: 标题属性))
                continue
            }
            if 行.hasPrefix("# ") {
                let 内容 = String(行.dropFirst(2))
                let 标题属性: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 字体大小 + 5),
                    .foregroundColor: 文字颜色
                ]
                结果.append(NSAttributedString(string: 内容 + "\n", attributes: 标题属性))
                continue
            }

            // 无序列表
            if 行.hasPrefix("- ") || 行.hasPrefix("* ") {
                let 内容 = String(行.dropFirst(2))
                let 项目符号属性: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 字体大小),
                    .foregroundColor: UIColor.systemBlue
                ]
                结果.append(NSAttributedString(string: "• ", attributes: 项目符号属性))
                结果.append(解析行内格式(内容, 字体大小: 字体大小, 文字颜色: 文字颜色))
                结果.append(NSAttributedString(string: "\n"))
                continue
            }

            // 有序列表
            if let 范围 = 行.range(of: #"^\d+\. "#, options: .regularExpression) {
                let 序号 = String(行[范围]).trimmingCharacters(in: .whitespaces)
                let 内容 = String(行[范围.upperBound...])
                let 序号属性: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 字体大小),
                    .foregroundColor: UIColor.systemBlue
                ]
                结果.append(NSAttributedString(string: 序号 + " ", attributes: 序号属性))
                结果.append(解析行内格式(内容, 字体大小: 字体大小, 文字颜色: 文字颜色))
                结果.append(NSAttributedString(string: "\n"))
                continue
            }

            // 引用
            if 行.hasPrefix("> ") {
                let 内容 = String(行.dropFirst(2))
                let 引用属性: [NSAttributedString.Key: Any] = [
                    .font: UIFont.italicSystemFont(ofSize: 字体大小),
                    .foregroundColor: UIColor.systemGray
                ]
                结果.append(NSAttributedString(string: "▎ ", attributes: [.foregroundColor: UIColor.systemBlue]))
                结果.append(NSAttributedString(string: 内容 + "\n", attributes: 引用属性))
                continue
            }

            // 普通段落
            结果.append(解析行内格式(行, 字体大小: 字体大小, 文字颜色: 文字颜色))
            结果.append(NSAttributedString(string: "\n"))
        }

        // 如果代码块未闭合，直接添加
        if 在代码块中 && !代码块内容.isEmpty {
            let 代码属性: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Menlo-Regular", size: 字体大小 - 1) ?? UIFont.monospacedSystemFont(ofSize: 字体大小 - 1, weight: .regular),
                .foregroundColor: UIColor.systemGreen,
                .backgroundColor: UIColor.systemGray6
            ]
            结果.append(NSAttributedString(string: 代码块内容, attributes: 代码属性))
        }

        return 结果
    }

    /// 解析行内格式（粗体、斜体、行内代码、链接）
    private static func 解析行内格式(_ 文本: String, 字体大小: CGFloat, 文字颜色: UIColor) -> NSAttributedString {
        let 结果 = NSMutableAttributedString()
        var 剩余文本 = 文本

        while !剩余文本.isEmpty {
            // 行内代码 `code`
            if let 开始范围 = 剩余文本.range(of: "`") {
                // 添加代码前的普通文本
                let 普通文本 = String(剩余文本[..<开始范围.lowerBound])
                if !普通文本.isEmpty {
                    结果.append(解析粗体斜体链接(普通文本, 字体大小: 字体大小, 文字颜色: 文字颜色))
                }
                // 查找结束的反引号
                let 剩余部分 = String(剩余文本[开始范围.upperBound...])
                if let 结束范围 = 剩余部分.range(of: "`") {
                    let 代码内容 = String(剩余部分[..<结束范围.lowerBound])
                    let 代码属性: [NSAttributedString.Key: Any] = [
                        .font: UIFont(name: "Menlo-Regular", size: 字体大小 - 1) ?? UIFont.monospacedSystemFont(ofSize: 字体大小 - 1, weight: .regular),
                        .foregroundColor: UIColor.systemRed,
                        .backgroundColor: UIColor.systemGray6
                    ]
                    结果.append(NSAttributedString(string: 代码内容, attributes: 代码属性))
                    剩余文本 = String(剩余部分[结束范围.upperBound...])
                } else {
                    // 没有闭合的反引号，当作普通文本
                    结果.append(NSAttributedString(string: "`", attributes: [.font: UIFont.systemFont(ofSize: 字体大小), .foregroundColor: 文字颜色]))
                    剩余文本 = 剩余部分
                }
            } else {
                // 没有行内代码，直接解析粗体斜体链接
                结果.append(解析粗体斜体链接(剩余文本, 字体大小: 字体大小, 文字颜色: 文字颜色))
                break
            }
        }

        return 结果
    }

    /// 解析粗体、斜体和链接
    private static func 解析粗体斜体链接(_ 文本: String, 字体大小: CGFloat, 文字颜色: UIColor) -> NSAttributedString {
        let 结果 = NSMutableAttributedString()
        var 剩余文本 = 文本

        while !剩余文本.isEmpty {
            // 粗体 **text**
            if let 开始范围 = 剩余文本.range(of: "**") {
                let 普通文本 = String(剩余文本[..<开始范围.lowerBound])
                if !普通文本.isEmpty {
                    结果.append(解析链接(普通文本, 字体大小: 字体大小, 文字颜色: 文字颜色))
                }
                let 剩余部分 = String(剩余文本[开始范围.upperBound...])
                if let 结束范围 = 剩余部分.range(of: "**") {
                    let 粗体内容 = String(剩余部分[..<结束范围.lowerBound])
                    let 粗体属性: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 字体大小),
                        .foregroundColor: 文字颜色
                    ]
                    结果.append(NSAttributedString(string: 粗体内容, attributes: 粗体属性))
                    剩余文本 = String(剩余部分[结束范围.upperBound...])
                } else {
                    结果.append(NSAttributedString(string: "**", attributes: [.font: UIFont.systemFont(ofSize: 字体大小), .foregroundColor: 文字颜色]))
                    剩余文本 = 剩余部分
                }
            }
            // 斜体 *text* 或 _text_
            else if let 开始范围 = 剩余文本.range(of: "*"), 开始范围.upperBound < 剩余文本.endIndex {
                let 下一个字符 = 剩余文本[开始范围.upperBound]
                if 下一个字符 != "*" {
                    let 普通文本 = String(剩余文本[..<开始范围.lowerBound])
                    if !普通文本.isEmpty {
                        结果.append(解析链接(普通文本, 字体大小: 字体大小, 文字颜色: 文字颜色))
                    }
                    let 剩余部分 = String(剩余文本[开始范围.upperBound...])
                    if let 结束范围 = 剩余部分.range(of: "*") {
                        let 斜体内容 = String(剩余部分[..<结束范围.lowerBound])
                        let 斜体属性: [NSAttributedString.Key: Any] = [
                            .font: UIFont.italicSystemFont(ofSize: 字体大小),
                            .foregroundColor: 文字颜色
                        ]
                        结果.append(NSAttributedString(string: 斜体内容, attributes: 斜体属性))
                        剩余文本 = String(剩余部分[结束范围.upperBound...])
                    } else {
                        结果.append(NSAttributedString(string: "*", attributes: [.font: UIFont.systemFont(ofSize: 字体大小), .foregroundColor: 文字颜色]))
                        剩余文本 = 剩余部分
                    }
                } else {
                    // ** 但前面没有匹配到粗体（不应该到这里），当作普通文本
                    结果.append(解析链接(剩余文本, 字体大小: 字体大小, 文字颜色: 文字颜色))
                    break
                }
            }
            // 没有粗体斜体，直接解析链接
            else {
                结果.append(解析链接(剩余文本, 字体大小: 字体大小, 文字颜色: 文字颜色))
                break
            }
        }

        return 结果
    }

    /// 解析链接 [text](url)
    private static func 解析链接(_ 文本: String, 字体大小: CGFloat, 文字颜色: UIColor) -> NSAttributedString {
        let 结果 = NSMutableAttributedString()
        var 剩余文本 = 文本

        while !剩余文本.isEmpty {
            if let 方括号开始 = 剩余文本.range(of: "["),
               let 方括号结束 = 剩余文本[方括号开始.upperBound...].range(of: "]"),
               let 圆括号开始 = 剩余文本[方括号结束.upperBound...].range(of: "("),
               let 圆括号结束 = 剩余文本[圆括号开始.upperBound...].range(of: ")") {

                // 确保 ]( 是连续的
                if 方括号结束.upperBound == 圆括号开始.lowerBound {
                    let 普通文本 = String(剩余文本[..<方括号开始.lowerBound])
                    if !普通文本.isEmpty {
                        结果.append(NSAttributedString(string: 普通文本, attributes: [.font: UIFont.systemFont(ofSize: 字体大小), .foregroundColor: 文字颜色]))
                    }
                    let 链接文本 = String(剩余文本[方括号开始.upperBound..<方括号结束.lowerBound])
                    let 链接地址 = String(剩余文本[圆括号开始.upperBound..<圆括号结束.lowerBound])
                    let 链接属性: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 字体大小),
                        .foregroundColor: UIColor.systemBlue,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .link: URL(string: 链接地址) as Any
                    ]
                    结果.append(NSAttributedString(string: 链接文本, attributes: 链接属性))
                    剩余文本 = String(剩余文本[圆括号结束.upperBound...])
                } else {
                    // 不是连续的 ](，当作普通文本
                    let 普通文本 = String(剩余文本[..<方括号开始.upperBound])
                    结果.append(NSAttributedString(string: 普通文本, attributes: [.font: UIFont.systemFont(ofSize: 字体大小), .foregroundColor: 文字颜色]))
                    剩余文本 = String(剩余文本[方括号开始.upperBound...])
                }
            } else {
                结果.append(NSAttributedString(string: 剩余文本, attributes: [.font: UIFont.systemFont(ofSize: 字体大小), .foregroundColor: 文字颜色]))
                break
            }
        }

        return 结果
    }
}
