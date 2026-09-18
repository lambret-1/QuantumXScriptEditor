import Foundation

/// 代码格式化服务，提供轻量JS缩进格式化
/// 基于大括号层级自动调整缩进，不做完整语法解析，避免破坏代码
/// 适用于新手整理混乱的代码缩进
enum 代码格式化服务 {
    /// 格式化结果
    struct 格式化结果 {
        /// 格式化后的代码
        let 格式化代码: String
        /// 是否成功
        let 成功: Bool
        /// 提示信息
        let 提示: String
    }

    /// 执行JS代码格式化
    /// - Parameter 代码: 原始JS源代码
    /// - Returns: 格式化结果
    static func 格式化(代码: String) -> 格式化结果 {
        let 行数组 = 代码.components(separatedBy: .newlines)
        var 格式化行: [String] = []
        var 当前缩进层级 = 0
        let 缩进单位 = "    " // 4空格缩进，生产级标准，可读性最佳

        for 原始行 in 行数组 {
            let 去首尾空白 = 原始行.trimmingCharacters(in: .whitespaces)

            // 空行保持空行
            guard !去首尾空白.isEmpty else {
                格式化行.append("")
                continue
            }

            // 单行注释不调整缩进，保持原样
            if 去首尾空白.hasPrefix("//") {
                格式化行.append(String(repeating: 缩进单位, count: max(当前缩进层级, 0)) + 去首尾空白)
                continue
            }

            // 如果行以 } 开头，先减少一级缩进
            var 本行层级 = 当前缩进层级
            if 去首尾空白.hasPrefix("}") || 去首尾空白.hasPrefix("}") || 去首尾空白.hasPrefix("],") || 去首尾空白.hasPrefix("]") {
                本行层级 = max(当前缩进层级 - 1, 0)
            }

            // 处理同行包含多个 } 的情况（如 } else {）
            let 左大括号数 = 去首尾空白.filter { $0 == "{" }.count
            let 右大括号数 = 去首尾空白.filter { $0 == "}" }.count

            格式化行.append(String(repeating: 缩进单位, count: max(本行层级, 0)) + 去首尾空白)

            // 更新下一行缩进层级
            当前缩进层级 += 左大括号数 - 右大括号数
            if 当前缩进层级 < 0 {
                当前缩进层级 = 0
            }
        }

        let 格式化代码 = 格式化行.joined(separator: "\n")
        return 格式化结果(
            格式化代码: 格式化代码,
            成功: true,
            提示: "✅ 格式化完成，已按大括号层级自动调整缩进（4空格）。复杂嵌套建议手动复核。"
        )
    }
}
