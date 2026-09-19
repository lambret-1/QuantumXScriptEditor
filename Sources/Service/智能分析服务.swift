import Foundation

/// 智能分析服务，解析用户粘贴的抓包数据，自动识别会员信息与广告信息，并生成对应脚本模板
/// 支持格式：JSON响应体、cURL命令、HAR格式、纯文本键值对
enum 智能分析服务 {

    // MARK: - 分析结果模型

    /// 单个识别到的字段信息
    struct 识别字段: Identifiable, Equatable {
        let id = UUID()
        /// 字段完整路径（如 data.user.isVip）
        let 字段路径: String
        /// 字段当前值
        let 当前值: String
        /// 字段类型
        let 类型: 字段类型

        /// 字段类型枚举
        enum 字段类型 {
            case 会员状态
            case 会员到期时间
            case 会员等级
            case 广告标记
            case 广告链接
            case 广告图片
            case 广告数组
        }
    }

    /// 完整分析结果
    struct 分析结果 {
        /// 识别到的会员相关字段
        var 会员字段: [识别字段] = []
        /// 识别到的广告相关字段
        var 广告字段: [识别字段] = []
        /// 原始数据格式
        var 数据格式: String = "未知"
        /// 是否识别到有效信息
        var 有结果: Bool {
            !会员字段.isEmpty || !广告字段.isEmpty
        }
    }

    /// 生成的可插入模板
    struct 生成模板: Identifiable, Equatable {
        let id = UUID()
        /// 模板名称
        let 名称: String
        /// 模板说明
        let 说明: String
        /// 生成的完整代码
        let 代码: String
        /// 模板分类标签
        let 分类: String
    }

    // MARK: - 关键词配置

    /// 会员状态字段关键词（布尔型，值为true/false）
    private static let 会员状态关键词 = [
        "isVip", "is_vip", "vip", "isMember", "is_member", "member",
        "isSvip", "is_svip", "svip", "isPremium", "is_premium", "premium",
        "isPro", "is_pro", "pro", "paid", "isPaid", "is_paid",
        "subscribed", "isSubscribed", "is_subscribed"
    ]

    /// 会员到期时间字段关键词
    private static let 会员到期关键词 = [
        "vipExpire", "vip_expire", "expire", "expireTime", "expire_time",
        "expiresAt", "expires_at", "vipExpireTime", "vip_expire_time",
        "memberExpire", "member_expire", "endTime", "end_time",
        "validUntil", "valid_until", "deadline"
    ]

    /// 会员等级字段关键词
    private static let 会员等级关键词 = [
        "level", "vipLevel", "vip_level", "memberLevel", "member_level",
        "userLevel", "user_level", "grade", "vipGrade", "vip_grade",
        "rank", "tier", "membershipLevel"
    ]

    /// 广告标记字段关键词（布尔型）
    private static let 广告标记关键词 = [
        "isAd", "is_ad", "hasAd", "has_ad", "isAdvert", "is_advert",
        "ad", "ads", "advert", "advertisement", "sponsored", "isSponsored",
        "is_sponsored", "promotion", "isPromotion", "is_promotion",
        "adFlag", "ad_flag", "adType", "ad_type"
    ]

    /// 广告链接/图片字段关键词
    private static let 广告资源关键词 = [
        "adUrl", "ad_url", "adLink", "ad_link", "adImage", "ad_image",
        "adImg", "ad_img", "adIcon", "ad_icon", "adTitle", "ad_title",
        "adContent", "ad_content", "adTrack", "ad_track", "adClick",
        "ad_click", "adId", "ad_id", "adSlot", "ad_slot", "adPosition",
        "ad_position", "bannerUrl", "banner_url", "bannerImage", "banner_image",
        "popupUrl", "popup_url", "popupImage", "popup_image"
    ]

    // MARK: - 主分析入口

    /// 分析用户粘贴的抓包数据
    /// - Parameter 原始文本: 用户粘贴的原始文本
    /// - Returns: 分析结果
    static func 分析(原始文本: String) -> 分析结果 {
        var 结果 = 分析结果()
        let 清洗文本 = 原始文本.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !清洗文本.isEmpty else { return 结果 }

        // 尝试解析为JSON
        if let json对象 = 解析JSON(清洗文本) {
            结果.数据格式 = "JSON"
            遍历JSON对象(对象: json对象, 路径前缀: "", 结果: &结果)
        }
        // 尝试从cURL命令中提取JSON
        else if let json子串 = 从文本提取JSON(清洗文本), let json对象 = 解析JSON(json子串) {
            结果.数据格式 = "cURL/文本（含JSON）"
            遍历JSON对象(对象: json对象, 路径前缀: "", 结果: &结果)
        }
        // 纯文本键值对
        else {
            结果.数据格式 = "纯文本"
            分析纯文本(文本: 清洗文本, 结果: &结果)
        }

        return 结果
    }

    // MARK: - 生成模板

    /// 根据分析结果生成可插入的脚本模板列表
    /// - Parameter 结果: 分析结果
    /// - Returns: 生成的模板列表
    static func 生成模板列表(结果: 分析结果) -> [生成模板] {
        var 模板列表: [生成模板] = []

        // 生成会员状态修改模板
        let 会员状态字段 = 结果.会员字段.filter { $0.类型 == .会员状态 }
        if !会员状态字段.isEmpty {
            let 第一个 = 会员状态字段[0]
            let 代码 = 生成会员状态模板(字段路径: 第一个.字段路径, 当前值: 第一个.当前值)
            模板列表.append(生成模板(
                名称: "解锁会员（\(第一个.字段路径)）",
                说明: "将会员状态字段设为true，模拟VIP用户",
                代码: 代码,
                分类: "会员解锁"
            ))
        }

        // 生成会员到期时间修改模板
        let 会员到期字段 = 结果.会员字段.filter { $0.类型 == .会员到期时间 }
        if !会员到期字段.isEmpty {
            let 第一个 = 会员到期字段[0]
            let 代码 = 生成会员到期模板(字段路径: 第一个.字段路径, 当前值: 第一个.当前值)
            模板列表.append(生成模板(
                名称: "会员永久有效（\(第一个.字段路径)）",
                说明: "将会员到期时间设为2099年，实现永久会员",
                代码: 代码,
                分类: "会员解锁"
            ))
        }

        // 生成会员等级修改模板
        let 会员等级字段 = 结果.会员字段.filter { $0.类型 == .会员等级 }
        if !会员等级字段.isEmpty {
            let 第一个 = 会员等级字段[0]
            let 代码 = 生成会员等级模板(字段路径: 第一个.字段路径, 当前值: 第一个.当前值)
            模板列表.append(生成模板(
                名称: "提升会员等级（\(第一个.字段路径)）",
                说明: "将会员等级设为最高级（如6/VIP6）",
                代码: 代码,
                分类: "会员解锁"
            ))
        }

        // 生成去广告（删除字段）模板
        let 广告标记字段 = 结果.广告字段.filter { $0.类型 == .广告标记 || $0.类型 == .广告链接 || $0.类型 == .广告图片 }
        if !广告标记字段.isEmpty {
            let 字段路径列表 = 广告标记字段.map { $0.字段路径 }
            let 代码 = 生成去广告字段模板(字段路径列表: 字段路径列表)
            模板列表.append(生成模板(
                名称: "去广告（删除\(广告标记字段.count)个字段）",
                说明: "从响应JSON中删除识别到的广告相关字段",
                代码: 代码,
                分类: "去广告"
            ))
        }

        // 生成去广告数组模板
        let 广告数组字段 = 结果.广告字段.filter { $0.类型 == .广告数组 }
        if !广告数组字段.isEmpty {
            let 第一个 = 广告数组字段[0]
            let 代码 = 生成去广告数组成员模板(数组路径: 第一个.字段路径)
            模板列表.append(生成模板(
                名称: "去广告数组（过滤\(第一个.字段路径)）",
                说明: "从数组列表中过滤掉广告项（按is_ad等字段判断）",
                代码: 代码,
                分类: "去广告"
            ))
        }

        // 如果没有识别到任何信息，给出通用模板
        if 模板列表.isEmpty {
            模板列表.append(生成模板(
                名称: "通用响应修改模板",
                说明: "未识别到特定字段，使用通用模板手动修改",
                代码: """
// ======================
// 通用响应修改模板
// 请根据实际接口结构修改下方代码
// ======================
let body = JSON.parse($response.body);
// TODO: 在这里修改响应字段
// 例如：body.data.isVip = true;
$response.body = JSON.stringify(body);
$done($response);
""",
                分类: "通用"
            ))
        }

        return 模板列表
    }

    // MARK: - 私有解析方法

    /// 尝试解析文本为JSON对象
    private static func 解析JSON(_ 文本: String) -> Any? {
        guard let 数据 = 文本.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: 数据, options: [.fragmentsAllowed])
    }

    /// 从任意文本中提取第一个完整的JSON对象/数组
    private static func 从文本提取JSON(_ 文本: String) -> String? {
        // 查找第一个 { 或 [
        let 花括号位置 = 文本.firstIndex(of: "{")
        let 方括号位置 = 文本.firstIndex(of: "[")
        var 起始位置: String.Index?
        var 结束字符: Character
        if let 花 = 花括号位置, let 方 = 方括号位置 {
            if 花 < 方 {
                起始位置 = 花
                结束字符 = "}"
            } else {
                起始位置 = 方
                结束字符 = "]"
            }
        } else if let 花 = 花括号位置 {
            起始位置 = 花
            结束字符 = "}"
        } else if let 方 = 方括号位置 {
            起始位置 = 方
            结束字符 = "]"
        }
        guard let 起始 = 起始位置 else { return nil }

        // 简单的括号匹配查找结束位置
        var 深度 = 0
        var 索引 = 起始
        while 索引 < 文本.endIndex {
            let 字符 = 文本[索引]
            if 字符 == "{" || 字符 == "[" {
                深度 += 1
            } else if 字符 == "}" || 字符 == "]" {
                深度 -= 1
                if 深度 == 0 {
                    return String(文本[起始...索引])
                }
            }
            索引 = 文本.index(after: 索引)
        }
        return nil
    }

    /// 递归遍历JSON对象，识别会员和广告字段
    private static func 遍历JSON对象(对象: Any, 路径前缀: String, 结果: inout 分析结果) {
        if let 字典 = 对象 as? [String: Any] {
            for (键, 值) in 字典 {
                let 当前路径 = 路径前缀.isEmpty ? 键 : "\(路径前缀).\(键)"
                let 小写键 = 键.lowercased()

                // 检查是否为数组（可能是广告列表）
                if let 数组 = 值 as? [Any], !数组.isEmpty {
                    // 检查数组名是否含广告关键词
                    if 广告标记关键词.contains(where: { 小写键.contains($0.lowercased()) }) ||
                       广告资源关键词.contains(where: { 小写键.contains($0.lowercased()) }) {
                        结果.广告字段.append(识别字段(
                            字段路径: 当前路径,
                            当前值: "[数组(\(数组.count)项)]",
                            类型: .广告数组
                        ))
                    }
                    // 检查数组第一项是否含广告/会员字段
                    else if let 第一项 = 数组.first as? [String: Any] {
                        let 含广告 = 第一项.keys.contains { 键名 in
                            let 小写 = 键名.lowercased()
                            return 广告标记关键词.contains(where: { 小写.contains($0.lowercased()) })
                        }
                        if 含广告 {
                            结果.广告字段.append(识别字段(
                                字段路径: 当前路径,
                                当前值: "[数组(\(数组.count)项，含广告标记)]",
                                类型: .广告数组
                            ))
                        }
                    }
                    // 继续递归遍历数组项
                    数组.forEach { 项 in
                        遍历JSON对象(对象: 项, 路径前缀: 当前路径 + "[*]", 结果: &结果)
                    }
                    continue
                }

                // 检查会员状态字段
                if 会员状态关键词.contains(where: { 小写键 == $0.lowercased() || 小写键.hasSuffix($0.lowercased()) }) {
                    结果.会员字段.append(识别字段(
                        字段路径: 当前路径,
                        当前值: String(describing: 值),
                        类型: .会员状态
                    ))
                }
                // 检查会员到期字段
                else if 会员到期关键词.contains(where: { 小写键 == $0.lowercased() || 小写键.hasSuffix($0.lowercased()) }) {
                    结果.会员字段.append(识别字段(
                        字段路径: 当前路径,
                        当前值: String(describing: 值),
                        类型: .会员到期时间
                    ))
                }
                // 检查会员等级字段
                else if 会员等级关键词.contains(where: { 小写键 == $0.lowercased() || 小写键.hasSuffix($0.lowercased()) }) {
                    结果.会员字段.append(识别字段(
                        字段路径: 当前路径,
                        当前值: String(describing: 值),
                        类型: .会员等级
                    ))
                }
                // 检查广告标记字段
                else if 广告标记关键词.contains(where: { 小写键 == $0.lowercased() || 小写键.hasSuffix($0.lowercased()) }) {
                    结果.广告字段.append(识别字段(
                        字段路径: 当前路径,
                        当前值: String(describing: 值),
                        类型: .广告标记
                    ))
                }
                // 检查广告资源字段
                else if 广告资源关键词.contains(where: { 小写键 == $0.lowercased() || 小写键.hasSuffix($0.lowercased()) }) {
                    let 类型: 识别字段.字段类型 = (小写键.contains("url") || 小写键.contains("link")) ? .广告链接 : .广告图片
                    结果.广告字段.append(识别字段(
                        字段路径: 当前路径,
                        当前值: String(describing: 值),
                        类型: 类型
                    ))
                }

                // 继续递归
                if let 子字典 = 值 as? [String: Any] {
                    遍历JSON对象(对象: 子字典, 路径前缀: 当前路径, 结果: &结果)
                }
            }
        }
    }

    /// 分析纯文本中的键值对
    private static func 分析纯文本(文本: String, 结果: inout 分析结果) {
        let 行数组 = 文本.components(separatedBy: .newlines)
        for 行 in 行数组 {
            let 部分 = 行.split(separator: ":", maxSplits: 1)
            guard 部分.count == 2 else { continue }
            let 键 = String(部分[0]).trimmingCharacters(in: .whitespaces).lowercased()
            let 值 = String(部分[1]).trimmingCharacters(in: .whitespaces)

            if 会员状态关键词.contains(where: { 键 == $0.lowercased() }) {
                结果.会员字段.append(识别字段(字段路径: 键, 当前值: 值, 类型: .会员状态))
            } else if 会员到期关键词.contains(where: { 键 == $0.lowercased() }) {
                结果.会员字段.append(识别字段(字段路径: 键, 当前值: 值, 类型: .会员到期时间))
            } else if 广告标记关键词.contains(where: { 键 == $0.lowercased() }) {
                结果.广告字段.append(识别字段(字段路径: 键, 当前值: 值, 类型: .广告标记))
            }
        }
    }

    // MARK: - 模板生成方法

    /// 生成会员状态修改模板
    private static func 生成会员状态模板(字段路径: String, 当前值: String) -> String {
        let 路径部分 = 字段路径.components(separatedBy: ".")
        var 导航代码 = ""
        var 父级路径 = "body"

        // 生成安全导航代码
        for i in 0..<(路径部分.count - 1) {
            let 字段名 = 路径部分[i]
            导航代码 += "if (\(父级路径).\(字段名) === undefined) { \(父级路径).\(字段名) = {}; }\n"
            父级路径 += ".\(字段名)"
        }

        let 最终字段 = 路径部分.last ?? 字段路径
        return """
// ======================
// 功能：解锁会员状态
// 识别字段：\(字段路径)（当前值：\(当前值)）
// ======================
let body = JSON.parse($response.body);
\(导航代码)// 将会员状态设为true
\(父级路径).\(最终字段) = true;
$response.body = JSON.stringify(body);
$done($response);
"""
    }

    /// 生成会员到期时间修改模板
    private static func 生成会员到期模板(字段路径: String, 当前值: String) -> String {
        let 路径部分 = 字段路径.components(separatedBy: ".")
        var 导航代码 = ""
        var 父级路径 = "body"
        for i in 0..<(路径部分.count - 1) {
            let 字段名 = 路径部分[i]
            导航代码 += "if (\(父级路径).\(字段名) === undefined) { \(父级路径).\(字段名) = {}; }\n"
            父级路径 += ".\(字段名)"
        }
        let 最终字段 = 路径部分.last ?? 字段路径

        // 判断当前值是时间戳还是日期字符串
        let 是否时间戳 = Double(当前值) != nil && (Double(当前值) ?? 0) > 1000000000
        let 永久值: String
        if 是否时间戳 {
            永久值 = "4070908800" // 2099-01-01 时间戳（秒）
        } else {
            永久值 = "\"2099-12-31 23:59:59\""
        }

        return """
// ======================
// 功能：会员永久有效
// 识别字段：\(字段路径)（当前值：\(当前值)）
// ======================
let body = JSON.parse($response.body);
\(导航代码)// 将会员到期时间设为2099年
\(父级路径).\(最终字段) = \(永久值);
$response.body = JSON.stringify(body);
$done($response);
"""
    }

    /// 生成会员等级修改模板
    private static func 生成会员等级模板(字段路径: String, 当前值: String) -> String {
        let 路径部分 = 字段路径.components(separatedBy: ".")
        var 导航代码 = ""
        var 父级路径 = "body"
        for i in 0..<(路径部分.count - 1) {
            let 字段名 = 路径部分[i]
            导航代码 += "if (\(父级路径).\(字段名) === undefined) { \(父级路径).\(字段名) = {}; }\n"
            父级路径 += ".\(字段名)"
        }
        let 最终字段 = 路径部分.last ?? 字段路径

        // 判断当前值是数字还是字符串
        let 是否数字 = Int(当前值) != nil
        let 最高值 = 是否数字 ? "6" : "\"VIP6\""

        return """
// ======================
// 功能：提升会员等级
// 识别字段：\(字段路径)（当前值：\(当前值)）
// ======================
let body = JSON.parse($response.body);
\(导航代码)// 将会员等级设为最高级
\(父级路径).\(最终字段) = \(最高值);
$response.body = JSON.stringify(body);
$done($response);
"""
    }

    /// 生成去广告字段模板
    private static func 生成去广告字段模板(字段路径列表: [String]) -> String {
        let 字段列表文本 = 字段路径列表.map { "\"\($0)\"" }.joined(separator: ",\n    ")
        return """
// ======================
// 功能：去广告（删除识别到的广告字段）
// 识别到\(字段路径列表.count)个广告字段
// ======================
let body = JSON.parse($response.body);

// 要删除的广告字段路径列表
const 要删除的字段 = [
    \(字段列表文本)
];

// 递归删除指定路径的字段
function 删除字段(obj, 路径) {
    const 部分 = 路径.split(".");
    let 当前 = obj;
    for (let i = 0; i < 部分.length - 1; i++) {
        if (当前[部分[i]] === undefined || 当前[部分[i]] === null) return;
        当前 = 当前[部分[i]];
    }
    delete 当前[部分[部分.length - 1]];
}

// 遍历删除所有广告字段
要删除的字段.forEach(function(路径) {
    删除字段(body, 路径);
});

$response.body = JSON.stringify(body);
$done($response);
"""
    }

    /// 生成去广告数组成员模板
    private static func 生成去广告数组成员模板(数组路径: String) -> String {
        let 路径部分 = 数组路径.components(separatedBy: ".")
        var 导航代码 = ""
        var 父级路径 = "body"
        for i in 0..<(路径部分.count - 1) {
            let 字段名 = 路径部分[i]
            导航代码 += "if (\(父级路径).\(字段名) === undefined) { $done($response); return; }\n"
            父级路径 += ".\(字段名)"
        }
        let 数组名 = 路径部分.last ?? 数组路径

        return """
// ======================
// 功能：去广告数组（从列表中过滤广告项）
// 识别数组：\(数组路径)
// ======================
let body = JSON.parse($response.body);
\(导航代码)const 列表 = \(父级路径).\(数组名);

// 判断一项是否为广告
function 是否为广告(项) {
    return 项.isAd === true
        || 项.is_ad === true
        || 项.hasAd === true
        || 项.ad !== undefined
        || 项.ad_id !== undefined
        || 项.type === "ad"
        || 项.type === "advert";
}

// 过滤掉广告项
if (Array.isArray(列表)) {
    \(父级路径).\(数组名) = 列表.filter(function(项) {
        return !是否为广告(项);
    });
}

$response.body = JSON.stringify(body);
$done($response);
"""
    }
}
