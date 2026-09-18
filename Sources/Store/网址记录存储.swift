import Foundation
import SwiftUI

/// 网址记录本地存储服务，负责测试URL的历史记录与收藏持久化
/// 存储方式：UserDefaults 序列化 JSON，重启App不丢失
@MainActor
final class 网址记录存储: ObservableObject {
    /// 全部网址记录（含收藏与历史）
    @Published var 记录列表: [网址记录模型] = []
    /// UserDefaults 存储键名
    private let 存储键 = "QuantumX网址记录列表"

    /// 初始化时自动加载本地记录
    init() {
        加载记录()
    }

    /// 从 UserDefaults 反序列化加载记录
    private func 加载记录() {
        guard let 数据 = UserDefaults.standard.data(forKey: 存储键) else { return }
        if let 列表 = try? JSONDecoder().decode([网址记录模型].self, from: 数据) {
            记录列表 = 列表
        }
    }

    /// 序列化保存到 UserDefaults
    private func 持久化() {
        if let 数据 = try? JSONEncoder().encode(记录列表) {
            UserDefaults.standard.set(数据, forKey: 存储键)
        }
    }

    /// 添加一条网址使用记录，已存在则更新使用时间并置顶
    /// - Parameter 网址: URL字符串
    func 添加网址(_ 网址: String) {
        let 清洗后 = 网址.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !清洗后.isEmpty else { return }
        if let 索引 = 记录列表.firstIndex(where: { $0.网址 == 清洗后 }) {
            记录列表[索引].使用时间 = Date()
            let 记录 = 记录列表.remove(at: 索引)
            记录列表.insert(记录, at: 0)
        } else {
            记录列表.insert(网址记录模型(网址: 清洗后), at: 0)
        }
        持久化()
    }

    /// 切换单条记录的收藏状态
    /// - Parameter 记录: 目标记录
    func 切换收藏(_ 记录: 网址记录模型) {
        guard let 索引 = 记录列表.firstIndex(where: { $0.id == 记录.id }) else { return }
        记录列表[索引].是否已收藏.toggle()
        持久化()
    }

    /// 删除单条记录
    /// - Parameter 记录: 目标记录
    func 删除记录(_ 记录: 网址记录模型) {
        记录列表.removeAll { $0.id == 记录.id }
        持久化()
    }

    /// 清空全部历史记录，已收藏的记录保留
    func 清空历史() {
        记录列表.removeAll { !$0.是否已收藏 }
        持久化()
    }

    /// 已收藏的网址列表（按使用时间倒序）
    var 收藏列表: [网址记录模型] {
        记录列表.filter { $0.是否已收藏 }.sorted { $0.使用时间 > $1.使用时间 }
    }

    /// 历史记录列表（未收藏，按使用时间倒序）
    var 历史列表: [网址记录模型] {
        记录列表.filter { !$0.是否已收藏 }.sorted { $0.使用时间 > $1.使用时间 }
    }
}
