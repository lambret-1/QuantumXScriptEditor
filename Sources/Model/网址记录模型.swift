import Foundation

/// 网址记录模型，用于测试URL的历史记录与收藏管理
struct 网址记录模型: Identifiable, Codable, Equatable {
    /// 唯一标识
    let id: UUID
    /// 完整URL字符串
    var 网址: String
    /// 是否收藏，收藏的网址不会被清空历史操作删除
    var 是否已收藏: Bool
    /// 记录创建/最后使用时间
    var 使用时间: Date

    /// 初始化网址记录
    /// - Parameters:
    ///   - id: 唯一标识，默认自动生成
    ///   - 网址: URL字符串
    ///   - 是否已收藏: 是否加入收藏，默认否
    init(id: UUID = UUID(), 网址: String, 是否已收藏: Bool = false) {
        self.id = id
        self.网址 = 网址
        self.是否已收藏 = 是否已收藏
        self.使用时间 = Date()
    }

    static func == (左侧: 网址记录模型, 右侧: 网址记录模型) -> Bool {
        左侧.id == 右侧.id
    }
}
