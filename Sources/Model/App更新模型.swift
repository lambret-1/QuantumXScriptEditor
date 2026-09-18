import Foundation

/// App更新信息模型，描述GitHub Release的版本信息
struct App更新模型: Identifiable, Equatable {
    let id = UUID()
    /// 版本号（如 0.5.0）
    let 版本号: String
    /// Release标签（如 v0.5.0）
    let 标签: String
    /// 发布说明
    let 发布说明: String
    /// IPA下载地址
    let 下载地址: String
    /// Release页面地址
    let 页面地址: String
    /// 发布时间
    let 发布时间: String

    static func == (左侧: App更新模型, 右侧: App更新模型) -> Bool {
        左侧.版本号 == 右侧.版本号
    }
}
