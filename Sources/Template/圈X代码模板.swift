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
// 【安全写法】创建新对象副本，避免直接修改$request.headers可能因不可变对象导致不生效
const headers = Object.assign({}, $request.headers);
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
// 【安全写法】创建新对象副本，避免直接修改$request.headers可能因不可变对象导致不生效
const headers = Object.assign({}, $request.headers);
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
// 容错等级：三级（空值保护/异常隔离/兜底放行）
// ======================
try {
    // 【高级容错】安全解析请求体JSON，解析失败则原样放行
    let body = {};
    try {
        body = JSON.parse($request.body);
    } catch (解析错误) {
        console.log("[容错] 请求体JSON解析失败: " + 解析错误.message);
        $done($request);
        return;
    }
    // 修改参数字段
    body.amount = 0.01;
    body.count = 1;
    // 序列化回字符串
    $request.body = JSON.stringify(body);
    $done($request);
} catch (错误) {
    // 【终极容错】任何异常都原样放行请求
    console.log("[兜底] 脚本执行异常: " + 错误.message);
    $done($request);
}
""",
            用途说明: "解析并修改POST请求的JSON参数（含容错）",
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
// 容错等级：四级（空值保护/数据校验/异常隔离/兜底返回）
// 参考真实圈X脚本风格，含详细分级日志
// ======================
console.log("🚀 [1] 脚本触发！");

// 【第一步】检查 $response 是否存在（挂在请求阶段会未定义）
if (typeof $response === "undefined" || $response === null) {
    console.log("❌ [错误] $response 未定义！请在圈X的 [rewrite_local] 中使用 script-response-body");
    $done({}); return;
}

// 【第二步】检查响应体是否为空
var bodyText = $response.body;
if (!bodyText) {
    console.log("❌ [错误] 响应体为空！可能接口返回了 204/304，或者需要开启 MitM");
    $done({}); return;
}

console.log("📦 [2] 成功获取响应体，长度: " + bodyText.length);
console.log("🔍 [调试] 响应体前100字符: " + bodyText.substring(0, 100));

// 保存原始响应体作为终极兜底
const 原始响应体 = bodyText;

try {
    // 【第三步】安全解析JSON
    var body = {};
    try {
        body = JSON.parse(bodyText);
        console.log("✅ [3] JSON 解析成功");
    } catch (解析错误) {
        console.log("❌ [异常] JSON解析失败: " + 解析错误.message);
        $done({ body: 原始响应体 });
        return;
    }

    // 【第四步】修改字段（空值保护：检查data字段存在且为对象）
    if (body.data && typeof body.data === "object") {
        // ====== 配置区：在这里修改需要的字段 ======
        body.data.isVip = true;                                    // 会员状态设为true
        body.data.vipExpire = String(body.data.vipExpire || "2099-12-31"); // 会员到期时间
        // ============================================
        console.log("👑 [4] 字段修改完毕");
    } else {
        console.log("⚠️ [降级] body.data不存在或非对象，跳过修改");
        console.log("💡 body 下目前的键有: " + Object.keys(body).join(", "));
    }

    console.log("🎉 [5] 脚本执行成功！");
    $done({ body: JSON.stringify(body) });
} catch (错误) {
    // 【终极容错】兜底返回：任何异常都返回原始响应
    console.log("❌ [异常] 脚本执行异常: " + (错误 && 错误.message ? 错误.message : String(错误)));
    $done({ body: 原始响应体 });
}
""",
            用途说明: "解析响应JSON并修改指定字段（含四级容错）",
            使用场景: "修改接口返回的会员状态、用户信息等"
        ),
        圈X代码模板(
            标题: "替换响应文本",
            分类: .响应处理,
            代码: """
// ======================
// 功能：全局替换响应体中的文本
// 场景：替换页面中的特定文字
// 容错等级：四级（空值保护/数据校验/异常隔离/兜底返回）
// ======================
const 原始响应体 = ($response && $response.body) || "";

try {
    // 【基础容错】类型转换：确保响应体为字符串
    let body = String($response.body || "");

    // 【进阶容错】数据校验：响应体非空才执行替换
    if (body.length > 0) {
        // 将所有"旧文本"替换为"新文本"
        body = body.replace(/旧文本/g, "新文本");
    } else {
        console.log("[降级] 响应体为空，跳过替换");
    }

    $done({ body: body });
} catch (错误) {
    // 【终极容错】兜底返回
    console.log("[兜底] 脚本执行异常: " + 错误.message);
    $done({ body: 原始响应体 });
}
""",
            用途说明: "对响应体做文本全局替换（含四级容错）",
            使用场景: "修改网页文案、替换广告内容等"
        ),
        圈X代码模板(
            标题: "阻断响应（返回空）",
            分类: .响应处理,
            代码: """
// ======================
// 功能：阻断请求，返回空响应
// 场景：屏蔽广告或无用接口
// 容错说明：直接返回固定空响应，天然不会崩溃
// ======================
$done({ body: "{}", statusCode: 200 });
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
// 容错等级：四级（空值保护/数据校验/异常隔离/兜底返回）
// ======================
const 原始响应体 = ($response && $response.body) || "";

try {
    // 【高级容错】安全解析JSON
    let body = {};
    try {
        body = JSON.parse($response.body);
    } catch (解析错误) {
        console.log("[容错] JSON解析失败: " + 解析错误.message);
        $done({ body: 原始响应体 });
        return;
    }

    // ====== 配置区：在这里填写要删除的广告字段路径 ======
    const 要删除的字段 = [
        "data.ad",           // 示例：删除 data 下的 ad 字段
        "data.banner",       // 示例：删除 data 下的 banner 字段
        "data.popup_ad"      // 示例：删除 data 下的 popup_ad 弹窗广告
    ];
    // ==================================================

    // 【基础容错】递归删除指定路径的字段（带空值保护）
    function 删除字段(obj, 路径) {
        if (!obj || typeof obj !== "object") return;
        const 部分 = String(路径).split(".");
        let 当前 = obj;
        for (let i = 0; i < 部分.length - 1; i++) {
            if (当前[部分[i]] === undefined || 当前[部分[i]] === null || typeof 当前[部分[i]] !== "object") return;
            当前 = 当前[部分[i]];
        }
        delete 当前[部分[部分.length - 1]];
    }

    // 【进阶容错】遍历删除所有配置的广告字段（单个失败不影响其他）
    要删除的字段.forEach(function(路径) {
        try {
            删除字段(body, 路径);
        } catch (字段错误) {
            console.log("[降级] 删除字段失败(" + 路径 + "): " + 字段错误.message);
        }
    });

    $done({ body: JSON.stringify(body) });
} catch (错误) {
    // 【终极容错】兜底返回
    console.log("[兜底] 脚本执行异常: " + 错误.message);
    $done({ body: 原始响应体 });
}
""",
            用途说明: "从JSON响应中删除指定路径的广告字段（含四级容错）",
            使用场景: "接口返回的JSON中包含ad、banner等广告字段，需要剔除后再展示"
        ),
        圈X代码模板(
            标题: "去广告数组（列表过滤广告项）",
            分类: .响应处理,
            代码: """
// ======================
// 功能：从响应JSON的数组中过滤掉广告项
// 场景：信息流、推荐列表中混入广告卡片，需要剔除
// 容错等级：四级（空值保护/数据校验/异常隔离/兜底返回）
// ======================
const 原始响应体 = ($response && $response.body) || "";

try {
    // 【高级容错】安全解析JSON
    let body = {};
    try {
        body = JSON.parse($response.body);
    } catch (解析错误) {
        console.log("[容错] JSON解析失败: " + 解析错误.message);
        $done({ body: 原始响应体 });
        return;
    }

    // ====== 配置区 ======
    const 数组路径 = "data.list";
    // ====================

    // 【基础容错】判断一项是否为广告（带类型保护）
    function 是否为广告(项) {
        if (!项 || typeof 项 !== "object") return false;
        return 项.type === "ad"
            || 项.type === "advert"
            || 项.has_ad === true
            || 项.is_ad === true
            || (项.ad_id !== undefined && 项.ad_id !== null);
    }

    // 【基础容错】安全导航到数组（空值保护）
    const 部分 = String(数组路径).split(".");
    let 父级 = body;
    let 路径有效 = true;
    for (let i = 0; i < 部分.length - 1; i++) {
        if (父级[部分[i]] === undefined || 父级[部分[i]] === null || typeof 父级[部分[i]] !== "object") {
            console.log("[降级] 数组路径不存在: " + 数组路径);
            路径有效 = false;
            break;
        }
        父级 = 父级[部分[i]];
    }

    // 【进阶容错】过滤掉广告项（数组类型校验）
    if (路径有效) {
        const 数组 = 父级[部分[部分.length - 1]];
        if (Array.isArray(数组)) {
            const 过滤后 = 数组.filter(function(项) {
                try {
                    return !是否为广告(项);
                } catch (项错误) {
                    return true; // 单项判断异常时保留该项
                }
            });
            父级[部分[部分.length - 1]] = 过滤后;
        } else {
            console.log("[降级] 目标字段不是数组，跳过过滤");
        }
    }

    $done({ body: JSON.stringify(body) });
} catch (错误) {
    // 【终极容错】兜底返回
    console.log("[兜底] 脚本执行异常: " + 错误.message);
    $done({ body: 原始响应体 });
}
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
// 容错等级：四级（空值保护/数据校验/异常隔离/兜底返回）
// ======================
const 原始响应体 = ($response && $response.body) || "";

try {
    // 【高级容错】安全解析JSON
    let body = {};
    try {
        body = JSON.parse($response.body);
    } catch (解析错误) {
        console.log("[容错] JSON解析失败: " + 解析错误.message);
        $done({ body: 原始响应体 });
        return;
    }

    // ====== 配置区 ======
    const 数组路径 = "data.list";
    const 要删除的字段名 = [
        "ad_url", "ad_image", "ad_title", "ad_track", "is_ad", "ad_id"
    ];
    // ====================

    // 【基础容错】安全导航到数组
    const 部分 = String(数组路径).split(".");
    let 父级 = body;
    let 路径有效 = true;
    for (let i = 0; i < 部分.length - 1; i++) {
        if (父级[部分[i]] === undefined || 父级[部分[i]] === null || typeof 父级[部分[i]] !== "object") {
            console.log("[降级] 数组路径不存在: " + 数组路径);
            路径有效 = false;
            break;
        }
        父级 = 父级[部分[i]];
    }

    // 【进阶容错】遍历数组批量删除字段（单项异常不影响其他）
    if (路径有效) {
        const 数组 = 父级[部分[部分.length - 1]];
        if (Array.isArray(数组)) {
            数组.forEach(function(项) {
                if (项 && typeof 项 === "object") {
                    要删除的字段名.forEach(function(字段名) {
                        try { delete 项[字段名]; } catch (e) {}
                    });
                }
            });
        } else {
            console.log("[降级] 目标字段不是数组，跳过批量删除");
        }
    }

    $done({ body: JSON.stringify(body) });
} catch (错误) {
    // 【终极容错】兜底返回
    console.log("[兜底] 脚本执行异常: " + 错误.message);
    $done({ body: 原始响应体 });
}
""",
            用途说明: "批量删除数组中每一项的多个广告相关字段（含四级容错）",
            使用场景: "列表接口中每一项都带有ad_url、ad_image等广告字段，需要统一清除"
        ),
        圈X代码模板(
            标题: "去广告（HTML页面移除广告节点）",
            分类: .响应处理,
            代码: """
// ======================
// 功能：从HTML响应中移除广告相关DOM节点
// 场景：网页中包含广告div/iframe，需要在加载前剔除
// 容错等级：四级（空值保护/数据校验/异常隔离/兜底返回）
// ======================
const 原始响应体 = ($response && $response.body) || "";

try {
    // 【基础容错】类型转换：确保响应体为字符串
    let html = String($response.body || "");

    // 【进阶容错】数据校验：空响应直接返回
    if (html.length === 0) {
        console.log("[降级] 响应体为空，跳过HTML处理");
        $done({ body: 原始响应体 });
        return;
    }

    // ====== 配置区：要移除的广告选择器 ======
    const 广告匹配规则 = [
        /<div[^>]*class="[^"]*ad[^"]*"[^>]*>[\\s\\S]*?<\\/div>/gi,
        /<div[^>]*id="[^"]*ad[^"]*"[^>]*>[\\s\\S]*?<\\/div>/gi,
        /<iframe[^>]*class="[^"]*ad[^"]*"[^>]*>[\\s\\S]*?<\\/iframe>/gi,
        /<ins[^>]*class="[^"]*adsbygoogle[^"]*"[^>]*>[\\s\\S]*?<\\/ins>/gi,
        /<script[^>]*src="[^"]*ads[^"]*"[^>]*>[\\s\\S]*?<\\/script>/gi
    ];
    // ==========================================

    // 【高级容错】逐条移除广告节点（单条正则异常不影响其他）
    广告匹配规则.forEach(function(正则) {
        try {
            html = html.replace(正则, "<!-- 广告已移除 -->");
        } catch (正则错误) {
            console.log("[降级] 正则替换异常: " + 正则错误.message);
        }
    });

    $done({ body: html });
} catch (错误) {
    // 【终极容错】兜底返回
    console.log("[兜底] 脚本执行异常: " + 错误.message);
    $done({ body: 原始响应体 });
}
""",
            用途说明: "从HTML响应中正则匹配并移除广告DOM节点（含四级容错）",
            使用场景: "网页中包含广告位div、Google AdSense、广告iframe等需要剔除"
        ),
        圈X代码模板(
            标题: "去广告（关键词屏蔽返回空）",
            分类: .响应处理,
            代码: """
// ======================
// 功能：检测响应中是否包含广告关键词，包含则返回空响应
// 场景：无法精确匹配广告字段时，用关键词粗筛屏蔽
// 容错等级：四级（空值保护/数据校验/异常隔离/兜底返回）
// ======================
const 原始响应体 = ($response && $response.body) || "";

try {
    // 【基础容错】类型转换：确保响应体为字符串
    const 响应文本 = String($response.body || "");

    // ====== 配置区：广告关键词列表 ======
    const 广告关键词 = ["广告位", "ad_slot", "advertisement", "推广", "sponsored"];
    // ====================================

    // 【进阶容错】检测是否包含任一广告关键词（单个关键词异常不影响其他）
    let 包含广告 = false;
    try {
        包含广告 = 广告关键词.some(function(关键词) {
            return 响应文本.indexOf(关键词) !== -1;
        });
    } catch (检测错误) {
        console.log("[降级] 关键词检测异常: " + 检测错误.message);
    }

    // 根据检测结果决定响应体
    let 最终响应体 = 响应文本;
    if (包含广告) {
        最终响应体 = "{}";
        try { $notify("广告拦截", "", "已屏蔽含广告关键词的响应"); } catch (e) {}
    }

    $done({ body: 最终响应体 });
} catch (错误) {
    // 【终极容错】兜底返回
    console.log("[兜底] 脚本执行异常: " + 错误.message);
    $done({ body: 原始响应体 });
}
""",
            用途说明: "检测响应中是否包含广告关键词，包含则返回空响应阻断（含四级容错）",
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
// 圈X原生API：$task.fetch（Promise风格）
// 注意：不是$httpClient（那是Surge的API）
// 容错等级：三级（空值保护/异常隔离/兜底返回）
// ======================
$task.fetch({
    url: "https://httpbin.org/get",
    method: "GET"
}).then(function(response) {
    // 【高级容错】安全解析响应JSON，解析失败则记录日志
    let data = {};
    try {
        data = JSON.parse(response.body);
    } catch (解析错误) {
        console.log("[容错] 响应JSON解析失败: " + 解析错误.message);
        $done();
        return;
    }
    try {
        $notify("请求成功", "", "来源IP：" + String(data.origin || "未知"));
    } catch (通知错误) {
        console.log("[降级] 通知发送失败: " + 通知错误.message);
    }
    $done();
}, function(reason) {
    // 请求失败回调
    try { $notify("请求失败", "", String(reason.error || reason)); } catch (e) {}
    $done();
});
""",
            用途说明: "使用圈X原生$task.fetch发起GET请求，Promise风格处理（含容错）",
            使用场景: "脚本需要主动请求外部接口获取数据"
        ),
        圈X代码模板(
            标题: "POST请求提交数据",
            分类: .网络请求,
            代码: """
// ======================
// 功能：发起POST请求提交JSON数据
// 场景：主动调用接口提交信息
// 圈X原生API：$task.fetch（Promise风格）
// 注意：不是$httpClient（那是Surge的API）
// 容错等级：三级（空值保护/异常隔离/兜底返回）
// ======================
const postData = JSON.stringify({key: "value"});
$task.fetch({
    url: "https://httpbin.org/post",
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: postData
}).then(function(response) {
    // 【高级容错】response.body可能很长，截断后通知
    let 响应摘要 = String(response.body || "");
    if (响应摘要.length > 200) {
        响应摘要 = 响应摘要.substring(0, 200) + "...";
    }
    try {
        $notify("提交成功", "", 响应摘要);
    } catch (通知错误) {
        console.log("[降级] 通知发送失败: " + 通知错误.message);
    }
    $done();
}, function(reason) {
    try { $notify("提交失败", "", String(reason.error || reason)); } catch (e) {}
    $done();
});
""",
            用途说明: "使用圈X原生$task.fetch发起POST请求，带请求头和请求体（含容错）",
            使用场景: "需要主动提交数据到接口时使用"
        ),

        // MARK: 存储通知类
        圈X代码模板(
            标题: "持久化存储读写",
            分类: .存储通知,
            代码: """
// ======================
// 功能：使用$prefs持久化存储数据
// 场景：保存计数器、配置等需要跨脚本运行保留的数据
// 圈X原生API：$prefs.setValueForKey(value, key) / $prefs.valueForKey(key)
// 注意：不是$persistentStore（那是Surge的API）
// 容错等级：三级（空值保护/类型校验/兜底默认值）
// ======================
// 【基础容错】读取已保存的计数，不存在或非数字则默认为0
let 存储值 = $prefs.valueForKey("运行次数");
let count = parseInt(存储值 || "0");
if (isNaN(count)) {
    count = 0; // 【降级】存储值不是有效数字时重置为0
}
count = count + 1;
// 写入新的计数值
$prefs.setValueForKey(String(count), "运行次数");
try {
    $notify("运行统计", "", "本脚本已运行" + count + "次");
} catch (通知错误) {
    console.log("[降级] 通知发送失败: " + 通知错误.message);
}
$done();
""",
            用途说明: "使用圈X原生$prefs读写持久化数据（含NaN容错）",
            使用场景: "保存运行次数、用户配置等跨运行保留的数据"
        ),
        圈X代码模板(
            标题: "条件通知弹窗",
            分类: .存储通知,
            代码: """
// ======================
// 功能：根据条件判断是否弹出通知
// 场景：监控特定字段变化时提醒
// 容错等级：四级（空值保护/数据校验/异常隔离/兜底返回）
// ======================
const 原始响应体 = ($response && $response.body) || "";

try {
    // 【高级容错】安全解析JSON
    let body = {};
    try {
        body = JSON.parse($response.body);
    } catch (解析错误) {
        console.log("[容错] JSON解析失败: " + 解析错误.message);
        $done({ body: 原始响应体 });
        return;
    }

    // 【基础容错】空值保护与类型转换
    const 错误码 = Number(body.code || 0);
    if (错误码 === 0) {
        // 成功时不通知，原样返回响应
        $done({ body: 原始响应体 });
    } else {
        // 失败时弹窗提醒
        const 错误信息 = String(body.msg || "未知错误");
        try {
            $notify("接口返回错误", "错误码", 错误码 + " - " + 错误信息);
        } catch (通知错误) {
            console.log("[降级] 通知发送失败: " + 通知错误.message);
        }
        $done({ body: 原始响应体 });
    }
} catch (错误) {
    // 【终极容错】兜底返回
    console.log("[兜底] 脚本执行异常: " + 错误.message);
    $done({ body: 原始响应体 });
}
""",
            用途说明: "根据响应条件决定是否弹出通知（含四级容错）",
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
// 容错等级：三级（空值保护/异常隔离/兜底返回null）
// ======================
function getQueryParam(url, name) {
    try {
        const regex = new RegExp("[?&]" + name + "=([^&]*)");
        const match = String(url || "").match(regex);
        if (!match) return null;
        // 【高级容错】decodeURIComponent可能因非法编码抛出异常
        try {
            return decodeURIComponent(match[1]);
        } catch (解码错误) {
            console.log("[降级] URL参数解码失败: " + 解码错误.message);
            return match[1]; // 降级返回原始未解码值
        }
    } catch (错误) {
        console.log("[兜底] URL参数解析异常: " + 错误.message);
        return null;
    }
}
// 使用示例：获取URL中的token参数
const token = getQueryParam($request.url, "token");
try {
    $notify("URL参数", "token", token || "未找到");
} catch (e) {}
$done();
""",
            用途说明: "提供从URL中解析查询参数的工具函数（含解码容错）",
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
        ),
        圈X代码模板(
            标题: "运行环境检测",
            分类: .工具函数,
            代码: """
// ======================
// 功能：检测当前脚本运行环境，编写跨平台兼容脚本
// 场景：脚本需要同时支持圈X、Surge等多个平台
// 圈X判断：typeof $task != "undefined"
// Surge判断：typeof $httpClient != "undefined"
// ======================
const isRequest = typeof $request != "undefined";      // 是否为重写类型脚本
const isQuanX = typeof $task != "undefined";            // 是否圈X环境
const isSurge = typeof $httpClient != "undefined";      // 是否Surge环境
const isJSBox = typeof $app != "undefined" && typeof $http != "undefined"; // 是否JSBox环境
const isNode = typeof require == "function" && !isJSBox; // 是否Node环境

console.log("[环境检测] 重写类型: " + isRequest);
console.log("[环境检测] 圈X: " + isQuanX);
console.log("[环境检测] Surge: " + isSurge);
console.log("[环境检测] Node: " + isNode);

// 跨平台通知封装
function 发送通知(标题, 副标题, 消息) {
    if (isQuanX) {
        $notify(标题, 副标题, 消息);
    } else if (isSurge) {
        $notification.post(标题, 副标题, 消息);
    } else {
        console.log(标题 + "\\n" + 副标题 + "\\n" + 消息);
    }
}

// 跨平台网络请求封装
function 发起请求(选项, 回调) {
    if (isQuanX) {
        // 圈X：$task.fetch Promise风格
        $task.fetch(选项).then(function(response) {
            回调(null, response, response.body);
        }, function(reason) {
            回调(reason, null, null);
        });
    } else if (isSurge) {
        // Surge：$httpClient回调风格
        if (选项.method === "POST") {
            $httpClient.post(选项, 回调);
        } else {
            $httpClient.get(选项, 回调);
        }
    }
}

发送通知("环境检测", "", "当前环境: " + (isQuanX ? "圈X" : isSurge ? "Surge" : "其他"));
$done();
""",
            用途说明: "检测运行环境并提供跨平台通知/请求封装，编写兼容圈X和Surge的脚本",
            使用场景: "脚本需要在多个代理工具中运行时使用"
        ),
        圈X代码模板(
            标题: "通知弹窗带链接",
            分类: .存储通知,
            代码: """
// ======================
// 功能：使用$notify弹出带跳转链接的通知
// 场景：通知用户点击后跳转到指定网页
// 圈X原生API：$notify(title, subtitle, message, {"open-url": "https://..."})
// ======================
// 第四个参数为选项对象，open-url指定点击通知后跳转的链接
$notify(
    "更新提醒",
    "发现新版本 v2.0.0",
    "点击查看更新详情",
    {"open-url": "https://github.com/lambret-1/QuantumXScriptEditor/releases"}
);

// 不带链接的普通通知
$notify("普通通知", "副标题", "消息内容");

console.log("[通知] 已发送通知弹窗");
$done();
""",
            用途说明: "使用圈X原生$notify弹出带open-url跳转链接的通知",
            使用场景: "需要用户点击通知后跳转到指定页面时使用"
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
