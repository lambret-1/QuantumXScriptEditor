import Foundation

/// 圈X脚本模板库，全部模板附带中文注释
/// 按用途分类，新手可一键插入后按需修改参数
struct 圈X代码模板: Identifiable {
    let id = UUID()
    /// 模板标题
    let 标题: String
    /// 模板分类
    let 分类: 模板分类
    /// 模板代码（含中文注释）
    let 代码: String
    /// 用途说明
    let 用途说明: String
    /// 使用场景描述
    let 使用场景: String

    /// 模板分类枚举
    enum 模板分类: String, CaseIterable {
        /// 请求修改类
        case 请求修改 = "请求修改"
        /// 响应处理类
        case 响应处理 = "响应处理"
        /// 网络请求类
        case 网络请求 = "网络请求"
        /// 存储通知类
        case 存储通知 = "存储通知"
        /// 工具函数类
        case 工具函数 = "工具函数"
    }

    // MARK: - 全部模板定义

    /// 全部内置模板列表
    static let 全部模板: [圈X代码模板] = [
        // MARK: 请求修改类
        圈X代码模板(
            标题: "修改请求头（UA）",
            分类: .请求修改,
            代码: """
// ======================
// 功能：修改请求头 User-Agent
// 场景：模拟特定客户端的UA标识
// ======================
const headers = $request.headers;
// 修改User-Agent为自定义值
headers["User-Agent"] = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)";
$request.headers = headers;
// 必须调用$done并传入修改后的$request
$done($request);
""",
            用途说明: "拦截请求并修改User-Agent请求头",
            使用场景: "部分网站根据UA返回不同页面，可通过修改UA绕过限制"
        ),
        圈X代码模板(
            标题: "修改请求头（Cookie）",
            分类: .请求修改,
            代码: """
// ======================
// 功能：修改或添加请求Cookie
// 场景：注入登录态Cookie
// ======================
const headers = $request.headers;
// 添加或覆盖Cookie
headers["Cookie"] = "sessionid=你的会话ID; token=你的令牌";
$request.headers = headers;
$done($request);
""",
            用途说明: "向请求注入自定义Cookie",
            使用场景: "需要携带特定登录态访问接口时使用"
        ),
        圈X代码模板(
            标题: "重定向请求URL",
            分类: .请求修改,
            代码: """
// ======================
// 功能：将请求重定向到另一个URL
// 场景：把正式环境请求指向测试环境
// ======================
// 替换URL中的域名部分
$request.url = $request.url.replace("https://api.正式.com", "https://api.测试.com");
$done($request);
""",
            用途说明: "修改请求的目标URL地址",
            使用场景: "调试时将正式环境请求重定向到测试环境"
        ),
        圈X代码模板(
            标题: "修改请求体（POST）",
            分类: .请求修改,
            代码: """
// ======================
// 功能：修改POST请求体内容
// 场景：修改提交的表单参数
// ======================
// 解析请求体为JSON（假设是JSON格式）
let body = JSON.parse($request.body);
// 修改参数字段
body.amount = 0.01;
body.count = 1;
// 序列化回字符串
$request.body = JSON.stringify(body);
$done($request);
""",
            用途说明: "解析并修改POST请求的JSON参数",
            使用场景: "修改提交金额、数量等请求参数"
        ),

        // MARK: 响应处理类
        圈X代码模板(
            标题: "修改响应JSON字段",
            分类: .响应处理,
            代码: """
// ======================
// 功能：修改接口返回的JSON数据
// 场景：修改会员状态、余额等字段
// ======================
// 解析响应体
let body = JSON.parse($response.body);
// 示例：将会员状态改为true
if (body.data) {
    body.data.isVip = true;
    body.data.vipExpire = "2099-12-31";
}
// 序列化并写回响应
$response.body = JSON.stringify(body);
$done($response);
""",
            用途说明: "解析响应JSON并修改指定字段",
            使用场景: "修改接口返回的会员状态、用户信息等"
        ),
        圈X代码模板(
            标题: "替换响应文本",
            分类: .响应处理,
            代码: """
// ======================
// 功能：全局替换响应体中的文本
// 场景：替换页面中的特定文字
// ======================
let body = $response.body;
// 将所有"旧文本"替换为"新文本"
body = body.replace(/旧文本/g, "新文本");
$response.body = body;
$done($response);
""",
            用途说明: "对响应体做文本全局替换",
            使用场景: "修改网页文案、替换广告内容等"
        ),
        圈X代码模板(
            标题: "阻断响应（返回空）",
            分类: .响应处理,
            代码: """
// ======================
// 功能：阻断请求，返回空响应
// 场景：屏蔽广告或无用接口
// ======================
$response.body = "{}";
$response.statusCode = 200;
$done($response);
""",
            用途说明: "将响应体替换为空JSON，实现接口屏蔽",
            使用场景: "屏蔽广告接口、数据上报接口等"
        ),
        圈X代码模板(
            标题: "去广告（删除JSON字段）",
            分类: .响应处理,
            代码: """
// ======================
// 功能：删除响应JSON中的广告字段
// 场景：接口返回数据中混入广告位，需要剔除
// ======================
// 解析响应体为JSON对象
let body = JSON.parse($response.body);

// ====== 配置区：在这里填写要删除的广告字段路径 ======
// 支持多级路径，用点号分隔，例如 "data.banner" 表示 body.data.banner
const 要删除的字段 = [
    "data.ad",           // 示例：删除 data 下的 ad 字段
    "data.banner",       // 示例：删除 data 下的 banner 字段
    "data.popup_ad"      // 示例：删除 data 下的 popup_ad 弹窗广告
];
// ==================================================

// 递归删除指定路径的字段
function 删除字段(obj, 路径) {
    const 部分 = 路径.split(".");
    let 当前 = obj;
    // 先导航到父级
    for (let i = 0; i < 部分.length - 1; i++) {
        if (当前[部分[i]] === undefined || 当前[部分[i]] === null) return;
        当前 = 当前[部分[i]];
    }
    // 删除最终字段
    delete 当前[部分[部分.length - 1]];
}

// 遍历删除所有配置的广告字段
要删除的字段.forEach(function(路径) {
    删除字段(body, 路径);
});

// 序列化回字符串并写回响应
$response.body = JSON.stringify(body);
$done($response);
""",
            用途说明: "从JSON响应中删除指定路径的广告字段（支持多级嵌套）",
            使用场景: "接口返回的JSON中包含ad、banner等广告字段，需要剔除后再展示"
        ),
        圈X代码模板(
            标题: "去广告数组（列表过滤广告项）",
            分类: .响应处理,
            代码: """
// ======================
// 功能：从响应JSON的数组中过滤掉广告项
// 场景：信息流、推荐列表中混入广告卡片，需要剔除
// ======================
// 解析响应体
let body = JSON.parse($response.body);

// ====== 配置区 ======
// 广告列表所在的数组路径，用点号分隔
// 例如 "data.list" 表示 body.data.list 数组
const 数组路径 = "data.list";
// 判断一项是否为广告的条件（满足任一即视为广告）
// type 字段等于 "ad" 或 "advert"，或 has_ad 字段为 true
function 是否为广告(项) {
    return 项.type === "ad"
        || 项.type === "advert"
        || 项.has_ad === true
        || 项.is_ad === true
        || (项.ad_id !== undefined && 项.ad_id !== null);
}
// ====================

// 导航到数组
const 部分 = 数组路径.split(".");
let 父级 = body;
let 数组 = body;
for (let i = 0; i < 部分.length - 1; i++) {
    if (父级[部分[i]] === undefined) {
        // 路径不存在，原样返回
        $done($response);
        return;
    }
    父级 = 父级[部分[i]];
}
数组 = 父级[部分[部分.length - 1]];

// 过滤掉广告项，保留非广告内容
if (Array.isArray(数组)) {
    const 过滤后 = 数组.filter(function(项) {
        return !是否为广告(项);
    });
    父级[部分[部分.length - 1]] = 过滤后;
}

// 写回响应
$response.body = JSON.stringify(body);
$done($response);
""",
            用途说明: "从JSON响应的数组列表中过滤掉广告项（按type/is_ad等字段判断）",
            使用场景: "信息流、文章列表、视频推荐等接口中混入广告卡片，需要剔除广告项"
        ),
        圈X代码模板(
            标题: "去广告数组（批量删除多字段）",
            分类: .响应处理,
            代码: """
// ======================
// 功能：批量删除数组中每一项的广告相关字段
// 场景：列表中每一项都带有广告标记字段，需要统一清除
// ======================
let body = JSON.parse($response.body);

// ====== 配置区 ======
// 数组路径
const 数组路径 = "data.list";
// 每个数组项中要删除的广告字段名列表
const 要删除的字段名 = [
    "ad_url",        // 广告跳转链接
    "ad_image",      // 广告图片
    "ad_title",      // 广告标题
    "ad_track",      // 广告追踪
    "is_ad",         // 是否广告标记
    "ad_id"          // 广告ID
];
// ====================

// 导航到数组
const 部分 = 数组路径.split(".");
let 父级 = body;
for (let i = 0; i < 部分.length - 1; i++) {
    if (父级[部分[i]] === undefined) { $done($response); return; }
    父级 = 父级[部分[i]];
}
const 数组 = 父级[部分[部分.length - 1]];

// 遍历数组，批量删除每个项的广告字段
if (Array.isArray(数组)) {
    数组.forEach(function(项) {
        要删除的字段名.forEach(function(字段名) {
            delete 项[字段名];
        });
    });
}

$response.body = JSON.stringify(body);
$done($response);
""",
            用途说明: "批量删除数组中每一项的多个广告相关字段",
            使用场景: "列表接口中每一项都带有ad_url、ad_image等广告字段，需要统一清除"
        ),
        圈X代码模板(
            标题: "去广告（HTML页面移除广告节点）",
            分类: .响应处理,
            代码: """
// ======================
// 功能：从HTML响应中移除广告相关DOM节点
// 场景：网页中包含广告div/iframe，需要在加载前剔除
// ======================
let html = $response.body;

// ====== 配置区：要移除的广告选择器 ======
// 按class、id、标签名等匹配，使用正则全局替换
const 广告匹配规则 = [
    /<div[^>]*class="[^"]*ad[^"]*"[^>]*>[\\s\\S]*?<\\/div>/gi,   // class含ad的div
    /<div[^>]*id="[^"]*ad[^"]*"[^>]*>[\\s\\S]*?<\\/div>/gi,     // id含ad的div
    /<iframe[^>]*class="[^"]*ad[^"]*"[^>]*>[\\s\\S]*?<\\/iframe>/gi, // 广告iframe
    /<ins[^>]*class="[^"]*adsbygoogle[^"]*"[^>]*>[\\s\\S]*?<\\/ins>/gi, // Google广告
    /<script[^>]*src="[^"]*ads[^"]*"[^>]*>[\\s\\S]*?<\\/script>/gi      // 广告JS
];
// ==========================================

// 逐条移除广告节点
广告匹配规则.forEach(function(正则) {
    html = html.replace(正则, "<!-- 广告已移除 -->");
});

// 写回响应
$response.body = html;
$done($response);
""",
            用途说明: "从HTML响应中正则匹配并移除广告DOM节点（div/iframe/script等）",
            使用场景: "网页中包含广告位div、Google AdSense、广告iframe等需要剔除"
        ),
        圈X代码模板(
            标题: "去广告（关键词屏蔽返回空）",
            分类: .响应处理,
            代码: """
// ======================
// 功能：检测响应中是否包含广告关键词，包含则返回空响应
// 场景：无法精确匹配广告字段时，用关键词粗筛屏蔽
// ======================
const 响应文本 = $response.body;

// ====== 配置区：广告关键词列表 ======
const 广告关键词 = [
    "广告位",
    "ad_slot",
    "advertisement",
    "推广",
    "sponsored"
];
// ====================================

// 检测是否包含任一广告关键词
const 包含广告 = 广告关键词.some(function(关键词) {
    return 响应文本.indexOf(关键词) !== -1;
});

if (包含广告) {
    // 包含广告关键词，返回空响应阻断
    $response.body = "{}";
    $response.statusCode = 200;
    $notify("广告拦截", "", "已屏蔽含广告关键词的响应");
} else {
    // 不包含广告，原样返回
}

$done($response);
""",
            用途说明: "检测响应中是否包含广告关键词，包含则返回空响应阻断",
            使用场景: "无法精确匹配广告字段时，用关键词粗筛屏蔽疑似广告响应"
        ),

        // MARK: 网络请求类
        圈X代码模板(
            标题: "GET请求并处理响应",
            分类: .网络请求,
            代码: """
// ======================
// 功能：发起GET异步请求并处理结果
// 场景：脚本中调用第三方接口获取数据
// ======================
$httpClient.get("https://httpbin.org/get", {}, function(error, response) {
    if (error) {
        $notify("请求失败", "", error);
        $done();
        return;
    }
    // response.body 是响应体文本
    let data = JSON.parse(response.body);
    $notify("请求成功", "", "来源IP：" + data.origin);
    $done();
});
""",
            用途说明: "使用$httpClient发起GET请求并在回调中处理",
            使用场景: "脚本需要主动请求外部接口获取数据"
        ),
        圈X代码模板(
            标题: "POST请求提交数据",
            分类: .网络请求,
            代码: """
// ======================
// 功能：发起POST请求提交JSON数据
// 场景：主动调用接口提交信息
// ======================
const postData = JSON.stringify({key: "value"});
$httpClient.post("https://httpbin.org/post", {
    headers: {"Content-Type": "application/json"},
    body: postData
}, function(error, response) {
    if (error) {
        $notify("提交失败", "", error);
        $done();
        return;
    }
    $notify("提交成功", "", response.body);
    $done();
});
""",
            用途说明: "使用$httpClient发起POST请求，带请求头和请求体",
            使用场景: "需要主动提交数据到接口时使用"
        ),

        // MARK: 存储通知类
        圈X代码模板(
            标题: "持久化存储读写",
            分类: .存储通知,
            代码: """
// ======================
// 功能：使用$persistentStore持久化存储数据
// 场景：保存计数器、配置等需要跨脚本运行保留的数据
// ======================
// 读取已保存的计数（不存在则为0）
let count = parseInt($persistentStore.read("运行次数") || "0");
count = count + 1;
// 写入新的计数值
$persistentStore.write(String(count), "运行次数");
$notify("运行统计", "", "本脚本已运行" + count + "次");
$done();
""",
            用途说明: "使用$persistentStore读写持久化数据",
            使用场景: "保存运行次数、用户配置等跨运行保留的数据"
        ),
        圈X代码模板(
            标题: "条件通知弹窗",
            分类: .存储通知,
            代码: """
// ======================
// 功能：根据条件判断是否弹出通知
// 场景：监控特定字段变化时提醒
// ======================
let body = JSON.parse($response.body);
if (body.code === 0) {
    // 成功时不通知
    $done($response);
} else {
    // 失败时弹窗提醒
    $notify("接口返回错误", "错误码", body.code + " - " + (body.msg || ""));
    $done($response);
}
""",
            用途说明: "根据响应条件决定是否弹出通知",
            使用场景: "监控接口异常、特定状态变化时提醒用户"
        ),

        // MARK: 工具函数类
        圈X代码模板(
            标题: "URL参数解析工具",
            分类: .工具函数,
            代码: """
// ======================
// 功能：解析URL中的查询参数
// 场景：需要读取URL上的特定参数
// ======================
function getQueryParam(url, name) {
    const regex = new RegExp("[?&]" + name + "=([^&]*)");
    const match = url.match(regex);
    return match ? decodeURIComponent(match[1]) : null;
}
// 使用示例：获取URL中的token参数
const token = getQueryParam($request.url, "token");
$notify("URL参数", "token", token || "未找到");
$done();
""",
            用途说明: "提供从URL中解析查询参数的工具函数",
            使用场景: "需要读取请求URL上的token、id等参数时"
        ),
        圈X代码模板(
            标题: "时间戳格式化工具",
            分类: .工具函数,
            代码: """
// ======================
// 功能：将时间戳格式化为可读日期
// 场景：接口返回时间戳需要转换显示
// ======================
function formatTime(timestamp) {
    const date = new Date(timestamp);
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, "0");
    const d = String(date.getDate()).padStart(2, "0");
    const h = String(date.getHours()).padStart(2, "0");
    const min = String(date.getMinutes()).padStart(2, "0");
    return y + "-" + m + "-" + d + " " + h + ":" + min;
}
// 使用示例
const now = formatTime(Date.now());
$notify("当前时间", "", now);
$done();
""",
            用途说明: "提供时间戳转可读日期字符串的工具函数",
            使用场景: "接口返回的时间戳需要转为人类可读格式"
        )
    ]

    /// 按分类筛选模板
    /// - Parameter 分类: 模板分类，nil表示全部
    /// - Returns: 筛选后的模板列表
    static func 按分类筛选(分类: 模板分类?) -> [圈X代码模板] {
        guard let 分类 = 分类 else { return 全部模板 }
        return 全部模板.filter { $0.分类 == 分类 }
    }
}
