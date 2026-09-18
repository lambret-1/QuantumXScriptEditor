import Foundation

/// 代码补全服务，提供圈X专用API的补全候选列表
/// 根据用户输入的前缀过滤候选项，支持按分类筛选
enum 代码补全服务 {
    /// 全部内置补全候选项
    static let 全部候选项: [代码补全项] = [
        // MARK: 全局对象
        代码补全项(触发词: "$request", 插入代码: "$request", 中文说明: "请求对象，包含 url、headers、method、body", 分类: .全局对象),
        代码补全项(触发词: "$response", 插入代码: "$response", 中文说明: "响应对象，包含 statusCode、headers、body", 分类: .全局对象),
        代码补全项(触发词: "$done", 插入代码: "$done();", 中文说明: "结束脚本执行，可传入返回值给圈X", 分类: .全局对象),
        代码补全项(触发词: "$notify", 插入代码: "$notify(\"标题\", \"副标题\", \"内容\");", 中文说明: "弹出本地通知，三个参数均为字符串", 分类: .全局对象),
        代码补全项(触发词: "$persistentStore", 插入代码: "$persistentStore", 中文说明: "持久化存储，支持 read/write，重启不丢失", 分类: .全局对象),
        代码补全项(触发词: "$httpClient", 插入代码: "$httpClient", 中文说明: "HTTP客户端，支持 get/post 异步请求", 分类: .全局对象),

        // MARK: 请求相关
        代码补全项(触发词: "$request.headers", 插入代码: "$request.headers", 中文说明: "请求头字典，可读取或修改请求头", 分类: .请求相关),
        代码补全项(触发词: "$request.url", 插入代码: "$request.url", 中文说明: "请求的完整URL字符串", 分类: .请求相关),
        代码补全项(触发词: "$request.method", 插入代码: "$request.method", 中文说明: "请求方法（GET/POST/PUT等）", 分类: .请求相关),
        代码补全项(触发词: "$request.body", 插入代码: "$request.body", 中文说明: "请求体文本", 分类: .请求相关),
        代码补全项(触发词: "修改请求头", 插入代码: "const headers = $request.headers;\nheaders[\"User-Agent\"] = \"自定义UA\";\n$request.headers = headers;\n$done($request);", 中文说明: "完整模板：修改请求头并返回修改后的请求", 分类: .请求相关),

        // MARK: 响应相关
        代码补全项(触发词: "$response.body", 插入代码: "$response.body", 中文说明: "响应体文本，通常需JSON.parse解析", 分类: .响应相关),
        代码补全项(触发词: "$response.statusCode", 插入代码: "$response.statusCode", 中文说明: "HTTP响应状态码（如200、404）", 分类: .响应相关),
        代码补全项(触发词: "$response.headers", 插入代码: "$response.headers", 中文说明: "响应头字典", 分类: .响应相关),
        代码补全项(触发词: "修改响应体", 插入代码: "let body = JSON.parse($response.body);\nbody.data.isVip = true;\n$response.body = JSON.stringify(body);\n$done($response);", 中文说明: "完整模板：解析响应JSON、修改字段、序列化返回", 分类: .响应相关),

        // MARK: 网络请求
        代码补全项(触发词: "$httpClient.get", 插入代码: "$httpClient.get(\"https://example.com/api\", {}, function(error, response) {\n    if (error) { $done(); return; }\n    $done(response);\n});", 中文说明: "GET异步请求，回调参数 (error, response)", 分类: .网络请求),
        代码补全项(触发词: "$httpClient.post", 插入代码: "$httpClient.post(\"https://example.com/api\", {headers:{}, body:\"\"}, function(error, response) {\n    if (error) { $done(); return; }\n    $done(response);\n});", 中文说明: "POST异步请求，选项含 headers 和 body", 分类: .网络请求),

        // MARK: 存储与通知
        代码补全项(触发词: "$persistentStore.write", 插入代码: "$persistentStore.write(\"要保存的值\", \"存储键名\");", 中文说明: "写入持久化存储，参数(值, 键)", 分类: .存储通知),
        代码补全项(触发词: "$persistentStore.read", 插入代码: "$persistentStore.read(\"存储键名\");", 中文说明: "读取持久化存储，返回字符串或null", 分类: .存储通知),
        代码补全项(触发词: "$notify模板", 插入代码: "$notify(\"脚本执行成功\", \"提示\", \"当前操作已完成\");\n$done();", 中文说明: "完整模板：弹出通知并结束脚本", 分类: .存储通知),

        // MARK: 控制流
        代码补全项(触发词: "if判断", 插入代码: "if (条件) {\n    // 条件成立时执行\n} else {\n    // 条件不成立时执行\n}", 中文说明: "条件判断代码块", 分类: .控制流),
        代码补全项(触发词: "for循环", 插入代码: "for (let i = 0; i < 数组.length; i++) {\n    // 遍历数组元素 数组[i]\n}", 中文说明: "for循环遍历数组", 分类: .控制流),
        代码补全项(触发词: "try异常", 插入代码: "try {\n    // 可能出错的代码\n} catch (e) {\n    $notify(\"错误\", \"\", e.message);\n}\n$done();", 中文说明: "异常捕获，出错时弹窗提示", 分类: .控制流)
    ]

    /// 根据输入前缀过滤补全候选项
    /// - Parameter 前缀: 用户当前输入的文本（通常是光标前的单词）
    /// - Returns: 匹配的候选项列表，按分类排序
    static func 过滤候选项(前缀: String) -> [代码补全项] {
        let 清洗前缀 = 前缀.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !清洗前缀.isEmpty else { return 全部候选项 }
        return 全部候选项.filter { 项 in
            项.触发词.lowercased().contains(清洗前缀) ||
            项.中文说明.lowercased().contains(清洗前缀)
        }
    }

    /// 获取所有分类名称
    static var 全部分类: [代码补全项.补全分类] {
        [.全局对象, .请求相关, .响应相关, .网络请求, .存储通知, .控制流]
    }
}
