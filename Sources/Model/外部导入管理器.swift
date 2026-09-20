import Foundation

/// 外部文件导入管理器
/// 解决冷启动时onOpenURL在脚本列表页初始化前调用导致通知丢失的问题
/// App入口收到外部文件后保存到此处，脚本列表页onAppear时检查并处理
class 外部导入管理器 {
    /// 共享单例
    static let 共享 = 外部导入管理器()

    /// 待导入的文件信息队列
    private var 待导入队列: [(文件名: String, 内容: String)] = []

    /// 私有初始化，防止外部创建实例
    private init() {}

    /// 添加待导入的文件
    /// - Parameters:
    ///   - 文件名: 文件名（不含扩展名）
    ///   - 内容: 文件内容
    func 添加待导入(文件名: String, 内容: String) {
        待导入队列.append((文件名: 文件名, 内容: 内容))
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
}
