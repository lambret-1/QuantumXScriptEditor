import SwiftUI

// MARK: - 新手教程数据模型

/// 教程分类
enum 教程分类: String, CaseIterable, Identifiable {
    case 基础语法 = "基础语法"
    case 数据类型 = "数据类型"
    case 圈X专用API = "圈X专用API"
    case 常用操作 = "常用操作"
    var id: String { rawValue }
}

/// 单个教程项
struct 教程项: Identifiable {
    let id = UUID()
    /// 关键词（如 let、if、$done）
    let 关键词: String
    /// 中文说明
    let 说明: String
    /// 代码示例
    let 示例: String
    /// 所属分类
    let 分类: 教程分类
}

// MARK: - 新手教程数据（基于圈X官方文档整理）

/// 新手教程数据库，包含JS基础语法和圈X专用API说明
enum 新手教程数据 {
    /// 全部教程项
    static let 全部教程: [教程项] = [
        // MARK: 基础语法
        教程项(关键词: "let", 说明: "声明一个可变变量，作用域为当前代码块。推荐优先使用let而非var。", 示例: "let 名称 = \"圈X\";\n名称 = \"新名称\"; // 可以重新赋值", 分类: .基础语法),
        教程项(关键词: "const", 说明: "声明一个常量，声明后不可重新赋值。用于不会改变的值。", 示例: "const PI = 3.14159;\nPI = 3; // 报错！常量不可修改", 分类: .基础语法),
        教程项(关键词: "var", 说明: "声明一个变量，作用域为函数级。旧写法，建议用let替代。", 示例: "var 计数 = 0;\n计数 = 1; // 可以重新赋值", 分类: .基础语法),
        教程项(关键词: "if", 说明: "条件判断语句，条件为true时执行代码块。", 示例: "if (body.data.isVip === 1) {\n    console.log(\"是VIP\");\n}", 分类: .基础语法),
        教程项(关键词: "if...else", 说明: "条件判断，条件为true执行if块，否则执行else块。", 示例: "if (body.data.isVip === 1) {\n    console.log(\"是VIP\");\n} else {\n    console.log(\"不是VIP\");\n}", 分类: .基础语法),
        教程项(关键词: "for", 说明: "循环语句，重复执行代码块指定次数。", 示例: "for (let i = 0; i < 5; i++) {\n    console.log(\"第\" + i + \"次\");\n}", 分类: .基础语法),
        教程项(关键词: "while", 说明: "循环语句，条件为true时重复执行。", 示例: "let i = 0;\nwhile (i < 5) {\n    console.log(i);\n    i++;\n}", 分类: .基础语法),
        教程项(关键词: "function", 说明: "声明一个函数，可重复调用的代码块。", 示例: "function 打招呼(名称) {\n    return \"你好，\" + 名称;\n}\nconsole.log(打招呼(\"圈X\"));", 分类: .基础语法),
        教程项(关键词: "return", 说明: "从函数中返回值，并结束函数执行。注意：顶层return必须放在函数内。", 示例: "function 加法(a, b) {\n    return a + b;\n}\nlet 结果 = 加法(1, 2); // 3", 分类: .基础语法),
        教程项(关键词: "try...catch", 说明: "异常捕获，try块中代码出错时执行catch块，防止脚本崩溃。", 示例: "try {\n    let 数据 = JSON.parse(响应体);\n} catch (错误) {\n    console.log(\"解析失败：\" + 错误.message);\n}", 分类: .基础语法),
        教程项(关键词: "typeof", 说明: "判断值的类型，返回字符串如\"string\"、\"number\"、\"object\"、\"undefined\"。", 示例: "typeof \"hello\" === \"string\";\ntypeof 123 === \"number\";\ntypeof {} === \"object\";\ntypeof undefined === \"undefined\";", 分类: .基础语法),

        // MARK: 数据类型
        教程项(关键词: "String", 说明: "字符串类型，用单引号或双引号包裹。", 示例: "let 文本 = \"Hello\";\nlet 长度 = 文本.length; // 5\nlet 大写 = 文本.toUpperCase(); // HELLO", 分类: .数据类型),
        教程项(关键词: "Number", 说明: "数字类型，包括整数和小数。", 示例: "let 整数 = 100;\nlet 小数 = 3.14;\nlet 转数字 = parseInt(\"123\"); // 123", 分类: .数据类型),
        教程项(关键词: "Boolean", 说明: "布尔类型，值为true或false。圈X中VIP状态常用数字1表示。", 示例: "let 是VIP = true;\nlet 已购买 = false;\n// 圈X脚本中常用数字：1=是，0=否\nbody.data.isVip = 1;", 分类: .数据类型),
        教程项(关键词: "Array", 说明: "数组，有序的数据集合，用[]包裹。", 示例: "let 列表 = [\"a\", \"b\", \"c\"];\n列表.push(\"d\"); // 末尾添加\nlet 第一个 = 列表[0]; // \"a\"\nlet 长度 = 列表.length; // 4", 分类: .数据类型),
        教程项(关键词: "Object", 说明: "对象，键值对集合，用{}包裹。JSON解析后就是对象。", 示例: "let 用户 = { 名称: \"圈X\", 等级: 6 };\n用户.名称 = \"新名称\"; // 修改属性\nlet 等级 = 用户.等级; // 6", 分类: .数据类型),
        教程项(关键词: "undefined", 说明: "未定义，表示变量已声明但未赋值，或对象属性不存在。", 示例: "let x;\nconsole.log(x); // undefined\nif (body.data === undefined) {\n    console.log(\"data不存在\");\n}", 分类: .数据类型),
        教程项(关键词: "null", 说明: "空值，表示故意赋值为空。与undefined不同。", 示例: "let 数据 = null;\nif (数据 === null) {\n    console.log(\"数据为空\");\n}", 分类: .数据类型),

        // MARK: 圈X专用API
        教程项(关键词: "$done", 说明: "【最重要】圈X脚本完成函数，必须调用！告诉圈X脚本执行完毕，传入修改后的响应。参数：{}=放行，{body:...}=修改响应体。", 示例: "// 修改响应体后必须调用\n$done({ body: JSON.stringify(body) });\n// 不修改直接放行\n$done({});\n// 放弃请求\n$done();", 分类: .圈X专用API),
        教程项(关键词: "$request", 说明: "请求对象，包含当前网络请求的信息。属性：url(网址)、method(方法)、headers(请求头)、body(请求体)、path(路径)、scheme(协议)。", 示例: "// 读取请求信息\nlet 网址 = $request.url;\nlet 方法 = $request.method;\nlet 请求头 = $request.headers;\nlet 请求体 = $request.body;", 分类: .圈X专用API),
        教程项(关键词: "$response", 说明: "响应对象，包含服务器返回的响应信息。属性：statusCode(状态码)、headers(响应头)、body(响应体文本)。仅在script-response-body类型脚本中可用。", 示例: "// 读取响应体\nlet 状态码 = $response.statusCode;\nlet 响应头 = $response.headers;\nlet 响应体文本 = $response.body;\n// 解析为JSON对象\nlet body = JSON.parse(响应体文本);", 分类: .圈X专用API),
        教程项(关键词: "$task.fetch", 说明: "圈X原生网络请求API，Promise风格。用于在脚本中发起额外的HTTP请求。注意：不是$httpClient（那是Surge的）。", 示例: "$task.fetch({\n    url: \"https://api.example.com/data\",\n    method: \"GET\",\n    headers: { \"Authorization\": \"Bearer xxx\" }\n}).then(function(响应) {\n    console.log(\"状态码：\" + 响应.statusCode);\n    console.log(\"响应体：\" + 响应.body);\n}, function(错误) {\n    console.log(\"请求失败：\" + 错误);\n});", 分类: .圈X专用API),
        教程项(关键词: "$prefs", 说明: "圈X原生持久化存储API，用于保存和读取数据。方法：setValueForKey(值,键)、valueForKey(键)、removeValueForKey(键)、removeAllValues()。注意：不是$persistentStore（那是Surge的）。", 示例: "// 保存数据\n$prefs.setValueForKey(\"圈X用户\", \"用户名\");\n// 读取数据\nlet 用户名 = $prefs.valueForKey(\"用户名\");\n// 删除数据\n$prefs.removeValueForKey(\"用户名\");", 分类: .圈X专用API),
        教程项(关键词: "$notify", 说明: "圈X通知弹窗API，发送iOS系统通知。4个参数：标题、副标题、消息、选项（可选）。需在圈X设置中开启通知。", 示例: "$notify(\n    \"脚本执行完成\",\n    \"VIP已解锁\",\n    \"会员状态已修改为VIP6\",\n    { \"open-url\": \"https://example.com\" }\n);", 分类: .圈X专用API),
        教程项(关键词: "console.log", 说明: "调试输出函数，在圈X日志级别为debug时输出到日志文件。注意：圈X中console前面不需要加$（$console是旧写法，已兼容）。", 示例: "console.log(\"脚本开始执行\");\nconsole.log(\"响应体长度：\" + body.length);\nconsole.log(\"VIP状态：\" + body.data.isVip);", 分类: .圈X专用API),
        教程项(关键词: "setTimeout", 说明: "延时执行函数，在指定毫秒后运行代码。第一个参数是函数，第二个参数是毫秒数。", 示例: "setTimeout(function() {\n    console.log(\"1秒后执行\");\n}, 1000);", 分类: .圈X专用API),

        // MARK: 常用操作
        教程项(关键词: "JSON.parse", 说明: "将JSON文本字符串解析为JavaScript对象。这是修改响应体的第一步——把\"文本\"翻译成\"能修改的对象\"。", 示例: "let 响应体文本 = $response.body;\nlet body = {};\ntry {\n    body = JSON.parse(响应体文本);\n} catch (e) {\n    // 不是JSON格式，原样放行\n    $done({ body: 响应体文本 });\n    return;\n}", 分类: .常用操作),
        教程项(关键词: "JSON.stringify", 说明: "将JavaScript对象序列化为JSON文本字符串。这是修改响应体的最后一步——把\"改好的对象\"重新\"压回\"文本，然后传给$done。", 示例: "// 修改对象字段\nbody.data.isVip = 1;\n// 序列化为文本并返回\n$done({ body: JSON.stringify(body) });", 分类: .常用操作),
        教程项(关键词: "安全访问嵌套对象", 说明: "安全访问嵌套对象属性，避免因某层不存在而报错。统一初始化父级路径后直接赋值，是圈X脚本的推荐写法。", 示例: "// 统一初始化（推荐写法，只检查一次）\nif (!body.data || typeof body.data !== \"object\") body.data = {};\nif (!body.data.user || typeof body.data.user !== \"object\") body.data.user = {};\n// 直接修改（初始化后不需要再判断）\nbody.data.user.isVip = 1;\nbody.data.user.nickname = \"新昵称\";", 分类: .常用操作),
        教程项(关键词: "数组filter过滤", 说明: "数组过滤方法，返回满足条件的新数组。常用于去广告——从列表中过滤掉广告项。", 示例: "// 从列表中过滤广告项\nbody.data.list = body.data.list.filter(function(项) {\n    // 保留非广告项\n    return 项.isAd !== 1 && 项.type !== \"ad\";\n});", 分类: .常用操作),
        教程项(关键词: "delete删除属性", 说明: "删除对象的某个属性。常用于去广告——删除响应中的广告字段。", 示例: "// 删除广告字段\ndelete body.data.ad;\ndelete body.data.banner;\n// 安全删除（先判断是否存在）\nif (body.data.ad !== undefined) {\n    delete body.data.ad;\n}", 分类: .常用操作),
        教程项(关键词: "字符串替换", 说明: "字符串替换方法，用于修改文本内容。支持正则表达式。", 示例: "// 简单替换\nlet 新文本 = 原文本.replace(\"旧内容\", \"新内容\");\n// 正则替换（全局替换）\nlet 结果 = 文本.replace(/广告/g, \"\");\n// 手机号掩码\nlet 掩码 = 手机号.replace(/(\\d{3})\\d{4}(\\d{4})/, \"$1****$2\");", 分类: .常用操作),
    ]

    /// 按分类获取教程项
    static func 按分类(_ 分类: 教程分类) -> [教程项] {
        全部教程.filter { $0.分类 == 分类 }
    }

    /// 搜索教程
    static func 搜索(_ 关键词: String) -> [教程项] {
        guard !关键词.trimmingCharacters(in: .whitespaces).isEmpty else { return 全部教程 }
        return 全部教程.filter { 项 in
            项.关键词.lowercased().contains(关键词.lowercased()) ||
            项.说明.contains(关键词)
        }
    }
}

// MARK: - 新手教程弹窗

/// 新手教程弹窗，展示JS基础语法和圈X专用API说明
struct 新手教程弹窗: View {
    /// 关闭回调
    var 关闭回调: (() -> Void)?
    /// 当前选中的分类
    @State private var 当前分类: 教程分类? = nil
    /// 搜索关键词
    @State private var 搜索关键词 = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture { 关闭回调?() }

            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Image(systemName: "book.fill")
                        .font(.system(size: 20)) // 20pt标题图标
                        .foregroundColor(.blue)
                    Text("新手教程")
                        .font(.headline)
                    Spacer()
                    Button(action: { 关闭回调?() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22)) // 22pt关闭按钮
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // 搜索框
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("搜索关键词（如 let、$done）", text: $搜索关键词)
                        .font(.subheadline)
                        .textFieldStyle(PlainTextFieldStyle())
                    if !搜索关键词.isEmpty {
                        Button(action: { 搜索关键词 = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                // 分类选择标签
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // 全部
                        Button(action: { 当前分类 = nil }) {
                            Text("全部")
                                .font(.caption)
                                .fontWeight(当前分类 == nil ? .semibold : .regular)
                                .foregroundColor(当前分类 == nil ? .white : .blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(当前分类 == nil ? Color.blue : Color.blue.opacity(0.12))
                                .cornerRadius(14)
                        }
                        ForEach(教程分类.allCases) { 分类 in
                            Button(action: { 当前分类 = 分类 }) {
                                Text(分类.rawValue)
                                    .font(.caption)
                                    .fontWeight(当前分类 == 分类 ? .semibold : .regular)
                                    .foregroundColor(当前分类 == 分类 ? .white : .blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(当前分类 == 分类 ? Color.blue : Color.blue.opacity(0.12))
                                    .cornerRadius(14)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 8)

                // 教程列表
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(过滤后的教程) { 项 in
                            教程卡片视图(项: 项)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .frame(maxHeight: UIScreen.main.bounds.height * 0.55) // 最大高度为屏幕55%，避免弹窗过高
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 16)
            .padding(.vertical, 40)
        }
    }

    /// 过滤后的教程列表
    private var 过滤后的教程: [教程项] {
        var 结果 = 新手教程数据.全部教程
        if let 分类 = 当前分类 {
            结果 = 新手教程数据.按分类(分类)
        }
        if !搜索关键词.trimmingCharacters(in: .whitespaces).isEmpty {
            结果 = 新手教程数据.搜索(搜索关键词)
        }
        return 结果
    }
}

// MARK: - 教程卡片视图

/// 单个教程项卡片
struct 教程卡片视图: View {
    let 项: 教程项

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 关键词 + 分类标签
            HStack {
                Text(项.关键词)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                Spacer()
                Text(项.分类.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(UIColor.systemGray5))
                    .cornerRadius(4)
            }

            // 中文说明
            Text(项.说明)
                .font(.caption)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true) // 自动换行

            // 代码示例
            Text(项.示例)
                .font(.system(size: 11, design: .monospaced)) // 11pt等宽字体，代码示例
                .foregroundColor(Color(UIColor.systemGreen))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
