import Foundation

/// 测试环境配置模型，保存一套URL与请求头的组合，便于快速切换测试场景
struct 测试环境模型: Identifiable, Codable, Equatable {
    /// 唯一标识
    let id: UUID
    /// 环境名称，用于用户识别
    var 环境名称: String
    /// 目标测试URL
    var 目标网址: String
    /// 自定义请求头字典
    var 请求头: [String: String]

    /// 初始化测试环境
    /// - Parameters:
    ///   - id: 唯一标识，默认自动生成
    ///   - 环境名称: 环境显示名称
    ///   - 目标网址: 测试URL
    ///   - 请求头: 请求头字典，默认空
    init(id: UUID = UUID(), 环境名称: String = "默认环境", 目标网址: String = "", 请求头: [String: String] = [:]) {
        self.id = id
        self.环境名称 = 环境名称
        self.目标网址 = 目标网址
        self.请求头 = 请求头
    }

    static func == (左侧: 测试环境模型, 右侧: 测试环境模型) -> Bool {
        左侧.id == 右侧.id
    }
}
