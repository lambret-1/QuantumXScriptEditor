import Foundation
import Combine

/// 外部文件导入管理器
/// 解决冷启动时onOpenURL在脚本列表页初始化前调用导致通知丢失的问题
/// App入口收到外部文件后保存到此处，脚本列表页通过@Published观察变化并处理
class 外部导入管理器: ObservableObject {
    /// 共享单例
    static let 共享 = 外部导入管理器()

    /// 待导入的文件信息队列（@Published让观察者实时感知变化）
    @Published private(set) var 待导入队列: [(文件名: String, 内容: String)] = []

    /// 防止重复导入的标记（处理中时为true）
    private var 正在处理 = false

    /// 私有初始化，防止外部创建实例
    private init() {}

    /// 添加待导入的文件
    /// - Parameters:
    ///   - 文件名: 文件名（不含扩展名）
    ///   - 内容: 文件内容
    func 添加待导入(文件名: String, 内容: String) {
        DispatchQueue.main.async {
            self.待导入队列.append((文件名: 文件名, 内容: 内容))
        }
    }

    /// 取出所有待导入的文件（取出后清空队列）
    /// - Returns: 待导入的文件信息数组
    func 取出全部待导入() -> [(文件名: String, 内容: String)] {
        let 队列 = 待导入队列
        待导入队列.removeAll()
        return 队列
    }

    /// 检查是否有待导入的文件
    var 有待导入: Bool {
        return !待导入队列.isEmpty
    }

    /// 标记开始处理（防止重复导入）
    func 标记处理开始() {
        正在处理 = true
    }

    /// 标记处理结束
    func 标记处理结束() {
        正在处理 = false
    }

    /// 是否正在处理
    var 处理中: Bool {
        return 正在处理
    }
}
