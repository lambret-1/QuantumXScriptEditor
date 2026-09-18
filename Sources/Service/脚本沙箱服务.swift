import Foundation
import JavaScriptCore

/// JS沙箱服务，模拟圈X运行环境供本地脚本测试
/// 模拟对象：$request / $response / $notify / $persistentStore / $httpClient.get/post / $done
/// 支持真实网络请求，带执行超时保护，支持中途停止，输出完整响应体
/// ⚠️ 沙箱环境不等于圈X真实运行环境，仅用于本地预调试
final class 脚本沙箱服务 {
    /// JS执行上下文
    private var 上下文: JSContext!
    /// 实时输出文本
    private(set) var 输出文本 = ""
    /// 输出更新回调（同步与异步结果均通过此回调通知）
    var 输出更新回调: ((String) -> Void)?
    /// 执行完成回调（参数：执行耗时秒数）
    var 完成回调: ((TimeInterval) -> Void)?
    /// 超时是否已触发
    private var 超时已触发 = false
    /// 同步执行是否已完成
    private var 同步已完成 = false
    /// 是否已被用户停止
    private var 已停止 = false
    /// 执行开始时间
    private var 开始时间: Date?
    /// 当前进行中的网络任务（用于停止时取消）
    private var 当前网络任务: URLSessionDataTask?
    /// 响应体最大输出字符数（超过则截断）
    private let 响应体最大输出长度 = 2000

    /// 初始化并构建沙箱环境
    init() {
        重置上下文()
    }

    /// 停止当前执行（取消网络请求，标记停止状态）
    func 停止执行() {
        已停止 = true
        当前网络任务?.cancel()
        当前网络任务 = nil
        追加输出("\n[已停止] 用户手动停止脚本执行\n")
    }

    /// 重建JS上下文并注入全部圈X模拟对象
    private func 重置上下文() {
        上下文 = JSContext()
        输出文本 = ""
        超时已触发 = false
        同步已完成 = false
        已停止 = false
        开始时间 = nil
        当前网络任务 = nil

        // 捕获JS运行时异常
        上下文.exceptionHandler = { [weak self] _, 异常 in
            guard let 异常 = 异常 else { return }
            self?.追加输出("[JS错误] \(异常)\n")
        }

        注入通知对象()
        注入完成对象()
        注入持久化存储()
        注入网络客户端()
    }

    /// 注入 $notify 模拟对象
    private func 注入通知对象() {
        let 通知函数: @convention(block) (Any?, Any?, Any?) -> Void = { [weak self] 标题, 副标题, 内容 in
            let t = 标题 as? String ?? ""
            let s = 副标题 as? String ?? ""
            let m = 内容 as? String ?? ""
            self?.追加输出("[通知] 标题：\(t) | 副标题：\(s) | 内容：\(m)\n")
        }
        上下文.setObject(通知函数, forKeyedSubscript: "$notify" as NSString)
    }

    /// 注入 $done 模拟对象
    private func 注入完成对象() {
        let 完成函数: @convention(block) (Any?) -> Void = { [weak self] 返回值 in
            if let 值 = 返回值 {
                self?.追加输出("[完成] 脚本返回：\(String(describing: 值))\n")
            } else {
                self?.追加输出("[完成] 脚本执行结束（无返回值）\n")
            }
        }
        上下文.setObject(完成函数, forKeyedSubscript: "$done" as NSString)
    }

    /// 注入 $persistentStore 模拟对象（内存级，重启沙箱丢失）
    private func 注入持久化存储() {
        var 存储字典: [String: String] = [:]
        let 读取函数: @convention(block) (String) -> String? = { 键 in
            存储字典[键]
        }
        let 写入函数: @convention(block) (String, String) -> Bool = { 键, 值 in
            存储字典[键] = 值
            return true
        }
        let 存储对象: [String: Any] = ["read": 读取函数, "write": 写入函数]
        上下文.setObject(存储对象, forKeyedSubscript: "$persistentStore" as NSString)
    }

    /// 注入 $httpClient 模拟对象，支持 get / post 真实网络请求
    private func 注入网络客户端() {
        weak var 弱引用 = self
        let get函数: @convention(block) (String, Any?, JSValue) -> Void = { 网址, 选项, 回调 in
            弱引用?.发起网络请求(方法: "GET", 网址: 网址, 选项: 选项, 回调: 回调)
        }
        let post函数: @convention(block) (String, Any?, JSValue) -> Void = { 网址, 选项, 回调 in
            弱引用?.发起网络请求(方法: "POST", 网址: 网址, 选项: 选项, 回调: 回调)
        }
        let 客户端对象: [String: Any] = ["get": get函数, "post": post函数]
        上下文.setObject(客户端对象, forKeyedSubscript: "$httpClient" as NSString)
    }

    /// 发起真实HTTP请求并在完成后调用JS回调
    /// - Parameters:
    ///   - 方法: HTTP方法（GET/POST）
    ///   - 网址: 请求URL
    ///   - 选项: 选项对象（headers、body）
    ///   - 回调: JS回调函数 function(error, response)
    private func 发起网络请求(方法: String, 网址: String, 选项: Any?, 回调: JSValue) {
        guard !已停止 else {
            回调.call(withArguments: [["error": "已被停止"], NSNull()])
            return
        }
        guard let 请求URL = URL(string: 网址) else {
            追加输出("[网络错误] URL格式无效：\(网址)\n")
            回调.call(withArguments: [["error": "URL格式无效"], NSNull()])
            return
        }

        var 请求头: [String: String] = [:]
        var 请求体数据: Data?
        if let 选项字典 = 选项 as? [String: Any] {
            请求头 = 选项字典["headers"] as? [String: String] ?? [:]
            if let 体字符串 = 选项字典["body"] as? String {
                请求体数据 = 体字符串.data(using: .utf8)
            }
        }

        var 请求 = URLRequest(url: 请求URL)
        请求.httpMethod = 方法
        请求.allHTTPHeaderFields = 请求头
        请求.httpBody = 请求体数据
        请求.timeoutInterval = 10 // 网络请求超时10秒，避免长时间挂起

        // 输出请求详情
        追加输出("[网络请求] \(方法) \(网址)\n")
        if !请求头.isEmpty {
            let 请求头文本 = 请求头.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
            追加输出("[请求头]\n\(请求头文本)\n")
        }
        if let 体 = 请求体数据, let 体文本 = String(data: 体, encoding: .utf8), !体文本.isEmpty {
            追加输出("[请求体]\n\(体文本)\n")
        }

        let 任务 = URLSession.shared.dataTask(with: 请求) { [weak self] 数据, 响应, 错误 in
            DispatchQueue.main.async {
                guard let 自身 = self else { return }
                自身.当前网络任务 = nil
                // 被取消时不回调
                if let 错误 = 错误 as? URLError, 错误.code == .cancelled {
                    自身.追加输出("[网络请求] 已取消\n")
                    return
                }
                if let 错误 = 错误 {
                    自身.追加输出("[网络错误] \(错误.localizedDescription)\n")
                    回调.call(withArguments: [["error": 错误.localizedDescription], NSNull()])
                    return
                }
                guard let HTTP响应 = 响应 as? HTTPURLResponse, let 响应数据 = 数据 else {
                    自身.追加输出("[网络错误] 响应为空\n")
                    回调.call(withArguments: [["error": "空响应"], NSNull()])
                    return
                }
                let 响应体文本 = String(data: 响应数据, encoding: .utf8) ?? ""
                // 输出响应头
                let 响应头文本 = HTTP响应.allHeaderFields.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
                自身.追加输出("[响应头]\n\(响应头文本)\n")
                // 输出响应体（超长截断）
                if 响应体文本.count > 自身.响应体最大输出长度 {
                    let 截断文本 = String(响应体文本.prefix(自身.响应体最大输出长度))
                    自身.追加输出("[响应体]（共\(响应体文本.count)字符，仅显示前\(自身.响应体最大输出长度)字符）\n\(截断文本)\n...\n")
                } else {
                    自身.追加输出("[响应体]\n\(响应体文本)\n")
                }
                自身.追加输出("[网络响应] 状态码\(HTTP响应.statusCode)，响应体\(响应体文本.count)字符\n")
                let 响应对象: [String: Any] = [
                    "status": HTTP响应.statusCode,
                    "statusCode": HTTP响应.statusCode,
                    "headers": HTTP响应.allHeaderFields,
                    "body": 响应体文本
                ]
                回调.call(withArguments: [NSNull(), 响应对象])
            }
        }
        当前网络任务 = 任务
        任务.resume()
    }

    /// 执行脚本，带超时保护与耗时统计
    /// - Parameters:
    ///   - 代码: JS源代码
    ///   - 目标网址: 注入到 $request.url 的测试URL
    ///   - 请求头: 注入到 $request.headers 的请求头
    ///   - 请求方法: 注入到 $request.method 的HTTP方法
    func 执行脚本(代码: String, 目标网址: String, 请求头: [String: String], 请求方法: String = "GET") {
        重置上下文()
        开始时间 = Date()

        // 注入 $request 对象
        let 请求对象: [String: Any] = [
            "url": 目标网址,
            "headers": 请求头,
            "method": 请求方法
        ]
        上下文.setObject(请求对象, forKeyedSubscript: "$request" as NSString)

        追加输出("========== 开始执行脚本 ==========\n")
        追加输出("目标网址：\(目标网址)\n")
        追加输出("请求方法：\(请求方法)\n")
        if !请求头.isEmpty {
            追加输出("请求头：\(请求头.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))\n")
        }

        // 超时保护：在后台队列执行，超时后提示
        let 工作项 = DispatchWorkItem { [weak self] in
            _ = self?.上下文.evaluateScript(代码)
        }

        // 超时监听
        DispatchQueue.global().asyncAfter(deadline: .now() + 应用常量.沙箱超时秒数) { [weak self] in
            guard let 自身 = self else { return }
            if !自身.同步已完成 && !自身.已停止 {
                自身.超时已触发 = true
                自身.追加输出("[超时] 脚本执行超过\(应用常量.沙箱超时秒数)秒，可能存在死循环或阻塞操作，已停止等待\n")
                自身.通知完成()
            }
        }

        // 在后台队列同步执行JS，避免阻塞主线程
        DispatchQueue.global().async { [weak self] in
            工作项.perform()
            DispatchQueue.main.async {
                guard let 自身 = self else { return }
                自身.同步已完成 = true
                if !自身.超时已触发 && !自身.已停止 {
                    自身.追加输出("========== 同步执行完成 ==========\n")
                    自身.通知完成()
                }
            }
        }
    }

    /// 计算执行耗时并通知完成回调
    private func 通知完成() {
        let 耗时: TimeInterval
        if let 开始 = 开始时间 {
            耗时 = Date().timeIntervalSince(开始)
        } else {
            耗时 = 0
        }
        追加输出("[耗时] \(String(format: "%.3f", 耗时))秒\n")
        完成回调?(耗时)
    }

    /// 追加输出文本并通知回调
    private func 追加输出(_ 文本: String) {
        输出文本 += 文本
        输出更新回调?(输出文本)
    }
}
