import Foundation

/// 智能分析服务，解析用户粘贴的抓包数据，自动识别会员信息与广告信息，并生成对应脚本模板
/// 支持格式：JSON响应体、cURL命令、HAR格式、纯文本键值对
/// 所有生成的模板统一遵循圈X标准四步流程：
/// 第一步：获取 $response.body，不是JSON就原样放行
/// 第二步：JSON.parse() 把文本"翻译"成脚本能修改的对象
/// 第三步：修改对象里的字段
/// 第四步：JSON.stringify() 把对象重新"压回"文本，调用 $done({ body: ... })
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
            // 用户核心信息
            case 用户ID
            case 用户名
            case 手机号
            case 邮箱
            case 头像
            case 积分余额
            case 登录Token
            case 性别
            case 生日
        }
    }

    /// 完整分析结果
    struct 分析结果 {
        /// 识别到的会员相关字段
        var 会员字段: [识别字段] = []
        /// 识别到的广告相关字段
        var 广告字段: [识别字段] = []
        /// 识别到的用户核心信息字段
        var 用户核心字段: [识别字段] = []
        /// 原始数据格式
        var 数据格式: String = "未知"
        /// 是否识别到有效信息
        var 有结果: Bool {
            !会员字段.isEmpty || !广告字段.isEmpty || !用户核心字段.isEmpty
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

    /// 会员状态字段关键词（数字型，值为1/0，圈X脚本中VIP状态通常用1表示）
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
        "adFlag", "ad_flag", "adType", "ad_type",
        "globalData", "appver"  // 全局广告配置/应用版本配置，识别后模板中设为{}空对象
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

    // MARK: - 用户核心信息关键词配置

    /// 用户ID字段关键词
    private static let 用户ID关键词 = [
        "userId", "user_id", "uid", "id", "memberId", "member_id",
        "accountId", "account_id", "customerId", "customer_id",
        "profileId", "profile_id", "userid", "uuid"
    ]

    /// 用户名/昵称字段关键词
    private static let 用户名关键词 = [
        "userName", "user_name", "username", "nickname", "nickName",
        "nick_name", "name", "screenName", "screen_name", "displayName",
        "display_name", "account", "accountName", "account_name",
        "loginName", "login_name", "realName", "real_name"
    ]

    /// 手机号字段关键词
    private static let 手机号关键词 = [
        "phone", "mobile", "tel", "telephone", "cellphone", "cellPhone",
        "phoneNumber", "phone_number", "mobileNumber", "mobile_number",
        "telNumber", "tel_number", "contactPhone", "contact_phone"
    ]

    /// 邮箱字段关键词
    private static let 邮箱关键词 = [
        "email", "eMail", "e_mail", "mail", "mailAddress", "mail_address",
        "emailAddress", "email_address", "userEmail", "user_email",
        "accountEmail", "account_email"
    ]

    /// 头像字段关键词
    private static let 头像关键词 = [
        "avatar", "avatarUrl", "avatar_url", "headImg", "head_img",
        "headImage", "head_image", "headIcon", "head_icon", "headUrl",
        "head_url", "photo", "photoUrl", "photo_url", "portrait",
        "portraitUrl", "portrait_url", "profileImage", "profile_image",
        "profileImg", "profile_img", "userAvatar", "user_avatar"
    ]

    /// 积分/余额字段关键词
    private static let 积分余额关键词 = [
        "points", "point", "score", "credit", "credits", "balance",
        "coin", "coins", "gold", "goldCoin", "gold_coin", "money",
        "amount", "wallet", "walletBalance", "wallet_balance",
        "integral", "bonus", "reward", "vipPoints", "vip_points",
        "growthValue", "growth_value", "exp", "experience"
    ]

    /// 登录Token字段关键词
    private static let 登录Token关键词 = [
        "token", "accessToken", "access_token", "refreshToken", "refresh_token",
        "authToken", "auth_token", "sessionId", "session_id", "session",
        "sessionToken", "session_token", "loginToken", "login_token",
        "jwt", "authorization", "auth", "apiKey", "api_key", "secret",
        "appToken", "app_token", "userToken", "user_token"
    ]

    /// 性别字段关键词
    private static let 性别关键词 = [
        "gender", "sex", "userGender", "user_gender", "memberGender",
        "member_gender", "profileGender", "profile_gender"
    ]

    /// 生日字段关键词
    private static let 生日关键词 = [
        "birthday", "birthDay", "birth_day", "birthDate", "birth_date",
        "dob", "dateOfBirth", "date_of_birth", "userBirthday",
        "user_birthday", "memberBirthday", "member_birthday", "age"
    ]

    // MARK: - 用户核心字段匹配辅助

    /// 短关键词列表（仅精确匹配，避免误判如id匹配到valid等）
    private static let 短关键词: Set<String> = ["id", "uid", "sex", "age", "exp", "dob", "mail", "name", "phone", "token", "auth", "jwt"]

    /// 判断键名是否匹配用户核心字段
    private static func 匹配用户核心字段(小写键: String) -> Bool {
        let 所有关键词 = 用户ID关键词 + 用户名关键词 + 手机号关键词 + 邮箱关键词 +
                        头像关键词 + 积分余额关键词 + 登录Token关键词 + 性别关键词 + 生日关键词
        return 所有关键词.contains { 关键词 in
            let 小写关键词 = 关键词.lowercased()
            if 短关键词.contains(小写关键词) {
                // 短关键词仅精确匹配
                return 小写键 == 小写关键词
            } else {
                // 长关键词精确或后缀匹配
                return 小写键 == 小写关键词 || 小写键.hasSuffix(小写关键词)
            }
        }
    }

    /// 判断用户字段的具体类型
    private static func 判断用户字段类型(小写键: String) -> 识别字段.字段类型 {
        if 匹配关键词列表(小写键: 小写键, 列表: 用户ID关键词) { return .用户ID }
        if 匹配关键词列表(小写键: 小写键, 列表: 用户名关键词) { return .用户名 }
        if 匹配关键词列表(小写键: 小写键, 列表: 手机号关键词) { return .手机号 }
        if 匹配关键词列表(小写键: 小写键, 列表: 邮箱关键词) { return .邮箱 }
        if 匹配关键词列表(小写键: 小写键, 列表: 头像关键词) { return .头像 }
        if 匹配关键词列表(小写键: 小写键, 列表: 积分余额关键词) { return .积分余额 }
        if 匹配关键词列表(小写键: 小写键, 列表: 登录Token关键词) { return .登录Token }
        if 匹配关键词列表(小写键: 小写键, 列表: 性别关键词) { return .性别 }
        if 匹配关键词列表(小写键: 小写键, 列表: 生日关键词) { return .生日 }
        return .用户名
    }

    /// 匹配关键词列表（短关键词精确匹配，长关键词精确或后缀匹配）
    private static func 匹配关键词列表(小写键: String, 列表: [String]) -> Bool {
        列表.contains { 关键词 in
            let 小写关键词 = 关键词.lowercased()
            if 短关键词.contains(小写关键词) {
                return 小写键 == 小写关键词
            } else {
                return 小写键 == 小写关键词 || 小写键.hasSuffix(小写关键词)
            }
        }
    }

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

    /// 根据分析结果生成可插入的脚本模板列表（综合模板置顶）
    /// - Parameter 结果: 分析结果
    /// - Returns: 生成的模板列表
    static func 生成模板列表(结果: 分析结果) -> [生成模板] {
        var 模板列表: [生成模板] = []

        // ====== 置顶：全部分析结果综合模板 ======
        if 结果.有结果 {
            let 综合代码 = 生成综合模板(结果: 结果)
            let 总字段数 = 结果.会员字段.count + 结果.广告字段.count + 结果.用户核心字段.count
            模板列表.append(生成模板(
                名称: "⭐ 全部导入（\(总字段数)个字段一键生成）",
                说明: "将所有识别到的会员、广告、用户字段合并到一个完整脚本中，一键插入",
                代码: 综合代码,
                分类: "综合模板"
            ))
        }

        // 生成会员状态修改模板
        let 会员状态字段 = 结果.会员字段.filter { $0.类型 == .会员状态 }
        if !会员状态字段.isEmpty {
            let 第一个 = 会员状态字段[0]
            let 代码 = 生成会员状态模板(字段路径: 第一个.字段路径, 当前值: 第一个.当前值)
            模板列表.append(生成模板(
                名称: "解锁会员（\(第一个.字段路径)）",
                说明: "将会员状态字段设为1，模拟VIP用户",
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

        // 生成用户核心信息相关模板
        if !结果.用户核心字段.isEmpty {
            // 1. 导出用户核心信息模板
            let 导出代码 = 生成导出用户信息模板(用户字段: 结果.用户核心字段)
            模板列表.append(生成模板(
                名称: "导出用户核心信息（\(结果.用户核心字段.count)项）",
                说明: "通过通知弹窗展示识别到的用户ID、昵称、手机等核心信息",
                代码: 导出代码,
                分类: "用户信息"
            ))

            // 2. 隐藏手机号和邮箱（隐私保护）
            let 隐私字段 = 结果.用户核心字段.filter { $0.类型 == .手机号 || $0.类型 == .邮箱 }
            if !隐私字段.isEmpty {
                let 隐私代码 = 生成隐私保护模板(隐私字段: 隐私字段)
                模板列表.append(生成模板(
                    名称: "隐私保护（隐藏手机/邮箱）",
                    说明: "将手机号和邮箱替换为星号掩码，保护用户隐私",
                    代码: 隐私代码,
                    分类: "用户信息"
                ))
            }

            // 3. 修改用户昵称
            let 用户名字段 = 结果.用户核心字段.filter { $0.类型 == .用户名 }
            if !用户名字段.isEmpty {
                let 第一个 = 用户名字段[0]
                let 昵称代码 = 生成修改昵称模板(字段路径: 第一个.字段路径, 当前值: 第一个.当前值)
                模板列表.append(生成模板(
                    名称: "修改用户昵称（\(第一个.字段路径)）",
                    说明: "将用户昵称修改为自定义名称",
                    代码: 昵称代码,
                    分类: "用户信息"
                ))
            }

            // 4. 修改积分余额
            let 积分字段 = 结果.用户核心字段.filter { $0.类型 == .积分余额 }
            if !积分字段.isEmpty {
                let 第一个 = 积分字段[0]
                let 积分代码 = 生成修改积分模板(字段路径: 第一个.字段路径, 当前值: 第一个.当前值)
                模板列表.append(生成模板(
                    名称: "修改积分余额（\(第一个.字段路径)）",
                    说明: "将积分/余额字段修改为指定数值",
                    代码: 积分代码,
                    分类: "用户信息"
                ))
            }
        }

        // 如果没有识别到任何信息，给出通用模板
        if 模板列表.isEmpty {
            模板列表.append(生成模板(
                名称: "通用响应修改模板",
                说明: "未识别到特定字段，使用通用模板手动修改",
                代码: """
// ======================
// 通用响应修改模板（圈X实战标准流程）
// 请根据实际接口结构修改下方代码
// ======================
(function() {
    // 定义一个匿名函数，并立即执行（IIFE），作用是隔离变量，避免污染全局环境
    console.log("🚀 [1] 通用响应修改模板触发！");

    // 1. 检查响应对象是否存在
    if (typeof $response === 'undefined' || $response === null) {
        console.log("❌ [错误] $response 未定义！请在圈X的 [rewrite_local] 里使用 script-response-body");
        $done({}); return;
    }
    console.log("✅ [1.1] $response 对象存在");

    var 原始响应体 = $response.body;
    if (!原始响应体) {
        console.log("⚠️ [错误] 响应体为空！可能接口返回了 204/304，或者需要开启 MitM");
        $done({}); return;
    }
    console.log("📦 [2] 成功获取 Body，长度: " + 原始响应体.length);
    console.log("🔍 [2.1] Body 前 100 字符: " + 原始响应体.substring(0, 100));

    // 2. 判断是不是JSON（非JSON直接放行，不破坏页面）
    var contentType = $response.headers["Content-Type"] || "";
    var isJson = contentType.indexOf("json") !== -1 ||
                 (原始响应体.charAt(0) === "{" || 原始响应体.charAt(0) === "[");
    if (!isJson) {
        console.log("⚠️ 非 JSON 响应（网页/图片等），直接放行");
        $done({}); return;
    }
    console.log("✅ [2.2] 确认是 JSON 响应");

    // ================= 核心修改函数 =================
    function 修改响应数据(body) {
        console.log("👑 [3] 开始执行修改响应数据函数");
        // ====== 配置区：在这里修改需要的字段 ======
        // 例如：if (!body.data || typeof body.data !== "object") body.data = {};
        // body.data.isvip = 1;  // 会员状态设为1（小写字段名）
        // ============================================
        console.log("👑 [4] 修改响应数据函数执行完毕");
        return body;
    }

    try {
        var body = JSON.parse(原始响应体);
        console.log("✅ [5] JSON 解析成功，顶层字段: " + Object.keys(body).join(", "));

        // 调用核心修改函数
        body = 修改响应数据(body);

        console.log("🎉 [6] 脚本执行成功！准备返回修改后的响应");
        $done({ body: JSON.stringify(body) });
    } catch (e) {
        console.log("❌ [异常] 解析失败：" + e + "，原样放行");
        $done({ body: 原始响应体 });
    }
})();
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
                // 检查用户核心信息字段（短关键词仅精确匹配，避免误判）
                else if 匹配用户核心字段(小写键: 小写键) {
                    let 用户类型 = 判断用户字段类型(小写键: 小写键)
                    结果.用户核心字段.append(识别字段(
                        字段路径: 当前路径,
                        当前值: String(describing: 值),
                        类型: 用户类型
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

    // MARK: - 智能路径导航工具

    /// 解析字段路径，生成安全导航代码（自动处理任意嵌套层级，如 data.user.isVip / data.info.VIP / root.isVip）
    /// - Parameter 字段路径: 点号分隔的完整路径，如 "data.user.isVip"
    /// - Returns: 导航代码、父级路径表达式、最终字段名
    private static func 生成安全导航(字段路径: String) -> (导航代码: String, 父级路径: String, 最终字段: String) {
        let 路径部分 = 字段路径.components(separatedBy: ".")
        guard 路径部分.count > 1 else {
            // 根级字段（如 body.isVip），无需导航
            return ("", "body", 路径部分.first ?? 字段路径)
        }
        var 导航代码 = ""
        var 父级路径 = "body"
        // 逐级导航：检查undefined/null/非对象/数组，确保父级一定是普通对象
        for i in 0..<(路径部分.count - 1) {
            let 字段名 = 路径部分[i]
            导航代码 += "if (\(父级路径).\(字段名) === undefined || \(父级路径).\(字段名) === null || typeof \(父级路径).\(字段名) !== \"object\" || Array.isArray(\(父级路径).\(字段名))) { \(父级路径).\(字段名) = {}; }\n"
            父级路径 += ".\(字段名)"
        }
        let 最终字段 = 路径部分.last ?? 字段路径
        return (导航代码, 父级路径, 最终字段)
    }

    /// 将点号路径转换为可读的层级展示（data.user.isVip → data › user › isVip）
    static func 路径展示文本(_ 路径: String) -> String {
        路径.components(separatedBy: ".").joined(separator: " › ")
    }

    // MARK: - 综合模板生成（全部字段一键导入）

    /// 从字段路径列表中收集所有需要初始化的父级路径（去重，按层级排序）
    /// 例如 ["data.user.isVip", "data.info.VIP"] → ["body.data", "body.data.user", "body.data.info"]
    private static func 收集所有父级路径(字段路径列表: [String]) -> [String] {
        var 路径集合 = Set<String>()
        for 字段路径 in 字段路径列表 {
            let 路径部分 = 字段路径.components(separatedBy: ".")
            guard 路径部分.count > 1 else { continue } // 根级字段无需父级初始化
            var 当前路径 = "body"
            for i in 0..<(路径部分.count - 1) {
                当前路径 += ".\(路径部分[i])"
                路径集合.insert(当前路径)
            }
        }
        // 按路径深度排序（浅层级先初始化，深层级后初始化）
        return 路径集合.sorted { $0.components(separatedBy: ".").count < $1.components(separatedBy: ".").count }
    }

    /// 生成统一初始化代码块（所有父级路径只检查一次，确保一定是普通对象）
    private static func 生成统一初始化代码(父级路径列表: [String]) -> String {
        guard !父级路径列表.isEmpty else { return "" }
        var 代码 = "    // ====== 统一初始化：所有父级路径只检查一次，确保一定是普通对象 ======\n"
        for 路径 in 父级路径列表 {
            代码 += "    if (!\(路径) || typeof \(路径) !== \"object\" || Array.isArray(\(路径))) \(路径) = {};\n"
        }
        代码 += "    // ====================================================================\n"
        return 代码
    }

    /// 生成综合模板：将所有识别到的会员、广告、用户字段合并到一个完整脚本中
    /// 【优化版】统一初始化父级路径（只检查一次）→ 直接修改字段（不再重复判断），代码更简洁高效
    private static func 生成综合模板(结果: 分析结果) -> String {
        // 收集所有需要修改的字段（用于统一初始化父级路径）
        var 所有字段路径: [String] = []
        所有字段路径.append(contentsOf: 结果.会员字段.map { $0.字段路径 })
        所有字段路径.append(contentsOf: 结果.用户核心字段.map { $0.字段路径 })
        // 广告字段用函数式删除，不需要初始化父级路径

        // 统一初始化所有父级路径（去重，只检查一次）
        let 所有父级路径 = 收集所有父级路径(字段路径列表: 所有字段路径)
        let 初始化代码 = 生成统一初始化代码(父级路径列表: 所有父级路径)

        // 直接修改字段代码块（初始化完成后直接赋值，不再每个字段包if判断）
        var 修改代码块 = ""

        // --- 会员状态修改（直接赋值，VIP状态用数字1表示）---
        let 会员状态字段 = 结果.会员字段.filter { $0.类型 == .会员状态 }
        if !会员状态字段.isEmpty {
            修改代码块 += "    // ====== 会员状态解锁 ======\n"
            for 字段 in 会员状态字段 {
                修改代码块 += "    body.\(字段.字段路径) = 1;  // 会员状态设为1\n"
            }
        }

        // --- 会员到期时间修改 ---
        let 会员到期字段 = 结果.会员字段.filter { $0.类型 == .会员到期时间 }
        if !会员到期字段.isEmpty {
            修改代码块 += "    // ====== 会员到期时间（永久有效）======\n"
            for 字段 in 会员到期字段 {
                let 是否时间戳 = Double(字段.当前值) != nil && (Double(字段.当前值) ?? 0) > 1000000000
                let 永久值 = 是否时间戳 ? "4070908800" : "\"2099-12-31 23:59:59\""
                修改代码块 += "    body.\(字段.字段路径) = \(永久值);  // 会员永久有效\n"
            }
        }

        // --- 会员等级修改 ---
        let 会员等级字段 = 结果.会员字段.filter { $0.类型 == .会员等级 }
        if !会员等级字段.isEmpty {
            修改代码块 += "    // ====== 会员等级（最高级）======\n"
            for 字段 in 会员等级字段 {
                let 是否数字 = Int(字段.当前值) != nil
                let 最高值 = 是否数字 ? "6" : "\"VIP6\""
                修改代码块 += "    body.\(字段.字段路径) = \(最高值);  // 会员等级最高\n"
            }
        }

        // --- 广告字段处理：globalData/appver设为{}空对象，其他广告字段删除 ---
        let 广告标记字段 = 结果.广告字段.filter { $0.类型 == .广告标记 || $0.类型 == .广告链接 || $0.类型 == .广告图片 }
        // 分离特殊字段（globalData/appver设为{}）和普通广告字段（删除）
        let 特殊置空字段 = 广告标记字段.filter { 字段 in
            let 小写路径 = 字段.字段路径.lowercased()
            return 小写路径.hasSuffix("globaldata") || 小写路径.hasSuffix("appver")
        }
        let 普通删除字段 = 广告标记字段.filter { 字段 in
            let 小写路径 = 字段.字段路径.lowercased()
            return !小写路径.hasSuffix("globaldata") && !小写路径.hasSuffix("appver")
        }
        // 特殊字段设为{}空对象
        if !特殊置空字段.isEmpty {
            修改代码块 += "    // ====== 去广告：清空全局广告配置/应用版本配置 ======\n"
            for 字段 in 特殊置空字段 {
                修改代码块 += "    body.\(字段.字段路径) = {};  // 清空\(字段.字段路径)广告配置\n"
            }
        }
        // 普通广告字段递归删除
        if !普通删除字段.isEmpty {
            let 字段列表文本 = 普通删除字段.map { "\"\($0.字段路径)\"" }.joined(separator: ", ")
            修改代码块 += "    // ====== 去广告：删除识别到的广告字段 ======\n"
            修改代码块 += "    const 要删除的广告字段 = [\(字段列表文本)];\n"
            修改代码块 += "    function 删除广告字段(obj, 路径) {\n"
            修改代码块 += "        if (!obj || typeof obj !== \"object\") return;\n"
            修改代码块 += "        const 部分 = String(路径).split(\".\");\n"
            修改代码块 += "        let 当前 = obj;\n"
            修改代码块 += "        for (let i = 0; i < 部分.length - 1; i++) {\n"
            修改代码块 += "            if (当前[部分[i]] === undefined || 当前[部分[i]] === null || typeof 当前[部分[i]] !== \"object\") return;\n"
            修改代码块 += "            当前 = 当前[部分[i]];\n"
            修改代码块 += "        }\n"
            修改代码块 += "        delete 当前[部分[部分.length - 1]];\n"
            修改代码块 += "    }\n"
            修改代码块 += "    要删除的广告字段.forEach(function(路径) { try { 删除广告字段(body, 路径); } catch (e) {} });\n"
        }

        // --- 用户昵称修改 ---
        let 用户名字段 = 结果.用户核心字段.filter { $0.类型 == .用户名 }
        if !用户名字段.isEmpty {
            修改代码块 += "    // ====== 用户昵称修改 ======\n"
            for 字段 in 用户名字段 {
                修改代码块 += "    body.\(字段.字段路径) = \"新昵称\";  // 修改用户昵称\n"
            }
        }

        // --- 积分余额修改 ---
        let 积分字段 = 结果.用户核心字段.filter { $0.类型 == .积分余额 }
        if !积分字段.isEmpty {
            修改代码块 += "    // ====== 积分余额拉满 ======\n"
            for 字段 in 积分字段 {
                let 是否数字 = Double(字段.当前值) != nil
                let 新值 = 是否数字 ? "999999" : "\"999999\""
                修改代码块 += "    body.\(字段.字段路径) = \(新值);  // 积分余额拉满\n"
            }
        }

        // --- 隐私保护（手机号/邮箱掩码，直接修改风格）---
        let 手机号字段 = 结果.用户核心字段.filter { $0.类型 == .手机号 }
        if !手机号字段.isEmpty {
            修改代码块 += "    // ====== 手机号掩码保护 ======\n"
            for 字段 in 手机号字段 {
                修改代码块 += "    body.\(字段.字段路径) = String(body.\(字段.字段路径) || \"\").replace(/(\\d{3})\\d{4}(\\d{4})/, \"$1****$2\");  // 手机号掩码\n"
            }
        }
        let 邮箱字段 = 结果.用户核心字段.filter { $0.类型 == .邮箱 }
        if !邮箱字段.isEmpty {
            修改代码块 += "    // ====== 邮箱掩码保护 ======\n"
            for 字段 in 邮箱字段 {
                修改代码块 += "    { let _e = String(body.\(字段.字段路径) || \"\"); let _at = _e.indexOf(\"@\"); if (_at > 2) { body.\(字段.字段路径) = _e.substring(0, 2) + \"****\" + _e.substring(_at); } }  // 邮箱掩码\n"
            }
        }

        let 总字段数 = 结果.会员字段.count + 结果.广告字段.count + 结果.用户核心字段.count

        return """
// ======================
// 功能：智能分析综合模板（全部识别字段一键导入）
// 共识别到\(总字段数)个字段，包含会员解锁/去广告/用户信息修改
// 遵循圈X实战标准流程：IIFE包裹→响应检查→非JSON放行→try-catch→function封装修改→$done返回
// ======================
(function() {
    // 定义一个匿名函数，并立即执行（IIFE），作用是隔离变量，避免污染全局环境
    console.log("🚀 [1] 智能分析综合模板触发！");

    // 1. 检查响应对象是否存在
    if (typeof $response === 'undefined' || $response === null) {
        console.log("❌ [错误] $response 未定义！请在圈X的 [rewrite_local] 里使用 script-response-body");
        $done({}); return;
    }
    console.log("✅ [1.1] $response 对象存在");

    var 原始响应体 = $response.body;
    if (!原始响应体) {
        console.log("⚠️ [错误] 响应体为空！可能接口返回了 204/304，或者需要开启 MitM");
        $done({}); return;
    }
    console.log("📦 [2] 成功获取 Body，长度: " + 原始响应体.length);
    console.log("🔍 [2.1] Body 前 100 字符: " + 原始响应体.substring(0, 100));

    // 2. 判断是不是JSON（非JSON直接放行，不破坏页面）
    var contentType = $response.headers["Content-Type"] || "";
    var isJson = contentType.indexOf("json") !== -1 ||
                 (原始响应体.charAt(0) === "{" || 原始响应体.charAt(0) === "[");
    if (!isJson) {
        console.log("⚠️ 非 JSON 响应（网页/图片等），直接放行");
        $done({}); return;
    }
    console.log("✅ [2.2] 确认是 JSON 响应");

    // ================= 核心修改函数 =================
    function 执行全部修改(body) {
        console.log("👑 [3] 开始执行智能分析综合修改函数，共修改\(总字段数)个字段");
\(初始化代码)\(修改代码块)
        console.log("👑 [4] 综合修改函数执行完毕");
        return body;
    }

    try {
        var body = JSON.parse(原始响应体);
        console.log("✅ [5] JSON 解析成功，顶层字段: " + Object.keys(body).join(", "));

        // 调用核心修改函数
        body = 执行全部修改(body);

        console.log("🎉 [6] 脚本执行成功！准备返回修改后的响应");
        // 把改好的对象重新"压回"文本字符串，调用$done返回
        $done({ body: JSON.stringify(body) });
    } catch (e) {
        console.log("❌ [异常] 解析失败：" + e + "，原样放行");
        // 解析失败返回原始响应体
        $done({ body: 原始响应体 });
    }
})();
"""
    }

    // MARK: - 单字段模板生成方法（四步标准流程）

    /// 生成会员状态修改模板（统一初始化+直接修改风格）
    private static func 生成会员状态模板(字段路径: String, 当前值: String) -> String {
        let 父级路径列表 = 收集所有父级路径(字段路径列表: [字段路径])
        let 初始化代码 = 生成统一初始化代码(父级路径列表: 父级路径列表)
        return """
// ======================
// 功能：解锁会员状态
// 识别字段：\(字段路径)（当前值：\(当前值)）
// ======================
// 【第一步】获取响应体，保存原始内容作为兜底
const 原始响应体 = ($response && $response.body) || "";

// 【第二步】把响应体文本"翻译"成脚本能修改的对象
let body = {};
try {
    body = JSON.parse(原始响应体);
} catch (解析错误) {
    console.log("[放行] 响应不是JSON格式，原样返回");
    $done({ body: 原始响应体 });
    return;
}

try {
    // 【第三步】修改对象里的字段（统一初始化父级路径，直接赋值）
\(初始化代码)    body.\(字段路径) = 1;  // 会员状态设为1（圈X脚本中VIP状态用数字1表示）
    console.log("✔️会员状态解锁完成");

    // 【第四步】把改好的对象重新"压回"文本字符串，交给圈X
    $done({ body: JSON.stringify(body) });
} catch (错误) {
    console.log("[兜底] 脚本异常: " + (错误 && 错误.message ? 错误.message : String(错误)));
    $done({ body: 原始响应体 });
}
"""
    }

    /// 生成会员到期时间修改模板（统一初始化+直接修改风格）
    private static func 生成会员到期模板(字段路径: String, 当前值: String) -> String {
        let 父级路径列表 = 收集所有父级路径(字段路径列表: [字段路径])
        let 初始化代码 = 生成统一初始化代码(父级路径列表: 父级路径列表)
        let 是否时间戳 = Double(当前值) != nil && (Double(当前值) ?? 0) > 1000000000
        let 永久值 = 是否时间戳 ? "4070908800" : "\"2099-12-31 23:59:59\""
        return """
// ======================
// 功能：会员永久有效
// 识别字段：\(字段路径)（当前值：\(当前值)）
// ======================
// 【第一步】获取响应体，保存原始内容作为兜底
const 原始响应体 = ($response && $response.body) || "";

// 【第二步】把响应体文本"翻译"成脚本能修改的对象
let body = {};
try {
    body = JSON.parse(原始响应体);
} catch (解析错误) {
    console.log("[放行] 响应不是JSON格式，原样返回");
    $done({ body: 原始响应体 });
    return;
}

try {
    // 【第三步】修改对象里的字段（统一初始化父级路径，直接赋值）
\(初始化代码)    body.\(字段路径) = \(永久值);  // 会员永久有效
    console.log("✔️会员到期时间设置完成");

    // 【第四步】把改好的对象重新"压回"文本字符串，交给圈X
    $done({ body: JSON.stringify(body) });
} catch (错误) {
    console.log("[兜底] 脚本异常: " + (错误 && 错误.message ? 错误.message : String(错误)));
    $done({ body: 原始响应体 });
}
"""
    }

    /// 生成会员等级修改模板（统一初始化+直接修改风格）
    private static func 生成会员等级模板(字段路径: String, 当前值: String) -> String {
        let 父级路径列表 = 收集所有父级路径(字段路径列表: [字段路径])
        let 初始化代码 = 生成统一初始化代码(父级路径列表: 父级路径列表)
        let 是否数字 = Int(当前值) != nil
        let 最高值 = 是否数字 ? "6" : "\"VIP6\""
        return """
// ======================
// 功能：提升会员等级
// 识别字段：\(字段路径)（当前值：\(当前值)）
// ======================
// 【第一步】获取响应体，保存原始内容作为兜底
const 原始响应体 = ($response && $response.body) || "";

// 【第二步】把响应体文本"翻译"成脚本能修改的对象
let body = {};
try {
    body = JSON.parse(原始响应体);
} catch (解析错误) {
    console.log("[放行] 响应不是JSON格式，原样返回");
    $done({ body: 原始响应体 });
    return;
}

try {
    // 【第三步】修改对象里的字段（统一初始化父级路径，直接赋值）
\(初始化代码)    body.\(字段路径) = \(最高值);  // 会员等级最高
    console.log("✔️会员等级提升完成");

    // 【第四步】把改好的对象重新"压回"文本字符串，交给圈X
    $done({ body: JSON.stringify(body) });
} catch (错误) {
    console.log("[兜底] 脚本异常: " + (错误 && 错误.message ? 错误.message : String(错误)));
    $done({ body: 原始响应体 });
}
"""
    }

    /// 生成去广告字段模板（globalData/appver设为{}空对象，其他广告字段删除）
    private static func 生成去广告字段模板(字段路径列表: [String]) -> String {
        // 分离特殊字段（globalData/appver设为{}）和普通广告字段（删除）
        let 特殊置空字段 = 字段路径列表.filter { 路径 in
            let 小写 = 路径.lowercased()
            return 小写.hasSuffix("globaldata") || 小写.hasSuffix("appver")
        }
        let 普通删除字段 = 字段路径列表.filter { 路径 in
            let 小写 = 路径.lowercased()
            return !小写.hasSuffix("globaldata") && !小写.hasSuffix("appver")
        }
        let 字段列表文本 = 普通删除字段.map { "\"\($0)\"" }.joined(separator: ",\n    ")
        let 置空代码块 = 特殊置空字段.map { 路径 in
            "    body.\(路径) = {};  // 清空\(路径)广告配置"
        }.joined(separator: "\n")
        let 置空注释 = 特殊置空字段.isEmpty ? "" : "\n    // ====== 清空全局广告配置/应用版本配置 ======\n\(置空代码块)\n"
        let 删除注释 = 普通删除字段.isEmpty ? "" : """
    // ====== 删除识别到的广告字段 ======
    const 要删除的字段 = [
    \(字段列表文本)
    ];

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

    要删除的字段.forEach(function(路径) {
        try { 删除字段(body, 路径); } catch (e) {}
    });
"""
        return """
// ======================
// 功能：去广告（删除/清空识别到的广告字段）
// 识别到\(字段路径列表.count)个广告字段（globalData/appver设为{}，其他删除）
// ======================
// 【第一步】获取响应体，保存原始内容作为兜底
const 原始响应体 = ($response && $response.body) || "";

// 【第二步】把响应体文本"翻译"成脚本能修改的对象
let body = {};
try {
    body = JSON.parse(原始响应体);
} catch (解析错误) {
    console.log("[放行] 响应不是JSON格式，原样返回");
    $done({ body: 原始响应体 });
    return;
}

try {
    // 【第三步】处理广告字段\(置空注释)\(删除注释)
    // 【第四步】把改好的对象重新"压回"文本字符串，交给圈X
    $done({ body: JSON.stringify(body) });
} catch (错误) {
    console.log("[兜底] 脚本异常: " + (错误 && 错误.message ? 错误.message : String(错误)));
    $done({ body: 原始响应体 });
}
"""
    }

    /// 生成去广告数组成员模板
    private static func 生成去广告数组成员模板(数组路径: String) -> String {
        return """
// ======================
// 功能：去广告数组（从列表中过滤广告项）
// 识别数组：\(数组路径)
// ======================
// 【第一步】获取响应体，保存原始内容作为兜底
const 原始响应体 = ($response && $response.body) || "";

// 【第二步】把响应体文本"翻译"成脚本能修改的对象
let body = {};
try {
    body = JSON.parse(原始响应体);
} catch (解析错误) {
    console.log("[放行] 响应不是JSON格式，原样返回");
    $done({ body: 原始响应体 });
    return;
}

try {
    // 【第三步】过滤数组里的广告项
    function 是否为广告(项) {
        if (!项 || typeof 项 !== "object") return false;
        return 项.isAd === true || 项.is_ad === true || 项.hasAd === true
            || 项.ad !== undefined || 项.ad_id !== undefined
            || 项.type === "ad" || 项.type === "advert";
    }

    const 部分 = "\(数组路径)".split(".");
    let 父级 = body;
    let 路径有效 = true;
    for (let i = 0; i < 部分.length - 1; i++) {
        if (父级[部分[i]] === undefined || 父级[部分[i]] === null || typeof 父级[部分[i]] !== "object") {
            路径有效 = false; break;
        }
        父级 = 父级[部分[i]];
    }

    if (路径有效) {
        const 列表 = 父级[部分[部分.length - 1]];
        if (Array.isArray(列表)) {
            父级[部分[部分.length - 1]] = 列表.filter(function(项) {
                try { return !是否为广告(项); } catch (e) { return true; }
            });
        }
    }

    // 【第四步】把改好的对象重新"压回"文本字符串，交给圈X
    $done({ body: JSON.stringify(body) });
} catch (错误) {
    console.log("[兜底] 脚本异常: " + (错误 && 错误.message ? 错误.message : String(错误)));
    $done({ body: 原始响应体 });
}
"""
    }

    // MARK: - 用户核心信息模板生成

    /// 生成导出用户核心信息模板
    private static func 生成导出用户信息模板(用户字段: [识别字段]) -> String {
        let 字段列表文本 = 用户字段.map { "\"\($0.字段路径)\"" }.joined(separator: ",\n    ")
        let 类型映射 = 用户字段.map { "case \"\($0.字段路径)\": return \"\(类型文本($0.类型))\"" }.joined(separator: "\n        ")
        return """
// ======================
// 功能：导出用户核心信息
// 识别到\(用户字段.count)项用户核心字段，通过通知弹窗展示
// ======================
// 【第一步】获取响应体，保存原始内容作为兜底
const 原始响应体 = ($response && $response.body) || "";

// 【第二步】把响应体文本"翻译"成脚本能读取的对象
let body = {};
try {
    body = JSON.parse(原始响应体);
} catch (解析错误) {
    console.log("[放行] 响应不是JSON格式，原样返回");
    $done({ body: 原始响应体 });
    return;
}

try {
    // 【第三步】读取并展示用户核心信息
    const 用户字段 = [
    \(字段列表文本)
    ];

    function 读取字段(obj, 路径) {
        return String(路径).split(".").reduce(function(o, k) {
            return (o || {})[k];
        }, obj);
    }

    function 字段类型(路径) {
        switch (路径) {
        \(类型映射)
        default: return "其他";
        }
    }

    let 信息列表 = [];
    用户字段.forEach(function(路径) {
        try {
            const 值 = 读取字段(body, 路径);
            if (值 !== undefined && 值 !== null) {
                信息列表.push(字段类型(路径) + "：" + String(值));
            }
        } catch (e) {}
    });

    if (信息列表.length > 0) {
        try { $notify("用户核心信息", "共" + 信息列表.length + "项", 信息列表.join("\\n")); } catch (e) {}
    }

    // 【第四步】原样返回响应（此模板只读取不修改）
    $done({ body: 原始响应体 });
} catch (错误) {
    console.log("[兜底] 脚本异常: " + (错误 && 错误.message ? 错误.message : String(错误)));
    $done({ body: 原始响应体 });
}
"""
    }

    /// 生成隐私保护模板（隐藏手机号和邮箱，统一初始化+直接修改风格）
    private static func 生成隐私保护模板(隐私字段: [识别字段]) -> String {
        // 收集所有隐私字段的父级路径，统一初始化
        let 所有字段路径 = 隐私字段.map { $0.字段路径 }
        let 父级路径列表 = 收集所有父级路径(字段路径列表: 所有字段路径)
        let 初始化代码 = 生成统一初始化代码(父级路径列表: 父级路径列表)

        var 处理代码 = ""
        // 手机号掩码（直接修改风格）
        let 手机号字段 = 隐私字段.filter { $0.类型 == .手机号 }
        if !手机号字段.isEmpty {
            处理代码 += "    // ====== 手机号掩码保护 ======\n"
            for 字段 in 手机号字段 {
                处理代码 += "    body.\(字段.字段路径) = String(body.\(字段.字段路径) || \"\").replace(/(\\d{3})\\d{4}(\\d{4})/, \"$1****$2\");  // 手机号掩码\n"
            }
        }
        // 邮箱掩码（直接修改风格）
        let 邮箱字段 = 隐私字段.filter { $0.类型 == .邮箱 }
        if !邮箱字段.isEmpty {
            处理代码 += "    // ====== 邮箱掩码保护 ======\n"
            for 字段 in 邮箱字段 {
                处理代码 += "    { let _e = String(body.\(字段.字段路径) || \"\"); let _at = _e.indexOf(\"@\"); if (_at > 2) { body.\(字段.字段路径) = _e.substring(0, 2) + \"****\" + _e.substring(_at); } }  // 邮箱掩码\n"
            }
        }

        return """
// ======================
// 功能：隐私保护（隐藏手机号和邮箱）
// 识别到\(隐私字段.count)个隐私字段，替换为星号掩码
// ======================
// 【第一步】获取响应体，保存原始内容作为兜底
const 原始响应体 = ($response && $response.body) || "";

// 【第二步】把响应体文本"翻译"成脚本能修改的对象
let body = {};
try {
    body = JSON.parse(原始响应体);
} catch (解析错误) {
    console.log("[放行] 响应不是JSON格式，原样返回");
    $done({ body: 原始响应体 });
    return;
}

try {
    // 【第三步】掩码处理隐私字段（统一初始化父级路径，直接修改）
\(初始化代码)\(处理代码)
    console.log("✔️隐私保护处理完成，共\(隐私字段.count)个字段");

    // 【第四步】把改好的对象重新"压回"文本字符串，交给圈X
    $done({ body: JSON.stringify(body) });
} catch (错误) {
    console.log("[兜底] 脚本异常: " + (错误 && 错误.message ? 错误.message : String(错误)));
    $done({ body: 原始响应体 });
}
"""
    }

    /// 生成修改用户昵称模板（统一初始化+直接修改风格）
    private static func 生成修改昵称模板(字段路径: String, 当前值: String) -> String {
        let 父级路径列表 = 收集所有父级路径(字段路径列表: [字段路径])
        let 初始化代码 = 生成统一初始化代码(父级路径列表: 父级路径列表)
        return """
// ======================
// 功能：修改用户昵称
// 识别字段：\(字段路径)（当前值：\(当前值)）
// ======================
// 【第一步】获取响应体，保存原始内容作为兜底
const 原始响应体 = ($response && $response.body) || "";

// 【第二步】把响应体文本"翻译"成脚本能修改的对象
let body = {};
try {
    body = JSON.parse(原始响应体);
} catch (解析错误) {
    console.log("[放行] 响应不是JSON格式，原样返回");
    $done({ body: 原始响应体 });
    return;
}

try {
    // 【第三步】修改对象里的字段（统一初始化父级路径，直接赋值）
\(初始化代码)    body.\(字段路径) = "新昵称";  // 修改用户昵称
    console.log("✔️用户昵称修改完成");

    // 【第四步】把改好的对象重新"压回"文本字符串，交给圈X
    $done({ body: JSON.stringify(body) });
} catch (错误) {
    console.log("[兜底] 脚本异常: " + (错误 && 错误.message ? 错误.message : String(错误)));
    $done({ body: 原始响应体 });
}
"""
    }

    /// 生成修改积分余额模板（统一初始化+直接修改风格）
    private static func 生成修改积分模板(字段路径: String, 当前值: String) -> String {
        let 父级路径列表 = 收集所有父级路径(字段路径列表: [字段路径])
        let 初始化代码 = 生成统一初始化代码(父级路径列表: 父级路径列表)
        let 是否数字 = Double(当前值) != nil
        let 新值 = 是否数字 ? "999999" : "\"999999\""
        return """
// ======================
// 功能：修改积分余额
// 识别字段：\(字段路径)（当前值：\(当前值)）
// ======================
// 【第一步】获取响应体，保存原始内容作为兜底
const 原始响应体 = ($response && $response.body) || "";

// 【第二步】把响应体文本"翻译"成脚本能修改的对象
let body = {};
try {
    body = JSON.parse(原始响应体);
} catch (解析错误) {
    console.log("[放行] 响应不是JSON格式，原样返回");
    $done({ body: 原始响应体 });
    return;
}

try {
    // 【第三步】修改对象里的字段（统一初始化父级路径，直接赋值）
\(初始化代码)    body.\(字段路径) = \(新值);  // 积分余额拉满
    console.log("✔️积分余额修改完成");

    // 【第四步】把改好的对象重新"压回"文本字符串，交给圈X
    $done({ body: JSON.stringify(body) });
} catch (错误) {
    console.log("[兜底] 脚本异常: " + (错误 && 错误.message ? 错误.message : String(错误)));
    $done({ body: 原始响应体 });
}
"""
    }

    /// 字段类型中文文本
    private static func 类型文本(_ 类型: 识别字段.字段类型) -> String {
        switch 类型 {
        case .用户ID: return "用户ID"
        case .用户名: return "用户名"
        case .手机号: return "手机号"
        case .邮箱: return "邮箱"
        case .头像: return "头像"
        case .积分余额: return "积分余额"
        case .登录Token: return "登录Token"
        case .性别: return "性别"
        case .生日: return "生日"
        default: return "其他"
        }
    }
}
