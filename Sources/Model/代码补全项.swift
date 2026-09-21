import Foundation

/// 代码补全候选项，描述一个可插入的代码片段及其说明
struct 代码补全项: Identifiable, Equatable {
    /// 唯一标识
    let id = UUID()
    /// 补全触发关键词（用户输入此内容时触发提示）
    let 触发词: String
    /// 补全后插入的完整代码
    let 插入代码: String
    /// 中文说明，解释该API的用途
    let 中文说明: String
    /// 分类标签，用于分组显示
    let 分类: 补全分类

    /// 补全分类枚举
    enum 补全分类: String, CaseIterable {
        /// 常用代码片段（首字母联想优先显示）
        case 常用片段 = "常用片段"
        /// 圈X全局对象
        case 全局对象 = "全局对象"
        /// 请求相关
        case 请求相关 = "请求相关"
        /// 响应相关
        case 响应相关 = "响应相关"
        /// 网络请求
        case 网络请求 = "网络请求"
        /// 存储与通知
        case 存储通知 = "存储通知"
        /// 控制流
        case 控制流 = "控制流"
        /// 加密编码
        case 加密编码 = "加密编码"
        /// 日期时间
        case 日期时间 = "日期时间"
        /// 字符串处理
        case 字符串处理 = "字符串处理"
        /// 正则匹配
        case 正则匹配 = "正则匹配"
        /// 数学运算
        case 数学运算 = "数学运算"
        /// JSON处理
        case JSON处理 = "JSON处理"
    }

    static func == (左侧: 代码补全项, 右侧: 代码补全项) -> Bool {
        左侧.id == 右侧.id
    }
}
