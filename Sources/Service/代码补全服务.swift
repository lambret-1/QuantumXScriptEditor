import Foundation

/// 代码补全服务，提供圈X专用API与常用JS代码片段的补全候选列表
/// 根据用户输入的前缀过滤候选项，支持按分类筛选
enum 代码补全服务 {
    /// 全部内置补全候选项（100+项，覆盖圈X全量API与常用JS片段）
    static let 全部候选项: [代码补全项] = [
        // MARK: 全局对象
        代码补全项(触发词: "$request", 插入代码: "$request", 中文说明: "请求对象，包含 url、headers、method、body", 分类: .全局对象),
        代码补全项(触发词: "$response", 插入代码: "$response", 中文说明: "响应对象，包含 statusCode、headers、body", 分类: .全局对象),
        代码补全项(触发词: "$done", 插入代码: "$done();", 中文说明: "结束脚本执行，可传入返回值给圈X", 分类: .全局对象),
        代码补全项(触发词: "$notify", 插入代码: "$notify(\"标题\", \"副标题\", \"内容\");", 中文说明: "弹出本地通知，三个参数均为字符串", 分类: .全局对象),
        代码补全项(触发词: "$persistentStore", 插入代码: "$persistentStore", 中文说明: "持久化存储，支持 read/write，重启不丢失", 分类: .全局对象),
        代码补全项(触发词: "$httpClient", 插入代码: "$httpClient", 中文说明: "【Surge API】HTTP客户端，圈X请用$task.fetch（Promise风格）", 分类: .全局对象),
        代码补全项(触发词: "$argument", 插入代码: "$argument", 中文说明: "脚本参数对象，可读取脚本配置的参数", 分类: .全局对象),
        代码补全项(触发词: "$environment", 插入代码: "$environment", 中文说明: "环境变量对象，包含系统与脚本环境信息", 分类: .全局对象),
        代码补全项(触发词: "$prefs", 插入代码: "$prefs", 中文说明: "圈X原生持久化存储对象，setValueForKey/valueForKey读写数据", 分类: .全局对象),
        代码补全项(触发词: "$prefs.setValueForKey", 插入代码: "$prefs.setValueForKey(\"要保存的值\", \"存储键名\");", 中文说明: "圈X原生写入持久化存储，参数(值, 键)", 分类: .存储通知),
        代码补全项(触发词: "$prefs.valueForKey", 插入代码: "$prefs.valueForKey(\"存储键名\");", 中文说明: "圈X原生读取持久化存储，返回字符串或undefined", 分类: .存储通知),
        代码补全项(触发词: "$config", 插入代码: "$config", 中文说明: "配置对象，访问脚本所在节点的配置信息", 分类: .全局对象),
        代码补全项(触发词: "console", 插入代码: "console.log(\"调试信息\");", 中文说明: "控制台输出，圈X标准写法，用于脚本调试（圈X日志中查看）", 分类: .全局对象),
        代码补全项(触发词: "$task", 插入代码: "$task.fetch({url: \"https://example.com\", method: \"GET\"}).then(function(response) { return response.body; });", 中文说明: "圈X高级HTTP任务API，支持Promise风格异步请求", 分类: .全局对象),

        // MARK: 请求相关
        代码补全项(触发词: "$request.headers", 插入代码: "$request.headers", 中文说明: "请求头字典，可读取或修改请求头", 分类: .请求相关),
        代码补全项(触发词: "$request.url", 插入代码: "$request.url", 中文说明: "请求的完整URL字符串", 分类: .请求相关),
        代码补全项(触发词: "$request.method", 插入代码: "$request.method", 中文说明: "请求方法（GET/POST/PUT等）", 分类: .请求相关),
        代码补全项(触发词: "$request.body", 插入代码: "$request.body", 中文说明: "请求体文本", 分类: .请求相关),
        代码补全项(触发词: "$request.path", 插入代码: "$request.path", 中文说明: "请求路径（不含域名）", 分类: .请求相关),
        代码补全项(触发词: "修改请求头", 插入代码: "const headers = $request.headers;\nheaders[\"User-Agent\"] = \"自定义UA\";\n$request.headers = headers;\n$done($request);", 中文说明: "完整模板：修改请求头并返回修改后的请求", 分类: .请求相关),
        代码补全项(触发词: "修改Cookie", 插入代码: "const headers = $request.headers;\nheaders[\"Cookie\"] = \"sessionid=xxx; token=yyy\";\n$request.headers = headers;\n$done($request);", 中文说明: "完整模板：注入或覆盖请求Cookie", 分类: .请求相关),
        代码补全项(触发词: "重定向URL", 插入代码: "$request.url = $request.url.replace(\"旧域名\", \"新域名\");\n$done($request);", 中文说明: "完整模板：替换请求URL中的域名部分", 分类: .请求相关),
        代码补全项(触发词: "阻断请求", 插入代码: "$done({});\n// 直接返回空响应，阻断原请求", 中文说明: "完整模板：阻断请求，返回空响应", 分类: .请求相关),
        代码补全项(触发词: "读取URL参数", 插入代码: "function getQueryParam(url, name) {\n    const regex = new RegExp(\"[?&]\" + name + \"=([^&]*)\");\n    const match = url.match(regex);\n    return match ? decodeURIComponent(match[1]) : null;\n}\nconst token = getQueryParam($request.url, \"token\");", 中文说明: "工具函数：从URL中解析查询参数", 分类: .请求相关),
        代码补全项(触发词: "读取Cookie", 插入代码: "const cookie = $request.headers[\"Cookie\"] || \"\";\nfunction getCookie(name) {\n    const match = cookie.match(new RegExp(\"(?:^|; )\" + name + \"=([^;]*)\"));\n    return match ? match[1] : null;\n}\nconst sessionId = getCookie(\"sessionid\");", 中文说明: "工具函数：从请求头Cookie中解析指定键值", 分类: .请求相关),
        代码补全项(触发词: "修改UA", 插入代码: "const headers = $request.headers;\nheaders[\"User-Agent\"] = \"Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)\";\n$request.headers = headers;\n$done($request);", 中文说明: "完整模板：修改User-Agent请求头", 分类: .请求相关),
        代码补全项(触发词: "重写请求方法", 插入代码: "$request.method = \"POST\";\n$request.headers[\"Content-Type\"] = \"application/x-www-form-urlencoded\";\n$request.body = \"key=value\";\n$done($request);", 中文说明: "完整模板：将GET请求重写为POST并添加请求体", 分类: .请求相关),

        // MARK: 响应相关
        代码补全项(触发词: "$response.body", 插入代码: "$response.body", 中文说明: "响应体文本，通常需JSON.parse解析", 分类: .响应相关),
        代码补全项(触发词: "$response.statusCode", 插入代码: "$response.statusCode", 中文说明: "HTTP响应状态码（如200、404）", 分类: .响应相关),
        代码补全项(触发词: "$response.headers", 插入代码: "$response.headers", 中文说明: "响应头字典", 分类: .响应相关),
        代码补全项(触发词: "修改响应体", 插入代码: "let body = JSON.parse($response.body);\nbody.data.isVip = true;\n$done({ body: JSON.stringify(body) });", 中文说明: "完整模板：解析响应JSON、修改字段、序列化返回", 分类: .响应相关),
        代码补全项(触发词: "替换响应文本", 插入代码: "let body = $response.body;\nbody = body.replace(/旧文本/g, \"新文本\");\n$done({ body: body });", 中文说明: "完整模板：全局替换响应体中的文本", 分类: .响应相关),
        代码补全项(触发词: "修改状态码", 插入代码: "$done({ body: $response.body, statusCode: 200 });", 中文说明: "修改HTTP响应状态码（保留原响应体）", 分类: .响应相关),
        代码补全项(触发词: "添加响应头", 插入代码: "const headers = $response.headers;\nheaders[\"X-Custom-Header\"] = \"自定义值\";\n$done({ body: $response.body, headers: headers });", 中文说明: "完整模板：添加自定义响应头（保留原响应体）", 分类: .响应相关),
        代码补全项(触发词: "安全解析响应JSON", 插入代码: "let body = {};\ntry {\n    body = JSON.parse($response.body);\n} catch (e) {\n    console.log(\"JSON解析失败: \" + e.message);\n    $done();\n    return;\n}", 中文说明: "完整模板：带异常捕获的响应体JSON解析，失败时原样返回", 分类: .响应相关),
        代码补全项(触发词: "注入JS到HTML", 插入代码: "let body = $response.body;\nconst 注入脚本 = \"<script>alert('注入成功')</script>\";\nbody = body.replace(\"</head>\", 注入脚本 + \"</head>\");\n$done({ body: body });", 中文说明: "完整模板：向HTML响应中注入JS脚本（需响应类型为HTML）", 分类: .响应相关),
        代码补全项(触发词: "修改响应状态码", 插入代码: "$done({ body: $response.body, statusCode: 200 });", 中文说明: "修改HTTP响应状态码（保留原响应体）", 分类: .响应相关),
        代码补全项(触发词: "四级容错模板", 插入代码: "const 原始响应体 = ($response && $response.body) || \"\";\ntry {\n    let body = {};\n    try { body = JSON.parse($response.body); } catch (e) { $done({ body: 原始响应体 }); return; }\n    // TODO: 在这里修改body字段\n    $done({ body: JSON.stringify(body) });\n} catch (错误) {\n    console.log(\"[兜底] 脚本异常: \" + 错误.message);\n    $done({ body: 原始响应体 });\n}", 中文说明: "完整四级容错模板：空值保护/数据校验/异常隔离/兜底返回，任何异常都返回原始响应", 分类: .响应相关),
        代码补全项(触发词: "安全读取嵌套字段", 插入代码: "function 安全读取(obj, 路径) {\n    return String(路径).split(\".\").reduce(function(o, k) {\n        return (o || {})[k];\n    }, obj);\n}", 中文说明: "工具函数：安全读取嵌套JSON字段，字段不存在时返回undefined不崩溃", 分类: .响应相关),

        // MARK: 网络请求
        代码补全项(触发词: "$httpClient.get", 插入代码: "$httpClient.get(\"https://example.com/api\", {}, function(error, response) {\n    if (error) { $done(); return; }\n    $done(response);\n});", 中文说明: "GET异步请求，回调参数 (error, response)", 分类: .网络请求),
        代码补全项(触发词: "$httpClient.post", 插入代码: "$httpClient.post(\"https://example.com/api\", {headers:{\"Content-Type\":\"application/json\"}, body:JSON.stringify({key:\"value\"})}, function(error, response) {\n    if (error) { $done(); return; }\n    $done(response);\n});", 中文说明: "POST异步请求，选项含 headers 和 body", 分类: .网络请求),
        代码补全项(触发词: "$httpClient.put", 插入代码: "$httpClient.put(\"https://example.com/api/1\", {headers:{}, body:\"\"}, function(error, response) {\n    if (error) { $done(); return; }\n    $done(response);\n});", 中文说明: "PUT异步请求，用于更新资源", 分类: .网络请求),
        代码补全项(触发词: "$httpClient.delete", 插入代码: "$httpClient.delete(\"https://example.com/api/1\", {}, function(error, response) {\n    if (error) { $done(); return; }\n    $done(response);\n});", 中文说明: "DELETE异步请求，用于删除资源", 分类: .网络请求),
        代码补全项(触发词: "并发请求", 插入代码: "let 完成数 = 0;\nconst 总请求数 = 2;\nfunction 检查完成() {\n    完成数++;\n    if (完成数 >= 总请求数) { $done(); }\n}\n$httpClient.get(\"url1\", {}, function(e, r) { 检查完成(); });\n$httpClient.get(\"url2\", {}, function(e, r) { 检查完成(); });", 中文说明: "完整模板：并发多个请求，全部完成后调用$done", 分类: .网络请求),

        // MARK: 存储与通知
        代码补全项(触发词: "$persistentStore.write", 插入代码: "$persistentStore.write(\"要保存的值\", \"存储键名\");", 中文说明: "【Surge API】写入持久化存储，圈X请用$prefs.setValueForKey", 分类: .存储通知),
        代码补全项(触发词: "$persistentStore.read", 插入代码: "$persistentStore.read(\"存储键名\");", 中文说明: "【Surge API】读取持久化存储，圈X请用$prefs.valueForKey", 分类: .存储通知),
        代码补全项(触发词: "计数器", 插入代码: "let count = parseInt($persistentStore.read(\"计数\") || \"0\");\ncount++;\n$persistentStore.write(String(count), \"计数\");\n$notify(\"计数\", \"\", \"已运行\" + count + \"次\");\n$done();", 中文说明: "完整模板：持久化计数器，每次运行自增", 分类: .存储通知),
        代码补全项(触发词: "存储JSON对象", 插入代码: "// 写入对象\nconst obj = {name: \"test\", value: 123};\n$persistentStore.write(JSON.stringify(obj), \"配置键\");\n// 读取对象\nconst data = JSON.parse($persistentStore.read(\"配置键\") || \"{}\");", 中文说明: "完整模板：持久化存储JSON对象（序列化与反序列化）", 分类: .存储通知),
        代码补全项(触发词: "$notify模板", 插入代码: "$notify(\"脚本执行成功\", \"提示\", \"当前操作已完成\");\n$done();", 中文说明: "完整模板：弹出通知并结束脚本", 分类: .存储通知),
        代码补全项(触发词: "$notify带链接", 插入代码: "$notify(\"标题\", \"副标题\", \"消息\", {\"open-url\": \"https://example.com\"});", 中文说明: "圈X原生通知带跳转链接，点击通知后打开指定URL", 分类: .存储通知),
        代码补全项(触发词: "环境检测", 插入代码: "const isQuanX = typeof $task != \"undefined\";\nconst isSurge = typeof $httpClient != \"undefined\";\nconsole.log(\"圈X: \" + isQuanX + \", Surge: \" + isSurge);", 中文说明: "检测当前运行环境（圈X/Surge），编写跨平台兼容脚本", 分类: .全局对象),
        代码补全项(触发词: "条件通知", 插入代码: "if (条件成立) {\n    $notify(\"标题\", \"副标题\", \"内容\");\n}\n$done();", 中文说明: "完整模板：满足条件时弹出通知", 分类: .存储通知),
        代码补全项(触发词: "删除存储键", 插入代码: "$persistentStore.write(\"\", \"要删除的键名\");", 中文说明: "通过写入空字符串删除持久化存储中的键", 分类: .存储通知),
        代码补全项(触发词: "存储布尔值", 插入代码: "$persistentStore.write(\"true\", \"开关状态\");\nconst 开关 = $persistentStore.read(\"开关状态\") === \"true\";", 中文说明: "持久化存储布尔值（字符串存储，读取时比较）", 分类: .存储通知),

        // MARK: 控制流
        代码补全项(触发词: "if判断", 插入代码: "if (条件) {\n    // 条件成立时执行\n} else {\n    // 条件不成立时执行\n}", 中文说明: "条件判断代码块", 分类: .控制流),
        代码补全项(触发词: "for循环", 插入代码: "for (let i = 0; i < 数组.length; i++) {\n    // 遍历数组元素 数组[i]\n}", 中文说明: "for循环遍历数组", 分类: .控制流),
        代码补全项(触发词: "forEach遍历", 插入代码: "数组.forEach(function(元素, 索引) {\n    // 处理每个元素\n});", 中文说明: "forEach方法遍历数组", 分类: .控制流),
        代码补全项(触发词: "switch分支", 插入代码: "switch (变量) {\n    case \"值1\":\n        // 处理值1\n        break;\n    case \"值2\":\n        // 处理值2\n        break;\n    default:\n        // 默认处理\n}", 中文说明: "switch多分支判断", 分类: .控制流),
        代码补全项(触发词: "try异常", 插入代码: "try {\n    // 可能出错的代码\n} catch (e) {\n    $notify(\"错误\", \"\", e.message);\n}\n$done();", 中文说明: "异常捕获，出错时弹窗提示", 分类: .控制流),
        代码补全项(触发词: "while循环", 插入代码: "let i = 0;\nwhile (i < 10) {\n    // 循环体\n    i++;\n}", 中文说明: "while循环，条件满足时持续执行", 分类: .控制流),
        代码补全项(触发词: "提前结束", 插入代码: "$done();\nreturn;", 中文说明: "立即结束脚本执行（用于条件不满足时提前退出）", 分类: .控制流),
        代码补全项(触发词: "三元表达式", 插入代码: "const 结果 = 条件 ? \"条件成立\" : \"条件不成立\";", 中文说明: "三元条件表达式，简化if-else赋值", 分类: .控制流),
        代码补全项(触发词: "可选链访问", 插入代码: "const 值 = 对象?.属性?.子属性 ?? \"默认值\";", 中文说明: "可选链访问嵌套属性，避免undefined报错（需iOS15+ JS引擎）", 分类: .控制流),

        // MARK: 加密编码
        代码补全项(触发词: "Base64编码", 插入代码: "const encoded = $base64.encode(\"要编码的文本\");", 中文说明: "Base64编码文本", 分类: .加密编码),
        代码补全项(触发词: "Base64解码", 插入代码: "const decoded = $base64.decode(\"要解码的Base64字符串\");", 中文说明: "Base64解码文本", 分类: .加密编码),
        代码补全项(触发词: "MD5哈希", 插入代码: "const hash = $md5(\"要哈希的文本\");", 中文说明: "计算MD5哈希值", 分类: .加密编码),
        代码补全项(触发词: "URL编码", 插入代码: "const encoded = encodeURIComponent(\"要编码的文本\");", 中文说明: "URL编码（encodeURIComponent）", 分类: .加密编码),
        代码补全项(触发词: "URL解码", 插入代码: "const decoded = decodeURIComponent(\"要解码的文本\");", 中文说明: "URL解码（decodeURIComponent）", 分类: .加密编码),
        代码补全项(触发词: "JSON转Base64", 插入代码: "const obj = {key: \"value\"};\nconst jsonStr = JSON.stringify(obj);\nconst base64 = $base64.encode(jsonStr);", 中文说明: "完整模板：将JSON对象转为Base64字符串", 分类: .加密编码),
        代码补全项(触发词: "SHA1哈希", 插入代码: "const hash = $sha1(\"要哈希的文本\");", 中文说明: "计算SHA1哈希值（圈X内置）", 分类: .加密编码),
        代码补全项(触发词: "SHA256哈希", 插入代码: "const hash = $sha256(\"要哈希的文本\");", 中文说明: "计算SHA256哈希值（圈X内置）", 分类: .加密编码),
        代码补全项(触发词: "HMAC签名", 插入代码: "const signature = $hmac.alg(\"SHA256\", \"密钥\", \"要签名的数据\");", 中文说明: "HMAC签名，支持MD5/SHA1/SHA256等算法", 分类: .加密编码),
        代码补全项(触发词: "随机字符串", 插入代码: "function randomString(length) {\n    const chars = \"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789\";\n    let result = \"\";\n    for (let i = 0; i < length; i++) {\n        result += chars.charAt(Math.floor(Math.random() * chars.length));\n    }\n    return result;\n}\nconst nonce = randomString(16);", 中文说明: "工具函数：生成指定长度的随机字符串（常用于nonce/防重放）", 分类: .加密编码),
        代码补全项(触发词: "时间戳随机数", 插入代码: "const timestamp = Math.floor(Date.now() / 1000);\nconst nonce = Math.random().toString(36).substring(2, 10);", 中文说明: "生成秒级时间戳和随机nonce（API签名常用）", 分类: .加密编码),

        // MARK: 日期时间
        代码补全项(触发词: "当前时间戳", 插入代码: "const timestamp = Date.now();\n// 返回毫秒级时间戳", 中文说明: "获取当前毫秒级时间戳", 分类: .日期时间),
        代码补全项(触发词: "时间戳转日期", 插入代码: "function formatTime(timestamp) {\n    const d = new Date(timestamp);\n    const y = d.getFullYear();\n    const m = String(d.getMonth() + 1).padStart(2, \"0\");\n    const day = String(d.getDate()).padStart(2, \"0\");\n    const h = String(d.getHours()).padStart(2, \"0\");\n    const min = String(d.getMinutes()).padStart(2, \"0\");\n    return y + \"-\" + m + \"-\" + day + \" \" + h + \":\" + min;\n}\nconst now = formatTime(Date.now());", 中文说明: "工具函数：时间戳格式化为 yyyy-MM-dd HH:mm", 分类: .日期时间),
        代码补全项(触发词: "日期加减", 插入代码: "const now = new Date();\n// 加1天\nnow.setDate(now.getDate() + 1);\n// 加1小时\nnow.setHours(now.getHours() + 1);\nconst timestamp = now.getTime();", 中文说明: "完整模板：日期时间加减运算", 分类: .日期时间),
        代码补全项(触发词: "计算时间差", 插入代码: "const 开始 = new Date(\"2024-01-01\");\nconst 结束 = new Date();\nconst 差毫秒 = 结束 - 开始;\nconst 差天 = Math.floor(差毫秒 / (1000 * 60 * 60 * 24));", 中文说明: "完整模板：计算两个日期之间的天数差", 分类: .日期时间),

        // MARK: 字符串处理
        代码补全项(触发词: "字符串替换", 插入代码: "const 结果 = 原字符串.replace(/要替换的内容/g, \"替换为\");\n// g标志表示全局替换", 中文说明: "字符串全局替换（正则方式）", 分类: .字符串处理),
        代码补全项(触发词: "字符串分割", 插入代码: "const 数组 = 字符串.split(\"分隔符\");\n// 例如 \"a,b,c\".split(\",\") 得到 [\"a\",\"b\",\"c\"]", 中文说明: "按分隔符分割字符串为数组", 分类: .字符串处理),
        代码补全项(触发词: "字符串截取", 插入代码: "const 子串 = 字符串.substring(起始索引, 结束索引);\n// 或 字符串.slice(起始, 结束)", 中文说明: "截取字符串子串", 分类: .字符串处理),
        代码补全项(触发词: "去除首尾空白", 插入代码: "const 结果 = 字符串.trim();", 中文说明: "去除字符串首尾空白字符", 分类: .字符串处理),
        代码补全项(触发词: "字符串包含", 插入代码: "if (字符串.includes(\"子串\")) {\n    // 包含子串时执行\n}", 中文说明: "判断字符串是否包含指定子串", 分类: .字符串处理),
        代码补全项(触发词: "字符串转大小写", 插入代码: "const 大写 = 字符串.toUpperCase();\nconst 小写 = 字符串.toLowerCase();", 中文说明: "字符串大小写转换", 分类: .字符串处理),
        代码补全项(触发词: "模板字符串", 插入代码: "const 名称 = \"圈X\";\nconst 结果 = `你好，${名称}！当前版本是v1.0`;\n// 使用反引号和${}插入变量", 中文说明: "模板字符串（反引号语法，变量插值）", 分类: .字符串处理),
        代码补全项(触发词: "字符串重复", 插入代码: "const 分隔线 = \"-\".repeat(20);\n// 生成20个减号组成的分隔线", 中文说明: "重复字符串指定次数", 分类: .字符串处理),
        代码补全项(触发词: "字符串填充", 插入代码: "const 编号 = String(42).padStart(5, \"0\");\n// 结果为 \"00042\"，左侧填充0到5位", 中文说明: "字符串左侧填充到指定长度（padStart）", 分类: .字符串处理),
        代码补全项(触发词: "字符串反转", 插入代码: "const 反转 = 字符串.split(\"\").reverse().join(\"\");", 中文说明: "反转字符串（分割为数组→反转→拼接）", 分类: .字符串处理),

        // MARK: 正则匹配
        代码补全项(触发词: "正则测试", 插入代码: "const 正则 = /匹配规则/;\nif (正则.test(待测试字符串)) {\n    // 匹配成功时执行\n}", 中文说明: "正则表达式测试是否匹配", 分类: .正则匹配),
        代码补全项(触发词: "正则提取", 插入代码: "const 正则 = /规则(捕获组)/;\nconst 匹配 = 字符串.match(正则);\nif (匹配) {\n    const 捕获内容 = 匹配[1];\n}", 中文说明: "正则提取捕获组内容", 分类: .正则匹配),
        代码补全项(触发词: "正则替换", 插入代码: "const 结果 = 字符串.replace(/正则/g, \"替换文本\");", 中文说明: "正则全局替换", 分类: .正则匹配),
        代码补全项(触发词: "匹配数字", 插入代码: "const 数字数组 = 字符串.match(/\\d+/g);\n// 提取字符串中所有数字", 中文说明: "提取字符串中的所有数字", 分类: .正则匹配),
        代码补全项(触发词: "匹配URL", 插入代码: "const url正则 = /https?:\\/\\/[^\\s\"']+/g;\nconst url列表 = 文本.match(url正则);", 中文说明: "从文本中提取所有URL链接", 分类: .正则匹配),
        代码补全项(触发词: "匹配中文字符", 插入代码: "const 中文正则 = /[\\u4e00-\\u9fa5]+/g;\nconst 中文列表 = 文本.match(中文正则);", 中文说明: "提取文本中的所有中文字符", 分类: .正则匹配),

        // MARK: 数学运算
        代码补全项(触发词: "四舍五入", 插入代码: "const 结果 = Math.round(数字 * 100) / 100;\n// 保留2位小数四舍五入", 中文说明: "四舍五入保留指定小数位", 分类: .数学运算),
        代码补全项(触发词: "随机数", 插入代码: "const 随机 = Math.floor(Math.random() * 100);\n// 生成0-99的随机整数", 中文说明: "生成指定范围的随机整数", 分类: .数学运算),
        代码补全项(触发词: "取最大值最小值", 插入代码: "const 最大 = Math.max(1, 5, 3);\nconst 最小 = Math.min(1, 5, 3);\n// 数组用 Math.max(...数组)", 中文说明: "取最大值与最小值", 分类: .数学运算),
        代码补全项(触发词: "绝对值", 插入代码: "const 结果 = Math.abs(数字);", 中文说明: "取绝对值", 分类: .数学运算),
        代码补全项(触发词: "向上向下取整", 插入代码: "const 向上 = Math.ceil(3.2); // 结果4\nconst 向下 = Math.floor(3.8); // 结果3", 中文说明: "向上取整与向下取整", 分类: .数学运算),
        代码补全项(触发词: "范围随机数", 插入代码: "function randomInt(min, max) {\n    return Math.floor(Math.random() * (max - min + 1)) + min;\n}\nconst 结果 = randomInt(1, 100); // 1到100之间的随机整数", 中文说明: "生成指定范围内的随机整数（含首尾）", 分类: .数学运算),
        代码补全项(触发词: "数字千分位", 插入代码: "const 格式化 = 数字.toLocaleString(\"en-US\");\n// 例如 1234567 → \"1,234,567\"", 中文说明: "数字格式化为千分位字符串", 分类: .数学运算),

        // MARK: JSON处理
        代码补全项(触发词: "JSON解析", 插入代码: "const 对象 = JSON.parse(json字符串);", 中文说明: "将JSON字符串解析为JS对象", 分类: .JSON处理),
        代码补全项(触发词: "JSON序列化", 插入代码: "const json字符串 = JSON.stringify(对象);\n// 美化输出：JSON.stringify(对象, null, 2)", 中文说明: "将JS对象序列化为JSON字符串", 分类: .JSON处理),
        代码补全项(触发词: "安全JSON解析", 插入代码: "let 对象 = {};\ntry {\n    对象 = JSON.parse(json字符串);\n} catch (e) {\n    $notify(\"解析失败\", \"\", e.message);\n}", 中文说明: "完整模板：带异常捕获的安全JSON解析", 分类: .JSON处理),
        代码补全项(触发词: "遍历JSON对象", 插入代码: "for (const 键 in 对象) {\n    const 值 = 对象[键];\n    // 处理每个键值对\n}", 中文说明: "遍历JSON对象的所有键值对", 分类: .JSON处理),
        代码补全项(触发词: "深拷贝对象", 插入代码: "const 拷贝 = JSON.parse(JSON.stringify(原对象));", 中文说明: "通过JSON序列化实现对象深拷贝", 分类: .JSON处理),
        代码补全项(触发词: "合并对象", 插入代码: "const 合并结果 = Object.assign({}, 对象1, 对象2);\n// 后续对象的属性覆盖前面的", 中文说明: "合并多个对象（Object.assign）", 分类: .JSON处理),
        代码补全项(触发词: "安全访问嵌套字段", 插入代码: "function getNested(obj, path, 默认值) {\n    return path.split(\".\").reduce(function(o, k) {\n        return (o || {})[k];\n    }, obj) || 默认值;\n}\nconst 值 = getNested(响应, \"data.user.name\", \"未知\");", 中文说明: "工具函数：安全访问嵌套对象字段，路径不存在时返回默认值", 分类: .JSON处理),
        代码补全项(触发词: "对象转数组", 插入代码: "const 数组 = Object.keys(对象).map(function(键) {\n    return { 键: 键, 值: 对象[键] };\n});", 中文说明: "将对象的键值对转换为数组（便于遍历排序）", 分类: .JSON处理),
        代码补全项(触发词: "数组去重", 插入代码: "const 去重后 = [...new Set(原数组)];\n// 例如 [1,2,2,3] → [1,2,3]", 中文说明: "数组去重（Set+扩展运算符）", 分类: .JSON处理)
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
        代码补全项.补全分类.allCases
    }
}
