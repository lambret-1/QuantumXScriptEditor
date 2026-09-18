import Foundation

/// 圈X脚本实体模型，描述单个JS脚本的元数据与内容
struct 脚本模型: Identifiable, Codable, Equatable {
    /// 唯一标识
    let id: UUID
    /// 脚本名称（不含扩展名）
    var 名称: String
    /// 脚本源代码内容
    var 内容: String
    /// 创建时间
    let 创建时间: Date
    /// 最后修改时间
    var 修改时间: Date

    /// 初始化脚本模型
    /// - Parameters:
    ///   - id: 唯一标识，默认自动生成
    ///   - 名称: 脚本名称
    ///   - 内容: 脚本源代码
    init(id: UUID = UUID(), 名称: String, 内容: String) {
        self.id = id
        self.名称 = 名称
        self.内容 = 内容
        self.创建时间 = Date()
        self.修改时间 = Date()
    }

    /// 判断两个脚本模型是否相等（仅比较id）
    static func == (左侧: 脚本模型, 右侧: 脚本模型) -> Bool {
        左侧.id == 右侧.id
    }
}
