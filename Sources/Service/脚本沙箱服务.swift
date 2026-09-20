import Foundation
import JavaScriptCore

/// JS沙箱服务，模拟圈X运行环境供本地脚本测试
/// 模拟对象：$request / $response / $done / $notify / console.log
/// 圈X原生API：$task.fetch（Promise风格网络请求）/ $prefs（持久化存储）
/// 兼容Surge API：$httpClient.get/post / $persistentStore.write/read
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
    /// $done是否已被调用（防止重复调用导致多次输出）
    private var done已调用 = false
    /// 执行开始时间
    private var 开始时间: Date?
    /// 当前进行中的网络任务（用于停止时取消）
    private var 当前网络任务: URLSessionDataTask?
    /// 当前执行的脚本代码（用于异常时输出出错代码上下文）
    private var 当前执行代码 = ""
    /// 响应体最大输出字符数（超过则截断）
    private let 响应体最大输出长度 = 500
    /// 输出队列（确保线程安全，所有输出修改都在主队列串行执行）
    private let 输出队列 = DispatchQueue.main

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

    /// 重建JS上下文并注入基础对象
    private func 重置上下文() {
        上下文 = JSContext()
        输出文本 = ""
        超时已触发 = false
        同步已完成 = false
        已停止 = false
        done已调用 = false
        开始时间 = nil
        当前网络任务 = nil

        // 捕获JS运行时异常，输出详细错误信息（行号、列号、出错代码上下文）
        上下文.exceptionHandler = { [weak self] 上下文, 异常 in
            guard let 异常 = 异常 else { return }
            let 错误名称 = 异常.forProperty("name")?.toString() ?? "Error"
            let 错误消息 = 异常.forProperty("message")?.toString() ?? 异常.toString()
            let 行号 = 异常.forProperty("line")?.toInt32() ?? 0
            let 列号 = 异常.forProperty("column")?.toInt32() ?? 0
            self?.追加输出("[JS错误] \(错误名称): \(错误消息)\n")
            if 行号 > 0 {
                self?.追加输出("[错误位置] 第\(行号)行，第\(列号)列\n")
                // 输出出错行附近的代码上下文（前后各2行）
                if let 代码 = self?.当前执行代码 {
                    let 行数组 = 代码.components(separatedBy: .newlines)
                    let 起始行 = max(0, Int(行号) - 3)
                    let 结束行 = min(行数组.count - 1, Int(行号) + 1)
                    if 起始行 <= 结束行 {
                        var 上下文文本 = "[代码上下文]\n"
                        for i in 起始行...结束行 {
                            let 行号文本 = String(format: "%4d", i + 1)
                            let 标记 = (i == Int(行号) - 1) ? ">>" : "  "
                            上下文文本 += "\(标记)\(行号文本): \(行数组[i])\n"
                        }
                        self?.追加输出(上下文文本)
                    }
                }
            }
        }

        // 基础对象在执行脚本时注入（确保每次执行都是干净环境）
        注入完成对象()
        注入网络客户端()
    }

    // MARK: - 注入对象方法

    /// 注入 $done 模拟对象（带重复调用防护）
    private func 注入完成对象() {
        let 完成函数: @convention(block) (Any?) -> Void = { [weak self] 返回值 in
            guard let 自身 = self else { return }
            // 防止$done被多次调用导致重复输出
            guard !自身.done已调用 else {
                自身.追加输出("[提示] $done() 已被多次调用，忽略后续调用\n")
                return
            }
            自身.done已调用 = true

            if let 字典 = 返回值 as? [String: Any] {
                自身.追加输出("[完成] 脚本执行完成\n")
                if let 状态码 = 字典["statusCode"] as? Int {
                    自身.追加输出("[状态码] \(状态码)\n")
                } else if let 状态码 = 字典["status"] as? Int {
                    自身.追加输出("[状态码] \(状态码)\n")
                }
                if let 响应头 = 字典["headers"] as? [String: Any], !响应头.isEmpty {
                    let 头文本 = 响应头.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
                    自身.追加输出("[响应头]\n\(头文本)\n")
                }
                if let 响应体 = 字典["body"] as? String {
                    自身.展示格式化响应体(响应体)
                } else if let 响应体 = 字典["body"] {
                    自身.追加输出("[修改后响应体] \(String(describing: 响应体))\n")
                } else {
                    自身.追加输出("[修改后响应体] （空）\n")
                }
            } else if let 值 = 返回值 {
                自身.追加输出("[完成] 脚本返回：\(String(describing: 值))\n")
            } else {
                自身.追加输出("[完成] 脚本执行结束（无返回值，原样放行）\n")
            }
        }
        上下文.setObject(完成函数, forKeyedSubscript: "$done" as NSString)
    }

    /// 格式化展示响应体：尝试JSON美化，失败则原样显示
    private func 展示格式化响应体(_ 响应体: String) {
        if let 数据 = 响应体.data(using: .utf8),
           let 对象 = try? JSONSerialization.jsonObject(with: 数据),
           let 美化数据 = try? JSONSerialization.data(withJSONObject: 对象, options: [.prettyPrinted]),
           let 美化文本 = String(data: 美化数据, encoding: .utf8) {
            追加输出("[修改后响应体]\n\(美化文本)\n")
        } else {
            if 响应体.count > 2000 {
                let 截断 = String(响应体.prefix(2000))
                追加输出("[修改后响应体]（共\(响应体.count)字符，仅显示前2000字符）\n\(截断)\n...\n")
            } else {
                追加输出("[修改后响应体]\n\(响应体)\n")
            }
        }
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
        let 客户端对象 = JSValue(newObjectIn: 上下文)!
        客户端对象.setObject(get函数, forKeyedSubscript: "get" as NSString)
        客户端对象.setObject(post函数, forKeyedSubscript: "post" as NSString)
        上下文.setObject(客户端对象, forKeyedSubscript: "$httpClient" as NSString)
    }

    /// 发起真实HTTP请求并在完成后调用JS回调
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
        请求.timeoutInterval = 8

        追加输出("[网络请求] \(方法) \(网址)\n")
        if !请求头.isEmpty {
            追加输出("[请求头] \(请求头.count)个字段\n")
        }

        let 任务 = URLSession.shared.dataTask(with: 请求) { [weak self] 数据, 响应, 错误 in
            DispatchQueue.main.async {
                guard let 自身 = self else { return }
                自身.当前网络任务 = nil
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
                自身.追加输出("[网络响应] 状态码\(HTTP响应.statusCode)，响应体\(响应体文本.count)字符\n")
                if !响应体文本.isEmpty {
                    if 响应体文本.count > 自身.响应体最大输出长度 {
                        let 截断文本 = String(响应体文本.prefix(自身.响应体最大输出长度))
                        自身.追加输出("[响应体预览] 前\(自身.响应体最大输出长度)字符：\n\(截断文本)\n...\n")
                    } else {
                        自身.追加输出("[响应体]\n\(响应体文本)\n")
                    }
                }
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

    // MARK: - 执行脚本

    /// 执行脚本，带超时保护与耗时统计
    func 执行脚本(代码: String, 目标网址: String, 请求头: [String: String], 请求方法: String = "GET", 响应体: String? = nil) {
        重置上下文()
        开始时间 = Date()

        // 注入 $request 对象
        let 请求对象: [String: Any] = [
            "url": 目标网址,
            "headers": 请求头,
            "method": 请求方法
        ]
        上下文.setObject(请求对象, forKeyedSubscript: "$request" as NSString)

        // 注入 $response 对象
        let 模拟响应体 = 响应体 ?? "{\"code\":0,\"msg\":\"success\",\"data\":{\"isVip\":false,\"vipExpire\":\"2024-01-01\",\"vipLevel\":1}}"
        let 响应对象: [String: Any] = [
            "statusCode": 200,
            "status": 200,
            "headers": ["Content-Type": "application/json"],
            "body": 模拟响应体
        ]
        上下文.setObject(响应对象, forKeyedSubscript: "$response" as NSString)

        // 注入 console 对象（支持多参数和任意类型，与真实console.log行为一致）
        let 日志函数: @convention(block) (JSValue) -> Void = { [weak self] 参数列表 in
            // JS侧会用arguments传递所有参数，这里通过JSValue的上下文获取
            // 简化处理：接收第一个参数作为消息
            let 消息 = 参数列表.toString() ?? ""
            self?.追加输出("[日志] \(消息)\n")
        }
        let 控制台对象 = JSValue(newObjectIn: 上下文)!
        控制台对象.setObject(日志函数, forKeyedSubscript: "log" as NSString)
        上下文.setObject(控制台对象, forKeyedSubscript: "console" as NSString)
        // 兼容旧写法 $console.log
        上下文.setObject(控制台对象, forKeyedSubscript: "$console" as NSString)

        // 用JS包装console.log支持多参数（在JS侧拼接参数）
        上下文.evaluateScript("""
        var _origConsoleLog = console.log;
        console.log = function() {
            var args = Array.prototype.slice.call(arguments);
            var msg = args.map(function(a) {
                if (typeof a === 'object' && a !== null) {
                    try { return JSON.stringify(a); } catch(e) { return String(a); }
                }
                return String(a);
            }).join(' ');
            _origConsoleLog(msg);
        };
        """)

        // 注入 $prefs 对象（圈X原生持久化存储API）
        let 持久化前缀 = "圈X沙箱_"
        let 设置值函数: @convention(block) (String, String) -> Void = { 值, 键 in
            UserDefaults.standard.set(值, forKey: "\(持久化前缀)\(键)")
        }
        let 获取值函数: @convention(block) (String) -> String? = { 键 in
            UserDefaults.standard.string(forKey: "\(持久化前缀)\(键)")
        }
        let 持久化对象 = JSValue(newObjectIn: 上下文)!
        持久化对象.setObject(设置值函数, forKeyedSubscript: "setValueForKey" as NSString)
        持久化对象.setObject(获取值函数, forKeyedSubscript: "valueForKey" as NSString)
        上下文.setObject(持久化对象, forKeyedSubscript: "$prefs" as NSString)

        // 兼容Surge写法 $persistentStore
        let surge写入函数: @convention(block) (String, String) -> Void = { 值, 键 in
            UserDefaults.standard.set(值, forKey: "\(持久化前缀)\(键)")
        }
        let surge读取函数: @convention(block) (String) -> String? = { 键 in
            UserDefaults.standard.string(forKey: "\(持久化前缀)\(键)")
        }
        let surge持久化对象 = JSValue(newObjectIn: 上下文)!
        surge持久化对象.setObject(surge写入函数, forKeyedSubscript: "write" as NSString)
        surge持久化对象.setObject(surge读取函数, forKeyedSubscript: "read" as NSString)
        上下文.setObject(surge持久化对象, forKeyedSubscript: "$persistentStore" as NSString)

        // 注入 $notify 函数（圈X原生通知弹窗API，使用JSValue接收参数避免类型不匹配崩溃）
        let 通知函数: @convention(block) (JSValue, JSValue, JSValue, JSValue) -> Void = { [weak self] 标题, 副标题, 消息, _ in
            let t = 标题.isString ? 标题.toString() : ""
            let s = 副标题.isString ? 副标题.toString() : ""
            let m = 消息.isString ? 消息.toString() : ""
            self?.追加输出("[通知] 标题：\(t ?? "") | 副标题：\(s ?? "") | 内容：\(m ?? "")\n")
        }
        上下文.setObject(通知函数, forKeyedSubscript: "$notify" as NSString)

        // 注入 $task 对象（圈X原生网络请求API，Promise风格）
        let 原生获取函数: @convention(block) (JSValue, JSValue) -> Void = { [weak self] 选项, 回调 in
            guard let 自身 = self else { return }
            var 网址 = ""
            var 方法 = "GET"
            if 选项.isString {
                网址 = 选项.toString() ?? ""
            } else if 选项.isObject {
                网址 = 选项.forProperty("url")?.toString() ?? ""
                方法 = 选项.forProperty("method")?.toString() ?? "GET"
            }
            guard !网址.isEmpty else {
                回调.call(withArguments: [["error": "URL为空"], NSNull()])
                return
            }
            自身.发起网络请求(方法: 方法, 网址: 网址, 选项: 选项.isObject ? 选项.toObject() : nil, 回调: 回调)
        }
        上下文.setObject(原生获取函数, forKeyedSubscript: "$nativeFetch" as NSString)
        上下文.evaluateScript("""
        var $task = {
            fetch: function(options) {
                return new Promise(function(resolve, reject) {
                    $nativeFetch(options, function(error, response) {
                        if (error) reject(error);
                        else resolve(response);
                    });
                });
            }
        };
        """)

        // 输出执行信息
        追加输出("========== 开始执行脚本 ==========\n")
        追加输出("目标网址：\(目标网址)\n")
        追加输出("请求方法：\(请求方法)\n")
        if !请求头.isEmpty {
            追加输出("请求头：\(请求头.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))\n")
        }
        if 模拟响应体.count > 响应体最大输出长度 {
            let 预览 = String(模拟响应体.prefix(响应体最大输出长度))
            追加输出("[输入响应体] 共\(模拟响应体.count)字符，预览前\(响应体最大输出长度)字符：\n\(预览)\n...\n")
        } else {
            追加输出("[输入响应体]\n\(模拟响应体)\n")
        }
        追加输出("---------- 脚本执行 ----------\n")

        // 将用户代码包装在IIFE中，模拟圈X真实运行环境，支持顶层return
        let 包装后代码 = "(function() {\n\(代码)\n})();"
        当前执行代码 = 包装后代码
        let 工作项 = DispatchWorkItem { [weak self] in
            _ = self?.上下文.evaluateScript(包装后代码)
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

    /// 追加输出文本并通知回调（统一在主队列执行，确保线程安全）
    private func 追加输出(_ 文本: String) {
        输出队列.async { [weak self] in
            guard let 自身 = self else { return }
            自身.输出文本 += 文本
            自身.输出更新回调?(自身.输出文本)
        }
    }
}
