import Foundation
import SwiftUI

/// 测试环境配置存储服务，保存多套URL与请求头组合
/// 存储方式：UserDefaults 序列化 JSON
@MainActor
final class 测试环境存储: ObservableObject {
    /// 已保存的测试环境列表
    @Published var 环境列表: [测试环境模型] = []
    /// UserDefaults 存储键名
    private let 存储键 = "QuantumX测试环境列表"

    /// 初始化时加载，若无数据则创建默认环境
    init() {
        加载()
    }

    /// 从 UserDefaults 加载环境列表
    private func 加载() {
        guard let 数据 = UserDefaults.standard.data(forKey: 存储键) else {
            环境列表 = [测试环境模型(环境名称: "默认环境")]
            return
        }
        if let 列表 = try? JSONDecoder().decode([测试环境模型].self, from: 数据) {
            环境列表 = 列表
        } else {
            环境列表 = [测试环境模型(环境名称: "默认环境")]
        }
    }

    /// 持久化到 UserDefaults
    private func 保存() {
        if let 数据 = try? JSONEncoder().encode(环境列表) {
            UserDefaults.standard.set(数据, forKey: 存储键)
        }
    }

    /// 新增测试环境
    /// - Parameter 环境: 环境模型
    func 新增环境(_ 环境: 测试环境模型) {
        环境列表.append(环境)
        保存()
    }

    /// 更新已有测试环境
    /// - Parameter 环境: 更新后的环境模型
    func 更新环境(_ 环境: 测试环境模型) {
        guard let 索引 = 环境列表.firstIndex(where: { $0.id == 环境.id }) else { return }
        环境列表[索引] = 环境
        保存()
    }

    /// 删除测试环境
    /// - Parameter 环境: 目标环境
    func 删除环境(_ 环境: 测试环境模型) {
        环境列表.removeAll { $0.id == 环境.id }
        保存()
    }
}
