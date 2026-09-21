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
        /// 识别到的广告相关字段（JSON格式）
        var 广告字段: [识别字段] = []
        /// 识别到的用户核心信息字段
        var 用户核心字段: [识别字段] = []
        /// 原始数据格式
        var 数据格式: String = "未知"
        /// 是否是JSON格式响应体
        var 是否JSON = false
        /// 非JSON文本中识别到的广告关键词（用于正则替换式广告屏蔽）
        var 文本广告关键词: [String] = []
        /// 是否识别到有效信息
        var 有结果: Bool {
            !会员字段.isEmpty || !广告字段.isEmpty || !用户核心字段.isEmpty || !文本广告关键词.isEmpty
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

    /// 广告标记字段关键词（布尔型/对象型，识别后设为0或{}）
    private static let 广告标记关键词 = [
        // 基础广告开关
        "isAd", "is_ad", "hasAd", "has_ad", "isAdvert", "is_advert",
        "ad", "ads", "advert", "advertisement", "sponsored", "isSponsored",
        "is_sponsored", "promotion", "isPromotion", "is_promotion",
        "adFlag", "ad_flag", "adType", "ad_type", "adSwitch", "ad_switch",
        "adEnable", "ad_enable", "adEnabled", "ad_enabled", "showAd", "show_ad",
        "showAds", "show_ads", "displayAd", "display_ad", "enableAd", "enable_ad",
        "openAd", "open_ad", "adOpen", "ad_open", "adStatus", "ad_status",
        "adShow", "ad_show", "adDisplay", "ad_display", "adVisible", "ad_visible",
        // 广告配置对象
        "globalData", "appver", "adConfig", "ad_config", "adConf", "ad_conf",
        "adSetting", "ad_setting", "adSettings", "ad_settings", "adOption", "ad_option",
        "adOptions", "ad_options", "adParam", "ad_param", "adParams", "ad_params",
        "adInfo", "ad_info", "adData", "ad_data", "adModel", "ad_model",
        "advertConfig", "advert_config", "advertInfo", "advert_info",
        "promoConfig", "promo_config", "promoInfo", "promo_info",
        // 开屏/插屏/横幅广告开关
        "splashAd", "splash_ad", "splash", "isSplash", "is_splash",
        "interstitialAd", "interstitial_ad", "interstitial", "isInterstitial", "is_interstitial",
        "bannerAd", "banner_ad", "isBanner", "is_banner", "bannerSwitch", "banner_switch",
        "rewardAd", "reward_ad", "rewardedAd", "rewarded_ad", "isReward", "is_reward",
        "nativeAd", "native_ad", "isNative", "is_native",
        "floatAd", "float_ad", "isFloat", "is_float", "floatingAd", "floating_ad",
        "videoAd", "video_ad", "isVideoAd", "is_video_ad",
        "insertAd", "insert_ad", "isInsert", "is_insert",
        "popupAd", "popup_ad", "isPopup", "is_popup", "popAd", "pop_ad",
        // 会员去广告相关
        "noAd", "no_ad", "noAds", "no_ads", "removeAd", "remove_ad",
        "adFree", "ad_free", "isAdFree", "is_ad_free", "vipNoAd", "vip_no_ad",
        "memberNoAd", "member_no_ad",
        // 信息流/时间线广告
        "feedAd", "feed_ad", "streamAd", "stream_ad", "timelineAd", "timeline_ad",
        "isFeedAd", "is_feed_ad", "isStreamAd", "is_stream_ad", "isTimelineAd", "is_timeline_ad",
        // 贴片广告
        "preRollAd", "pre_roll_ad", "midRollAd", "mid_roll_ad", "postRollAd", "post_roll_ad",
        "isPreRoll", "is_pre_roll", "isMidRoll", "is_mid_roll", "isPostRoll", "is_post_roll",
        // 角标/徽章广告
        "cornerAd", "corner_ad", "badgeAd", "badge_ad", "isCornerAd", "is_corner_ad",
        // 通知/推送广告
        "notificationAd", "notification_ad", "pushAd", "push_ad", "isPushAd", "is_push_ad",
        // 广告策略/规则/版本
        "adStrategy", "ad_strategy", "adRule", "ad_rule", "adPolicy", "ad_policy",
        "adVersion", "ad_version", "adPlan", "ad_plan", "adScheme", "ad_scheme",
        // 会员免广告
        "adVipFree", "ad_vip_free", "adMemberFree", "ad_member_free", "adPaidFree", "ad_paid_free",
        "vipAdFree", "vip_ad_free", "memberAdFree", "member_ad_free",
        // 广告计数/频率/间隔
        "adCount", "ad_count", "adNum", "ad_num", "adFrequency", "ad_frequency",
        "adInterval", "ad_interval", "adTimes", "ad_times", "adLimit", "ad_limit",
        // 广告优先级/权重
        "adPriority", "ad_priority", "adWeight", "ad_weight", "adLevel", "ad_level",
        "adRank", "ad_rank", "adSort", "ad_sort",
        // 广告调试/测试
        "adDebug", "ad_debug", "adTest", "ad_test", "adMock", "ad_mock", "adDemo", "ad_demo",
        // 更多广告配置对象
        "adEnvironment", "ad_environment", "adChannel", "ad_channel", "adSourceConfig", "ad_source_config",
        "adSdk", "ad_sdk", "adSdkConfig", "ad_sdk_config", "adSdkVersion", "ad_sdk_version",
        "adNetwork", "ad_network", "adPlatform", "ad_platform", "adProvider", "ad_provider",
        "adVendor", "ad_vendor", "adAgency", "ad_agency", "adPartner", "ad_partner",
        // 更多广告类型
        "richMediaAd", "rich_media_ad", "isRichMedia", "is_rich_media",
        "expandableAd", "expandable_ad", "isExpandable", "is_expandable",
        "stickyAd", "sticky_ad", "isSticky", "is_sticky",
        "stickyBanner", "sticky_banner", "isStickyBanner", "is_sticky_banner",
        "wallAd", "wall_ad", "isWallAd", "is_wall_ad", "adWall", "ad_wall",
        "offerWall", "offer_wall", "isOfferWall", "is_offer_wall",
        "interstitialVideo", "interstitial_video", "isInterstitialVideo", "is_interstitial_video",
        "rewardedVideo", "rewarded_video", "isRewardedVideo", "is_rewarded_video",
        "playableAd", "playable_ad", "isPlayable", "is_playable",
        "instreamAd", "instream_ad", "isInstream", "is_instream",
        "outstreamAd", "outstream_ad", "isOutstream", "is_outstream"
    ]

    /// 广告链接/图片/视频字段关键词（识别后设为空字符串）
    private static let 广告资源关键词 = [
        // 基础广告资源
        "adUrl", "ad_url", "adLink", "ad_link", "adImage", "ad_image",
        "adImg", "ad_img", "adIcon", "ad_icon", "adTitle", "ad_title",
        "adContent", "ad_content", "adTrack", "ad_track", "adClick",
        "ad_click", "adId", "ad_id", "adSlot", "ad_slot", "adPosition",
        "ad_position", "bannerUrl", "banner_url", "bannerImage", "banner_image",
        "popupUrl", "popup_url", "popupImage", "popup_image",
        // 广告描述/副标题
        "adDesc", "ad_desc", "adDescription", "ad_description", "adSubtitle", "ad_subtitle",
        "adSummary", "ad_summary", "adText", "ad_text", "adMsg", "ad_msg",
        "adMessage", "ad_message", "adBody", "ad_body", "adDetail", "ad_detail",
        // 广告跳转/落地页
        "adJumpUrl", "ad_jump_url", "adJump", "ad_jump", "adTarget", "ad_target",
        "adRedirect", "ad_redirect", "adRedirectUrl", "ad_redirect_url",
        "adLanding", "ad_landing", "adLandingUrl", "ad_landing_url",
        "adAction", "ad_action", "adActionUrl", "ad_action_url",
        "adDeepLink", "ad_deep_link", "adDeeplink", "ad_deeplink",
        // 广告视频资源
        "adVideo", "ad_video", "adVideoUrl", "ad_video_url", "adVideoImage", "ad_video_image",
        "adVideoCover", "ad_video_cover", "adVideoThumb", "ad_video_thumb",
        "adMedia", "ad_media", "adMediaUrl", "ad_media_url",
        "adSource", "ad_source", "adSourceUrl", "ad_source_url",
        // 开屏广告资源
        "splashUrl", "splash_url", "splashImage", "splash_image", "splashImg", "splash_img",
        "splashIcon", "splash_icon", "splashTitle", "splash_title", "splashDesc", "splash_desc",
        "splashJumpUrl", "splash_jump_url", "splashLink", "splash_link",
        // 插屏广告资源
        "interstitialUrl", "interstitial_url", "interstitialImage", "interstitial_image",
        "interstitialImg", "interstitial_img", "interstitialTitle", "interstitial_title",
        "interstitialDesc", "interstitial_desc", "interstitialJumpUrl", "interstitial_jump_url",
        // 横幅广告资源
        "bannerImg", "banner_img", "bannerIcon", "banner_icon", "bannerTitle", "banner_title",
        "bannerDesc", "banner_desc", "bannerJumpUrl", "banner_jump_url", "bannerLink", "banner_link",
        "bannerTarget", "banner_target", "bannerRedirect", "banner_redirect",
        // 激励视频广告资源
        "rewardUrl", "reward_url", "rewardImage", "reward_image", "rewardTitle", "reward_title",
        "rewardDesc", "reward_desc", "rewardedUrl", "rewarded_url", "rewardedImage", "rewarded_image",
        // 原生广告资源
        "nativeUrl", "native_url", "nativeImage", "native_image", "nativeTitle", "native_title",
        "nativeDesc", "native_desc", "nativeIcon", "native_icon",
        // 悬浮广告资源
        "floatUrl", "float_url", "floatImage", "float_image", "floatIcon", "float_icon",
        "floatTitle", "float_title", "floatDesc", "float_desc", "floatJumpUrl", "float_jump_url",
        "floatingUrl", "floating_url", "floatingImage", "floating_image",
        // 弹窗广告资源
        "popupImg", "popup_img", "popupIcon", "popup_icon", "popupTitle", "popup_title",
        "popupDesc", "popup_desc", "popupJumpUrl", "popup_jump_url", "popupLink", "popup_link",
        "popUrl", "pop_url", "popImage", "pop_image", "popTitle", "pop_title", "popDesc", "pop_desc",
        // 广告按钮/CTA
        "adButton", "ad_button", "adBtn", "ad_btn", "adButtonText", "ad_button_text",
        "adBtnText", "ad_btn_text", "adCta", "ad_cta", "adCtaText", "ad_cta_text",
        "adActionText", "ad_action_text", "adButtonUrl", "ad_button_url", "adBtnUrl", "ad_btn_url",
        // 广告统计/上报
        "adReport", "ad_report", "adReportUrl", "ad_report_url", "adTrackUrl", "ad_track_url",
        "adTracking", "ad_tracking", "adTrackingUrl", "ad_tracking_url", "adMonitor", "ad_monitor",
        "adMonitorUrl", "ad_monitor_url", "adStat", "ad_stat", "adStatUrl", "ad_stat_url",
        "adPv", "ad_pv", "adPvUrl", "ad_pv_url", "adUv", "ad_uv", "adUvUrl", "ad_uv_url",
        "adExpose", "ad_expose", "adExposeUrl", "ad_expose_url", "adImpression", "ad_impression",
        "adImpressionUrl", "ad_impression_url", "adShowUrl", "ad_show_url", "adViewUrl", "ad_view_url",
        "adClickUrl", "ad_click_url", "adClickTrack", "ad_click_track", "adClickTrackUrl", "ad_click_track_url",
        // 广告品牌/广告主
        "adBrand", "ad_brand", "adBrandName", "ad_brand_name", "advertiser", "advertiserName",
        "advertiser_name", "adOwner", "ad_owner", "adOwnerName", "ad_owner_name",
        "adSponsor", "ad_sponsor", "adSponsorName", "ad_sponsor_name",
        // 广告价格/积分
        "adPrice", "ad_price", "adCoin", "ad_coin", "adPoint", "ad_point", "adScore", "ad_score",
        "adReward", "ad_reward", "adRewardCoin", "ad_reward_coin", "adRewardPoint", "ad_reward_point",
        // 广告有效期
        "adStartTime", "ad_start_time", "adEndTime", "ad_end_time", "adExpire", "ad_expire",
        "adExpireTime", "ad_expire_time", "adValidTime", "ad_valid_time", "adDuration", "ad_duration",
        // 更多广告图片资源
        "adImageUrl", "ad_image_url", "adPic", "ad_pic", "adPicUrl", "ad_pic_url",
        "adCover", "ad_cover", "adCoverUrl", "ad_cover_url", "adThumbnail", "ad_thumbnail",
        "adThumbUrl", "ad_thumb_url", "adBannerUrl", "ad_banner_url", "adBannerImg", "ad_banner_img",
        "adSplashUrl", "ad_splash_url", "adSplashImg", "ad_splash_img", "adPopupUrl", "ad_popup_url",
        "adPopupImg", "ad_popup_img", "adFloatUrl", "ad_float_url", "adFloatImg", "ad_float_img",
        "adNativeUrl", "ad_native_url", "adNativeImg", "ad_native_img", "adFeedUrl", "ad_feed_url",
        "adFeedImg", "ad_feed_img", "adStreamUrl", "ad_stream_url", "adStreamImg", "ad_stream_img",
        // 更多广告视频资源
        "adVideoLink", "ad_video_link", "adVideoSource", "ad_video_source", "adVideoPath", "ad_video_path",
        "adMp4", "ad_mp4", "adMp4Url", "ad_mp4_url", "adM3u8", "ad_m3u8", "adM3u8Url", "ad_m3u8_url",
        "adVideoFile", "ad_video_file", "adVideoFileName", "ad_video_file_name", "adVideoDuration", "ad_video_duration",
        "adVideoSize", "ad_video_size", "adVideoWidth", "ad_video_width", "adVideoHeight", "ad_video_height",
        "adVideoBitrate", "ad_video_bitrate", "adVideoFps", "ad_video_fps", "adVideoFormat", "ad_video_format",
        "adVideoCodec", "ad_video_codec", "adVideoQuality", "ad_video_quality", "adVideoDefinition", "ad_video_definition",
        // 更多广告音频资源
        "adAudio", "ad_audio", "adAudioUrl", "ad_audio_url", "adVoice", "ad_voice", "adVoiceUrl", "ad_voice_url",
        "adMusic", "ad_music", "adMusicUrl", "ad_music_url", "adSound", "ad_sound", "adSoundUrl", "ad_sound_url",
        "adMp3", "ad_mp3", "adMp3Url", "ad_mp3_url", "adAudioDuration", "ad_audio_duration", "adAudioSize", "ad_audio_size",
        // 更多广告HTML/富媒体资源
        "adHtml", "ad_html", "adHtmlUrl", "ad_html_url", "adContentUrl", "ad_content_url", "adIframe", "ad_iframe",
        "adIframeUrl", "ad_iframe_url", "adEmbed", "ad_embed", "adEmbedUrl", "ad_embed_url", "adObject", "ad_object",
        "adObjectUrl", "ad_object_url", "adSnippet", "ad_snippet", "adSnippetUrl", "ad_snippet_url", "adCode", "ad_code",
        "adCodeUrl", "ad_code_url", "adScript", "ad_script", "adScriptUrl", "ad_script_url", "adCss", "ad_css",
        "adCssUrl", "ad_css_url", "adJs", "ad_js", "adJsUrl", "ad_js_url",
        // 更多广告位置/槽位
        "adSlotId", "ad_slot_id", "adPositionId", "ad_position_id", "adPlace", "ad_place", "adPlacement", "ad_placement",
        "adPlacementId", "ad_placement_id", "adArea", "ad_area", "adAreaId", "ad_area_id", "adZone", "ad_zone",
        "adZoneId", "ad_zone_id", "adSpace", "ad_space", "adSpaceId", "ad_space_id", "adLocation", "ad_location",
        "adLocationId", "ad_location_id", "adSpot", "ad_spot", "adSpotId", "ad_spot_id", "adUnit", "ad_unit",
        "adUnitId", "ad_unit_id", "adTag", "ad_tag", "adTagId", "ad_tag_id", "adCategory", "ad_category",
        "adCategoryId", "ad_category_id", "adTypeCode", "ad_type_code", "adTypeId", "ad_type_id",
        // 更多广告样式/模板
        "adStyle", "ad_style", "adStyleId", "ad_style_id", "adTemplate", "ad_template", "adTemplateId", "ad_template_id",
        "adLayout", "ad_layout", "adLayoutId", "ad_layout_id", "adTheme", "ad_theme", "adThemeId", "ad_theme_id",
        "adColor", "ad_color", "adBgColor", "ad_bg_color", "adTextColor", "ad_text_color", "adTitleColor", "ad_title_color",
        "adSize", "ad_size", "adWidth", "ad_width", "adHeight", "ad_height", "adRadius", "ad_radius", "adBorder", "ad_border",
        "adBorderColor", "ad_border_color", "adBorderWidth", "ad_border_width", "adPadding", "ad_padding", "adMargin", "ad_margin",
        "adFont", "ad_font", "adFontSize", "ad_font_size", "adFontColor", "ad_font_color", "adFontWeight", "ad_font_weight",
        "adAnimation", "ad_animation", "adAnimationType", "ad_animation_type", "adAnimationDuration", "ad_animation_duration",
        "adEffect", "ad_effect", "adEffectType", "ad_effect_type", "adTransition", "ad_transition", "adTransitionType", "ad_transition_type",
        // 更多广告交互/按钮
        "adClose", "ad_close", "adCloseUrl", "ad_close_url", "adCloseIcon", "ad_close_icon", "adCloseText", "ad_close_text",
        "adSkip", "ad_skip", "adSkipUrl", "ad_skip_url", "adSkipIcon", "ad_skip_icon", "adSkipText", "ad_skip_text",
        "adSkipTime", "ad_skip_time", "adSkipCountdown", "ad_skip_countdown", "adMute", "ad_mute", "adMuteUrl", "ad_mute_url",
        "adMuteIcon", "ad_mute_icon", "adFullscreen", "ad_fullscreen", "adFullscreenUrl", "ad_fullscreen_url", "adFullscreenIcon", "ad_fullscreen_icon",
        "adPlay", "ad_play", "adPlayUrl", "ad_play_url", "adPlayIcon", "ad_play_icon", "adPause", "ad_pause", "adPauseUrl", "ad_pause_url",
        "adPauseIcon", "ad_pause_icon", "adStop", "ad_stop", "adStopUrl", "ad_stop_url", "adStopIcon", "ad_stop_icon",
        "adReplay", "ad_replay", "adReplayUrl", "ad_replay_url", "adReplayIcon", "ad_replay_icon",
        "adDownload", "ad_download", "adDownloadUrl", "ad_download_url", "adDownloadIcon", "ad_download_icon", "adDownloadText", "ad_download_text",
        "adInstall", "ad_install", "adInstallUrl", "ad_install_url", "adInstallIcon", "ad_install_icon", "adInstallText", "ad_install_text",
        "adShare", "ad_share", "adShareUrl", "ad_share_url", "adShareIcon", "ad_share_icon", "adShareText", "ad_share_text",
        "adFavorite", "ad_favorite", "adFavoriteUrl", "ad_favorite_url", "adFavoriteIcon", "ad_favorite_icon",
        "adLike", "ad_like", "adLikeUrl", "ad_like_url", "adLikeIcon", "ad_like_icon", "adLikeCount", "ad_like_count",
        "adComment", "ad_comment", "adCommentUrl", "ad_comment_url", "adCommentIcon", "ad_comment_icon", "adCommentCount", "ad_comment_count",
        // 更多广告落地页/跳转
        "adPageUrl", "ad_page_url", "adWebUrl", "ad_web_url", "adSiteUrl", "ad_site_url", "adH5Url", "ad_h5_url",
        "adH5", "ad_h5", "adMiniProgram", "ad_mini_program", "adMiniProgramId", "ad_mini_program_id", "adMiniProgramPath", "ad_mini_program_path",
        "adMiniApp", "ad_mini_app", "adMiniAppId", "ad_mini_app_id", "adMiniAppPath", "ad_mini_app_path",
        "adScheme", "ad_scheme", "adSchemeUrl", "ad_scheme_url", "adIntent", "ad_intent", "adIntentUrl", "ad_intent_url",
        "adUniversalLink", "ad_universal_link", "adUniversalLinkUrl", "ad_universal_link_url", "adAppLink", "ad_app_link",
        "adAppLinkUrl", "ad_app_link_url", "adDeepLinkUrl", "ad_deep_link_url", "adDeeplinkUrl", "ad_deeplink_url",
        "adTargetUrl", "ad_target_url", "adDestinationUrl", "ad_destination_url", "adFinalUrl", "ad_final_url",
        "adLandingPage", "ad_landing_page", "adLandingPageUrl", "ad_landing_page_url", "adClickUrl", "ad_click_url",
        "adClickThroughUrl", "ad_click_through_url", "adClickTarget", "ad_click_target", "adClickAction", "ad_click_action",
        // 更多广告品牌/广告主
        "adBrandUrl", "ad_brand_url", "adBrandLogo", "ad_brand_logo", "adBrandLogoUrl", "ad_brand_logo_url",
        "adBrandIcon", "ad_brand_icon", "adBrandIconUrl", "ad_brand_icon_url", "adBrandImage", "ad_brand_image",
        "adBrandImageUrl", "ad_brand_image_url", "adAdvertiserId", "ad_advertiser_id", "adAdvertiserUrl", "ad_advertiser_url",
        "adAdvertiserLogo", "ad_advertiser_logo", "adAdvertiserLogoUrl", "ad_advertiser_logo_url", "adAdvertiserIcon", "ad_advertiser_icon",
        "adOwnerId", "ad_owner_id", "adOwnerUrl", "ad_owner_url", "adOwnerLogo", "ad_owner_logo", "adOwnerLogoUrl", "ad_owner_logo_url",
        "adSponsorId", "ad_sponsor_id", "adSponsorUrl", "ad_sponsor_url", "adSponsorLogo", "ad_sponsor_logo", "adSponsorLogoUrl", "ad_sponsor_logo_url",
        "adAgencyId", "ad_agency_id", "adAgencyUrl", "ad_agency_url", "adAgencyName", "ad_agency_name",
        "adPartnerId", "ad_partner_id", "adPartnerUrl", "ad_partner_url", "adPartnerName", "ad_partner_name",
        "adVendorId", "ad_vendor_id", "adVendorUrl", "ad_vendor_url", "adVendorName", "ad_vendor_name",
        "adProviderId", "ad_provider_id", "adProviderUrl", "ad_provider_url", "adProviderName", "ad_provider_name",
        "adNetworkId", "ad_network_id", "adNetworkUrl", "ad_network_url", "adNetworkName", "ad_network_name",
        "adPlatformId", "ad_platform_id", "adPlatformUrl", "ad_platform_url", "adPlatformName", "ad_platform_name",
        // 更多广告统计/上报
        "adCallback", "ad_callback", "adCallbackUrl", "ad_callback_url", "adNotify", "ad_notify", "adNotifyUrl", "ad_notify_url",
        "adPing", "ad_ping", "adPingUrl", "ad_ping_url", "adBeacon", "ad_beacon", "adBeaconUrl", "ad_beacon_url",
        "adLog", "ad_log", "adLogUrl", "ad_log_url", "adEvent", "ad_event", "adEventUrl", "ad_event_url",
        "adEventType", "ad_event_type", "adEventName", "ad_event_name", "adEventId", "ad_event_id", "adEventTime", "ad_event_time",
        "adEventParams", "ad_event_params", "adEventData", "ad_event_data", "adEventPayload", "ad_event_payload",
        "adTrackEvent", "ad_track_event", "adTrackEventType", "ad_track_event_type", "adTrackEventName", "ad_track_event_name",
        "adMonitorEvent", "ad_monitor_event", "adMonitorEventType", "ad_monitor_event_type", "adMonitorEventName", "ad_monitor_event_name",
        "adStatEvent", "ad_stat_event", "adStatEventType", "ad_stat_event_type", "adStatEventName", "ad_stat_event_name",
        "adReportEvent", "ad_report_event", "adReportEventType", "ad_report_event_type", "adReportEventName", "ad_report_event_name",
        "adExposeEvent", "ad_expose_event", "adExposeEventType", "ad_expose_event_type", "adExposeEventName", "ad_expose_event_name",
        "adImpressionEvent", "ad_impression_event", "adImpressionEventType", "ad_impression_event_type", "adImpressionEventName", "ad_impression_event_name",
        "adShowEvent", "ad_show_event", "adShowEventType", "ad_show_event_type", "adShowEventName", "ad_show_event_name",
        "adViewEvent", "ad_view_event", "adViewEventType", "ad_view_event_type", "adViewEventName", "ad_view_event_name",
        "adClickEvent", "ad_click_event", "adClickEventType", "ad_click_event_type", "adClickEventName", "ad_click_event_name",
        "adCloseEvent", "ad_close_event", "adCloseEventType", "ad_close_event_type", "adCloseEventName", "ad_close_event_name",
        "adSkipEvent", "ad_skip_event", "adSkipEventType", "ad_skip_event_type", "adSkipEventName", "ad_skip_event_name",
        "adCompleteEvent", "ad_complete_event", "adCompleteEventType", "ad_complete_event_type", "adCompleteEventName", "ad_complete_event_name",
        "adRewardEvent", "ad_reward_event", "adRewardEventType", "ad_reward_event_type", "adRewardEventName", "ad_reward_event_name",
        "adStartEvent", "ad_start_event", "adStartEventType", "ad_start_event_type", "adStartEventName", "ad_start_event_name",
        "adEndEvent", "ad_end_event", "adEndEventType", "ad_end_event_type", "adEndEventName", "ad_end_event_name",
        "adPlayEvent", "ad_play_event", "adPlayEventType", "ad_play_event_type", "adPlayEventName", "ad_play_event_name",
        "adPauseEvent", "ad_pause_event", "adPauseEventType", "ad_pause_event_type", "adPauseEventName", "ad_pause_event_name",
        "adMuteEvent", "ad_mute_event", "adMuteEventType", "ad_mute_event_type", "adMuteEventName", "ad_mute_event_name",
        "adFullscreenEvent", "ad_fullscreen_event", "adFullscreenEventType", "ad_fullscreen_event_type", "adFullscreenEventName", "ad_fullscreen_event_name",
        // 更多广告价格/积分/预算
        "adAmount", "ad_amount", "adCost", "ad_cost", "adBudget", "ad_budget", "adBid", "ad_bid",
        "adBidPrice", "ad_bid_price", "adBidAmount", "ad_bid_amount", "adCpm", "ad_cpm", "adCpc", "ad_cpc",
        "adCpa", "ad_cpa", "adCtr", "ad_ctr", "adCvr", "ad_cvr", "adRoi", "ad_roi", "adEcpm", "ad_ecpm",
        "adRevenue", "ad_revenue", "adIncome", "ad_income", "adProfit", "ad_profit", "adMargin", "ad_margin",
        "adSpend", "ad_spend", "adExpense", "ad_expense", "adFee", "ad_fee", "adCharge", "ad_charge",
        "adPriceAmount", "ad_price_amount", "adPriceUnit", "ad_price_unit", "adPriceCurrency", "ad_price_currency",
        "adCoinAmount", "ad_coin_amount", "adPointAmount", "ad_point_amount", "adScoreAmount", "ad_score_amount",
        "adRewardAmount", "ad_reward_amount", "adRewardValue", "ad_reward_value", "adRewardType", "ad_reward_type",
        "adRewardName", "ad_reward_name", "adRewardDesc", "ad_reward_desc", "adRewardIcon", "ad_reward_icon",
        "adRewardImage", "ad_reward_image", "adRewardUrl", "ad_reward_url", "adRewardLink", "ad_reward_link",
        // 更多广告跳转链接（通用）
        "adGotoUrl", "ad_goto_url", "adGoto", "ad_goto", "adGotoLink", "ad_goto_link",
        "adOpenUrl", "ad_open_url", "adOpen", "ad_open", "adOpenLink", "ad_open_link",
        "adMoreUrl", "ad_more_url", "adMore", "ad_more", "adMoreLink", "ad_more_link",
        "adDetailUrl", "ad_detail_url", "adDetail", "ad_detail", "adDetailLink", "ad_detail_link",
        "adInfoUrl", "ad_info_url", "adInfoLink", "ad_info_link",
        "adAboutUrl", "ad_about_url", "adAbout", "ad_about", "adAboutLink", "ad_about_link",
        "adClickThroughUrl", "ad_click_through_url", "adClickThrough", "ad_click_through",
        "adClickTargetUrl", "ad_click_target_url", "adClickActionUrl", "ad_click_action_url",
        "adClickDestinationUrl", "ad_click_destination_url", "adClickFinalUrl", "ad_click_final_url",
        "adClickLandingUrl", "ad_click_landing_url", "adClickPageUrl", "ad_click_page_url",
        "adClickWebUrl", "ad_click_web_url", "adClickSiteUrl", "ad_click_site_url",
        "adClickH5Url", "ad_click_h5_url", "adClickSchemeUrl", "ad_click_scheme_url",
        "adClickIntentUrl", "ad_click_intent_url", "adClickDeeplinkUrl", "ad_click_deeplink_url",
        "adClickDeepLinkUrl", "ad_click_deep_link_url", "adClickAppLinkUrl", "ad_click_app_link_url",
        "adClickUniversalLinkUrl", "ad_click_universal_link_url",
        "adClickMiniProgramUrl", "ad_click_mini_program_url", "adClickMiniAppUrl", "ad_click_mini_app_url",
        "adDestination", "ad_destination", "adFinal", "ad_final", "adPage", "ad_page",
        "adWeb", "ad_web", "adSite", "ad_site", "adH5Link", "ad_h5_link",
        "adMiniProgramLink", "ad_mini_program_link", "adMiniAppLink", "ad_mini_app_link",
        "adSchemeLink", "ad_scheme_link", "adIntentLink", "ad_intent_link",
        "adUniversalLinkLink", "ad_universal_link_link", "adAppLinkLink", "ad_app_link_link",
        "adDeepLinkLink", "ad_deep_link_link", "adDeeplinkLink", "ad_deeplink_link",
        // 开屏广告跳转链接
        "splashGotoUrl", "splash_goto_url", "splashGoto", "splash_goto",
        "splashOpenUrl", "splash_open_url", "splashOpen", "splash_open",
        "splashMoreUrl", "splash_more_url", "splashMore", "splash_more",
        "splashDetailUrl", "splash_detail_url", "splashDetail", "splash_detail",
        "splashClickUrl", "splash_click_url", "splashClick", "splash_click",
        "splashActionUrl", "splash_action_url", "splashAction", "splash_action",
        "splashTargetUrl", "splash_target_url", "splashTarget", "splash_target",
        "splashRedirectUrl", "splash_redirect_url", "splashRedirect", "splash_redirect",
        "splashDestinationUrl", "splash_destination_url", "splashFinalUrl", "splash_final_url",
        "splashLandingUrl", "splash_landing_url", "splashPageUrl", "splash_page_url",
        "splashWebUrl", "splash_web_url", "splashH5Url", "splash_h5_url",
        "splashSchemeUrl", "splash_scheme_url", "splashIntentUrl", "splash_intent_url",
        "splashDeeplinkUrl", "splash_deeplink_url", "splashDeepLinkUrl", "splash_deep_link_url",
        "splashAppLinkUrl", "splash_app_link_url", "splashUniversalLinkUrl", "splash_universal_link_url",
        "splashMiniProgramUrl", "splash_mini_program_url", "splashMiniAppUrl", "splash_mini_app_url",
        // 横幅广告跳转链接
        "bannerGotoUrl", "banner_goto_url", "bannerGoto", "banner_goto",
        "bannerOpenUrl", "banner_open_url", "bannerOpen", "banner_open",
        "bannerMoreUrl", "banner_more_url", "bannerMore", "banner_more",
        "bannerDetailUrl", "banner_detail_url", "bannerDetail", "banner_detail",
        "bannerClickUrl", "banner_click_url", "bannerClick", "banner_click",
        "bannerActionUrl", "banner_action_url", "bannerAction", "banner_action",
        "bannerTargetUrl", "banner_target_url", "bannerTarget", "banner_target",
        "bannerRedirectUrl", "banner_redirect_url", "bannerRedirect", "banner_redirect",
        "bannerDestinationUrl", "banner_destination_url", "bannerFinalUrl", "banner_final_url",
        "bannerLandingUrl", "banner_landing_url", "bannerPageUrl", "banner_page_url",
        "bannerWebUrl", "banner_web_url", "bannerH5Url", "banner_h5_url",
        "bannerSchemeUrl", "banner_scheme_url", "bannerIntentUrl", "banner_intent_url",
        "bannerDeeplinkUrl", "banner_deeplink_url", "bannerDeepLinkUrl", "banner_deep_link_url",
        "bannerAppLinkUrl", "banner_app_link_url", "bannerUniversalLinkUrl", "banner_universal_link_url",
        "bannerMiniProgramUrl", "banner_mini_program_url", "bannerMiniAppUrl", "banner_mini_app_url",
        // 弹窗广告跳转链接
        "popupGotoUrl", "popup_goto_url", "popupGoto", "popup_goto",
        "popupOpenUrl", "popup_open_url", "popupOpen", "popup_open",
        "popupMoreUrl", "popup_more_url", "popupMore", "popup_more",
        "popupDetailUrl", "popup_detail_url", "popupDetail", "popup_detail",
        "popupClickUrl", "popup_click_url", "popupClick", "popup_click",
        "popupActionUrl", "popup_action_url", "popupAction", "popup_action",
        "popupTargetUrl", "popup_target_url", "popupTarget", "popup_target",
        "popupRedirectUrl", "popup_redirect_url", "popupRedirect", "popup_redirect",
        "popupDestinationUrl", "popup_destination_url", "popupFinalUrl", "popup_final_url",
        "popupLandingUrl", "popup_landing_url", "popupPageUrl", "popup_page_url",
        "popupWebUrl", "popup_web_url", "popupH5Url", "popup_h5_url",
        "popupSchemeUrl", "popup_scheme_url", "popupIntentUrl", "popup_intent_url",
        "popupDeeplinkUrl", "popup_deeplink_url", "popupDeepLinkUrl", "popup_deep_link_url",
        "popupAppLinkUrl", "popup_app_link_url", "popupUniversalLinkUrl", "popup_universal_link_url",
        "popupMiniProgramUrl", "popup_mini_program_url", "popupMiniAppUrl", "popup_mini_app_url",
        // 悬浮广告跳转链接
        "floatGotoUrl", "float_goto_url", "floatGoto", "float_goto",
        "floatOpenUrl", "float_open_url", "floatOpen", "float_open",
        "floatMoreUrl", "float_more_url", "floatMore", "float_more",
        "floatDetailUrl", "float_detail_url", "floatDetail", "float_detail",
        "floatClickUrl", "float_click_url", "floatClick", "float_click",
        "floatActionUrl", "float_action_url", "floatAction", "float_action",
        "floatTargetUrl", "float_target_url", "floatTarget", "float_target",
        "floatRedirectUrl", "float_redirect_url", "floatRedirect", "float_redirect",
        "floatDestinationUrl", "float_destination_url", "floatFinalUrl", "float_final_url",
        "floatLandingUrl", "float_landing_url", "floatPageUrl", "float_page_url",
        "floatWebUrl", "float_web_url", "floatH5Url", "float_h5_url",
        "floatSchemeUrl", "float_scheme_url", "floatIntentUrl", "float_intent_url",
        "floatDeeplinkUrl", "float_deeplink_url", "floatDeepLinkUrl", "float_deep_link_url",
        "floatAppLinkUrl", "float_app_link_url", "floatUniversalLinkUrl", "float_universal_link_url",
        "floatMiniProgramUrl", "float_mini_program_url", "floatMiniAppUrl", "float_mini_app_url",
        // 原生广告跳转链接
        "nativeGotoUrl", "native_goto_url", "nativeGoto", "native_goto",
        "nativeOpenUrl", "native_open_url", "nativeOpen", "native_open",
        "nativeMoreUrl", "native_more_url", "nativeMore", "native_more",
        "nativeDetailUrl", "native_detail_url", "nativeDetail", "native_detail",
        "nativeClickUrl", "native_click_url", "nativeClick", "native_click",
        "nativeActionUrl", "native_action_url", "nativeAction", "native_action",
        "nativeTargetUrl", "native_target_url", "nativeTarget", "native_target",
        "nativeRedirectUrl", "native_redirect_url", "nativeRedirect", "native_redirect",
        "nativeDestinationUrl", "native_destination_url", "nativeFinalUrl", "native_final_url",
        "nativeLandingUrl", "native_landing_url", "nativePageUrl", "native_page_url",
        "nativeWebUrl", "native_web_url", "nativeH5Url", "native_h5_url",
        "nativeSchemeUrl", "native_scheme_url", "nativeIntentUrl", "native_intent_url",
        "nativeDeeplinkUrl", "native_deeplink_url", "nativeDeepLinkUrl", "native_deep_link_url",
        "nativeAppLinkUrl", "native_app_link_url", "nativeUniversalLinkUrl", "native_universal_link_url",
        "nativeMiniProgramUrl", "native_mini_program_url", "nativeMiniAppUrl", "native_mini_app_url",
        // 激励视频广告跳转链接
        "rewardGotoUrl", "reward_goto_url", "rewardGoto", "reward_goto",
        "rewardOpenUrl", "reward_open_url", "rewardOpen", "reward_open",
        "rewardMoreUrl", "reward_more_url", "rewardMore", "reward_more",
        "rewardDetailUrl", "reward_detail_url", "rewardDetail", "reward_detail",
        "rewardClickUrl", "reward_click_url", "rewardClick", "reward_click",
        "rewardActionUrl", "reward_action_url", "rewardAction", "reward_action",
        "rewardTargetUrl", "reward_target_url", "rewardTarget", "reward_target",
        "rewardRedirectUrl", "reward_redirect_url", "rewardRedirect", "reward_redirect",
        "rewardDestinationUrl", "reward_destination_url", "rewardFinalUrl", "reward_final_url",
        "rewardLandingUrl", "reward_landing_url", "rewardPageUrl", "reward_page_url",
        "rewardWebUrl", "reward_web_url", "rewardH5Url", "reward_h5_url",
        "rewardSchemeUrl", "reward_scheme_url", "rewardIntentUrl", "reward_intent_url",
        "rewardDeeplinkUrl", "reward_deeplink_url", "rewardDeepLinkUrl", "reward_deep_link_url",
        "rewardAppLinkUrl", "reward_app_link_url", "rewardUniversalLinkUrl", "reward_universal_link_url",
        "rewardMiniProgramUrl", "reward_mini_program_url", "rewardMiniAppUrl", "reward_mini_app_url",
        // 插屏广告跳转链接
        "interstitialGotoUrl", "interstitial_goto_url", "interstitialGoto", "interstitial_goto",
        "interstitialOpenUrl", "interstitial_open_url", "interstitialOpen", "interstitial_open",
        "interstitialMoreUrl", "interstitial_more_url", "interstitialMore", "interstitial_more",
        "interstitialDetailUrl", "interstitial_detail_url", "interstitialDetail", "interstitial_detail",
        "interstitialClickUrl", "interstitial_click_url", "interstitialClick", "interstitial_click",
        "interstitialActionUrl", "interstitial_action_url", "interstitialAction", "interstitial_action",
        "interstitialTargetUrl", "interstitial_target_url", "interstitialTarget", "interstitial_target",
        "interstitialRedirectUrl", "interstitial_redirect_url", "interstitialRedirect", "interstitial_redirect",
        "interstitialDestinationUrl", "interstitial_destination_url", "interstitialFinalUrl", "interstitial_final_url",
        "interstitialLandingUrl", "interstitial_landing_url", "interstitialPageUrl", "interstitial_page_url",
        "interstitialWebUrl", "interstitial_web_url", "interstitialH5Url", "interstitial_h5_url",
        "interstitialSchemeUrl", "interstitial_scheme_url", "interstitialIntentUrl", "interstitial_intent_url",
        "interstitialDeeplinkUrl", "interstitial_deeplink_url", "interstitialDeepLinkUrl", "interstitial_deep_link_url",
        "interstitialAppLinkUrl", "interstitial_app_link_url", "interstitialUniversalLinkUrl", "interstitial_universal_link_url",
        "interstitialMiniProgramUrl", "interstitial_mini_program_url", "interstitialMiniAppUrl", "interstitial_mini_app_url"
    ]

    /// 广告数组字段关键词（识别后设为空数组[]）
    private static let 广告数组关键词 = [
        "adList", "ad_list", "adsList", "ads_list", "adArray", "ad_array",
        "adItems", "ad_items", "adDataList", "ad_data_list", "adDataArray", "ad_data_array",
        "adInfoList", "ad_info_list", "adInfoArray", "ad_info_array",
        "adConfigList", "ad_config_list", "adConfigArray", "ad_config_array",
        "bannerList", "banner_list", "bannerArray", "banner_array", "banners",
        "splashList", "splash_list", "splashArray", "splash_array",
        "interstitialList", "interstitial_list", "interstitialArray", "interstitial_array",
        "popupList", "popup_list", "popupArray", "popup_array", "popups",
        "floatList", "float_list", "floatArray", "float_array", "floats",
        "nativeList", "native_list", "nativeArray", "native_array",
        "rewardList", "reward_list", "rewardArray", "reward_array",
        "videoAdList", "video_ad_list", "videoAdArray", "video_ad_array",
        "promotionList", "promotion_list", "promotionArray", "promotion_array", "promotions",
        "advertList", "advert_list", "advertArray", "advert_array", "adverts",
        "sponsorList", "sponsor_list", "sponsorArray", "sponsor_array", "sponsors",
        "pcsliderows", "pcSliderows", "pc_slide_rows", "slideList", "slide_list",
        "slideArray", "slide_array", "slides", "carouselList", "carousel_list",
        "carouselArray", "carousel_array", "carousels",
        "recommendAdList", "recommend_ad_list", "recommendAds", "recommend_ads",
        "hotAdList", "hot_ad_list", "hotAds", "hot_ads",
        "topAdList", "top_ad_list", "topAds", "top_ads",
        "feedAdList", "feed_ad_list", "feedAds", "feed_ads",
        "streamAdList", "stream_ad_list", "streamAds", "stream_ads",
        // 更多按类型分类的广告列表
        "adBannerList", "ad_banner_list", "adBannerArray", "ad_banner_array",
        "adSplashList", "ad_splash_list", "adSplashArray", "ad_splash_array",
        "adInterstitialList", "ad_interstitial_list", "adInterstitialArray", "ad_interstitial_array",
        "adPopupList", "ad_popup_list", "adPopupArray", "ad_popup_array",
        "adFloatList", "ad_float_list", "adFloatArray", "ad_float_array",
        "adNativeList", "ad_native_list", "adNativeArray", "ad_native_array",
        "adRewardList", "ad_reward_list", "adRewardArray", "ad_reward_array",
        "adVideoList", "ad_video_list", "adVideoArray", "ad_video_array",
        "adFeedList", "ad_feed_list", "adFeedArray", "ad_feed_array",
        "adStreamList", "ad_stream_list", "adStreamArray", "ad_stream_array",
        "adTimelineList", "ad_timeline_list", "adTimelineArray", "ad_timeline_array",
        "adPreRollList", "ad_pre_roll_list", "adPreRollArray", "ad_pre_roll_array",
        "adMidRollList", "ad_mid_roll_list", "adMidRollArray", "ad_mid_roll_array",
        "adPostRollList", "ad_post_roll_list", "adPostRollArray", "ad_post_roll_array",
        "adCornerList", "ad_corner_list", "adCornerArray", "ad_corner_array",
        "adBadgeList", "ad_badge_list", "adBadgeArray", "ad_badge_array",
        "adNotificationList", "ad_notification_list", "adNotificationArray", "ad_notification_array",
        "adPushList", "ad_push_list", "adPushArray", "ad_push_array",
        "adRichMediaList", "ad_rich_media_list", "adRichMediaArray", "ad_rich_media_array",
        "adExpandableList", "ad_expandable_list", "adExpandableArray", "ad_expandable_array",
        "adStickyList", "ad_sticky_list", "adStickyArray", "ad_sticky_array",
        "adWallList", "ad_wall_list", "adWallArray", "ad_wall_array",
        "adOfferWallList", "ad_offer_wall_list", "adOfferWallArray", "ad_offer_wall_array",
        "adPlayableList", "ad_playable_list", "adPlayableArray", "ad_playable_array",
        "adInstreamList", "ad_instream_list", "adInstreamArray", "ad_instream_array",
        "adOutstreamList", "ad_outstream_list", "adOutstreamArray", "ad_outstream_array",
        // 更多广告位置/槽位列表
        "adSlotList", "ad_slot_list", "adSlotArray", "ad_slot_array", "slots",
        "adPositionList", "ad_position_list", "adPositionArray", "ad_position_array", "positions",
        "adPlacementList", "ad_placement_list", "adPlacementArray", "ad_placement_array", "placements",
        "adZoneList", "ad_zone_list", "adZoneArray", "ad_zone_array", "zones",
        "adAreaList", "ad_area_list", "adAreaArray", "ad_area_array", "areas",
        "adSpaceList", "ad_space_list", "adSpaceArray", "ad_space_array", "spaces",
        "adLocationList", "ad_location_list", "adLocationArray", "ad_location_array", "locations",
        "adSpotList", "ad_spot_list", "adSpotArray", "ad_spot_array", "spots",
        "adUnitList", "ad_unit_list", "adUnitArray", "ad_unit_array", "units",
        // 更多广告资源列表
        "adImageList", "ad_image_list", "adImageArray", "ad_image_array", "adImages", "ad_images",
        "adPicList", "ad_pic_list", "adPicArray", "ad_pic_array", "adPics", "ad_pics",
        "adImgList", "ad_img_list", "adImgArray", "ad_img_array", "adImgs", "ad_imgs",
        "adUrlList", "ad_url_list", "adUrlArray", "ad_url_array", "adUrls", "ad_urls",
        "adLinkList", "ad_link_list", "adLinkArray", "ad_link_array", "adLinks", "ad_links",
        "adVideoResourceList", "ad_video_resource_list", "adVideoResourceArray", "ad_video_resource_array",
        "adAudioList", "ad_audio_list", "adAudioArray", "ad_audio_array", "adAudios", "ad_audios",
        "adHtmlList", "ad_html_list", "adHtmlArray", "ad_html_array", "adHtmls", "ad_htmls",
        "adCoverList", "ad_cover_list", "adCoverArray", "ad_cover_array", "adCovers", "ad_covers",
        "adThumbnailList", "ad_thumbnail_list", "adThumbnailArray", "ad_thumbnail_array", "adThumbnails", "ad_thumbnails",
        "adIconList", "ad_icon_list", "adIconArray", "ad_icon_array", "adIcons", "ad_icons",
        "adLogoList", "ad_logo_list", "adLogoArray", "ad_logo_array", "adLogos", "ad_logos",
        "adBannerResourceList", "ad_banner_resource_list", "adBannerResourceArray", "ad_banner_resource_array",
        "adSplashResourceList", "ad_splash_resource_list", "adSplashResourceArray", "ad_splash_resource_array",
        "adPopupResourceList", "ad_popup_resource_list", "adPopupResourceArray", "ad_popup_resource_array",
        // 更多轮播/幻灯片列表
        "adCarouselList", "ad_carousel_list", "adCarouselArray", "ad_carousel_array", "adCarousels", "ad_carousels",
        "adSlideList", "ad_slide_list", "adSlideArray", "ad_slide_array", "adSlides", "ad_slides",
        "adBannerCarouselList", "ad_banner_carousel_list", "adBannerCarouselArray", "ad_banner_carousel_array",
        "adBannerSlideList", "ad_banner_slide_list", "adBannerSlideArray", "ad_banner_slide_array",
        "adSplashCarouselList", "ad_splash_carousel_list", "adSplashCarouselArray", "ad_splash_carousel_array",
        "adPopupCarouselList", "ad_popup_carousel_list", "adPopupCarouselArray", "ad_popup_carousel_array",
        // 更多信息流/时间线列表
        "feedList", "feed_list", "feedArray", "feed_array", "feeds",
        "streamList", "stream_list", "streamArray", "stream_array", "streams",
        "timelineList", "timeline_list", "timelineArray", "timeline_array", "timelines",
        "contentList", "content_list", "contentArray", "content_array", "contents",
        "articleList", "article_list", "articleArray", "article_array", "articles",
        "postList", "post_list", "postArray", "post_array", "posts",
        "newsList", "news_list", "newsArray", "news_array", "news",
        "storyList", "story_list", "storyArray", "story_array", "stories",
        "momentList", "moment_list", "momentArray", "moment_array", "moments",
        "dynamicList", "dynamic_list", "dynamicArray", "dynamic_array", "dynamics",
        // 更多推荐/热门/排行榜列表
        "recommendList", "recommend_list", "recommendArray", "recommend_array", "recommends",
        "recommendationList", "recommendation_list", "recommendationArray", "recommendation_array", "recommendations",
        "hotList", "hot_list", "hotArray", "hot_array", "hots",
        "topList", "top_list", "topArray", "top_array", "tops",
        "rankList", "rank_list", "rankArray", "rank_array", "ranks",
        "rankingList", "ranking_list", "rankingArray", "ranking_array", "rankings",
        "leaderboardList", "leaderboard_list", "leaderboardArray", "leaderboard_array", "leaderboards",
        "trendingList", "trending_list", "trendingArray", "trending_array", "trendings",
        "popularList", "popular_list", "popularArray", "popular_array", "populars",
        "featuredList", "featured_list", "featuredArray", "featured_array", "featureds",
        "selectedList", "selected_list", "selectedArray", "selected_array", "selecteds",
        "choiceList", "choice_list", "choiceArray", "choice_array", "choices",
        "editorList", "editor_list", "editorArray", "editor_array", "editors",
        // 更多弹窗/通知/消息列表
        "noticeList", "notice_list", "noticeArray", "notice_array", "notices",
        "notificationList", "notification_list", "notificationArray", "notification_array", "notifications",
        "messageList", "message_list", "messageArray", "message_array", "messages",
        "msgList", "msg_list", "msgArray", "msg_array", "msgs",
        "alertList", "alert_list", "alertArray", "alert_array", "alerts",
        "dialogList", "dialog_list", "dialogArray", "dialog_array", "dialogs",
        "toastList", "toast_list", "toastArray", "toast_array", "toasts",
        "tipList", "tip_list", "tipArray", "tip_array", "tips",
        "guideList", "guide_list", "guideArray", "guide_array", "guides",
        "tutorialList", "tutorial_list", "tutorialArray", "tutorial_array", "tutorials",
        // 更多活动/促销/营销列表
        "activityList", "activity_list", "activityArray", "activity_array", "activities",
        "campaignList", "campaign_list", "campaignArray", "campaign_array", "campaigns",
        "eventList", "event_list", "eventArray", "event_array", "events",
        "promotionList", "promotion_list", "promotionArray", "promotion_array", "promotions",
        "promoList", "promo_list", "promoArray", "promo_array", "promos",
        "saleList", "sale_list", "saleArray", "sale_array", "sales",
        "discountList", "discount_list", "discountArray", "discount_array", "discounts",
        "couponList", "coupon_list", "couponArray", "coupon_array", "coupons",
        "voucherList", "voucher_list", "voucherArray", "voucher_array", "vouchers",
        "giftList", "gift_list", "giftArray", "gift_array", "gifts",
        "prizeList", "prize_list", "prizeArray", "prize_array", "prizes",
        "rewardList", "reward_list", "rewardArray", "reward_array", "rewards",
        "bonusList", "bonus_list", "bonusArray", "bonus_array", "bonuses",
        "lotteryList", "lottery_list", "lotteryArray", "lottery_array", "lotteries",
        "luckyList", "lucky_list", "luckyArray", "lucky_array", "luckies",
        "taskList", "task_list", "taskArray", "task_array", "tasks",
        "missionList", "mission_list", "missionArray", "mission_array", "missions",
        "questList", "quest_list", "questArray", "quest_array", "quests",
        "signList", "sign_list", "signArray", "sign_array", "signs",
        "checkinList", "checkin_list", "checkinArray", "checkin_array", "checkins",
        // 更多品牌/广告主列表
        "brandList", "brand_list", "brandArray", "brand_array", "brands",
        "advertiserList", "advertiser_list", "advertiserArray", "advertiser_array", "advertisers",
        "sponsorList", "sponsor_list", "sponsorArray", "sponsor_array", "sponsors",
        "agencyList", "agency_list", "agencyArray", "agency_array", "agencies",
        "partnerList", "partner_list", "partnerArray", "partner_array", "partners",
        "vendorList", "vendor_list", "vendorArray", "vendor_array", "vendors",
        "providerList", "provider_list", "providerArray", "provider_array", "providers",
        "networkList", "network_list", "networkArray", "network_array", "networks",
        "platformList", "platform_list", "platformArray", "platform_array", "platforms",
        // 更多广告配置/策略列表
        "adConfigList", "ad_config_list", "adConfigArray", "ad_config_array",
        "adStrategyList", "ad_strategy_list", "adStrategyArray", "ad_strategy_array",
        "adRuleList", "ad_rule_list", "adRuleArray", "ad_rule_array",
        "adPolicyList", "ad_policy_list", "adPolicyArray", "ad_policy_array",
        "adPlanList", "ad_plan_list", "adPlanArray", "ad_plan_array",
        "adSchemeList", "ad_scheme_list", "adSchemeArray", "ad_scheme_array",
        "adTemplateList", "ad_template_list", "adTemplateArray", "ad_template_array",
        "adStyleList", "ad_style_list", "adStyleArray", "ad_style_array",
        "adLayoutList", "ad_layout_list", "adLayoutArray", "ad_layout_array",
        "adThemeList", "ad_theme_list", "adThemeArray", "ad_theme_array",
        // 更多广告统计/报表列表
        "adReportList", "ad_report_list", "adReportArray", "ad_report_array",
        "adStatList", "ad_stat_list", "adStatArray", "ad_stat_array",
        "adDataList", "ad_data_list", "adDataArray", "ad_data_array",
        "adInfoList", "ad_info_list", "adInfoArray", "ad_info_array",
        "adRecordList", "ad_record_list", "adRecordArray", "ad_record_array",
        "adLogList", "ad_log_list", "adLogArray", "ad_log_array",
        "adEventList", "ad_event_list", "adEventArray", "ad_event_array",
        "adTrackList", "ad_track_list", "adTrackArray", "ad_track_array",
        "adMonitorList", "ad_monitor_list", "adMonitorArray", "ad_monitor_array"
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
            结果.是否JSON = true
            遍历JSON对象(对象: json对象, 路径前缀: "", 结果: &结果)
        }
        // 尝试从cURL命令中提取JSON
        else if let json子串 = 从文本提取JSON(清洗文本), let json对象 = 解析JSON(json子串) {
            结果.数据格式 = "cURL/文本（含JSON）"
            结果.是否JSON = true
            遍历JSON对象(对象: json对象, 路径前缀: "", 结果: &结果)
        }
        // 纯文本/HTML/JS：搜索广告关键词，用于正则替换式广告屏蔽
        else {
            结果.数据格式 = "纯文本/HTML/JS"
            结果.是否JSON = false
            分析纯文本(文本: 清洗文本, 结果: &结果)
            // 搜索广告关键词在文本中的出现（去重）
            let 所有广告关键词 = 广告标记关键词 + 广告资源关键词 + 广告数组关键词
            var 找到的关键词 = Set<String>()
            for 关键词 in 所有广告关键词 {
                if 清洗文本.localizedCaseInsensitiveContains(关键词) {
                    找到的关键词.insert(关键词)
                }
            }
            结果.文本广告关键词 = Array(找到的关键词).sorted()
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

    /// 广告URL中常见的关键词（域名/路径/参数），用于判断一个URL是否真的是广告链接
    private static let 广告URL关键词 = [
        // 广告平台域名
        "doubleclick", "googleads", "admob", "unityads", "vungle", "chartboost",
        "applovin", "ironsource", "mintegral", "pangle", "bytedance", "tiktok",
        "facebook", "fbcdn", "instagram", "twitter", "snap", "pinterest", "reddit",
        "tumblr", "yahoo", "bing", "baidu", "tencent", "alibaba", "jd", "meituan",
        "didi", "kuaishou", "bilibili", "youku", "iqiyi", "tudou", "mgtv", "qq",
        "weixin", "wechat", "adnxs", "adform", "adcolony", "tapjoy", "fyber",
        "supersonic", "mopub", "millennial", "inmobi", "flurry", "localytics",
        "amplitude", "mixpanel", "adjust", "appsflyer", "kochava", "tune",
        "branch", "onfido", "sentry", "bugly", "umeng", "talkingsata",
        // 广告相关路径
        "/ad/", "/ads/", "/advert/", "/advertisement/", "/banner/", "/splash/",
        "/popup/", "/float/", "/native/", "/reward/", "/interstitial/", "/promotion/",
        "/promo/", "/sponsor/", "/sponsored/", "/creative/", "/campaign/", "/placement/",
        "/slot/", "/zone/", "/area/", "/space/", "/location/", "/spot/", "/unit/",
        "/tag/", "/category/", "/tracking/", "/track/", "/monitor/", "/stat/",
        "/report/", "/log/", "/event/", "/analytics/", "/pixel/", "/beacon/",
        "/impression/", "/expose/", "/click/", "/conversion/", "/download/",
        "/install/", "/open/", "/activate/", "/session/", "/revenue/", "/spend/",
        // 广告相关参数（?后面的参数名）
        "ad_id=", "adid=", "ad_type=", "adtype=", "creative_id=", "creativeid=",
        "campaign_id=", "campaignid=", "placement_id=", "placementid=", "slot_id=", "slotid=",
        "zone_id=", "zoneid=", "area_id=", "areaid=", "space_id=", "spaceid=",
        "location_id=", "locationid=", "spot_id=", "spotid=", "unit_id=", "unitid=",
        "tag_id=", "tagid=", "category_id=", "categoryid=", "advertiser_id=", "advertiserid=",
        "brand_id=", "brandid=", "sponsor_id=", "sponsorid=", "agency_id=", "agencyid=",
        "partner_id=", "partnerid=", "vendor_id=", "vendorid=", "provider_id=", "providerid=",
        "network_id=", "networkid=", "platform_id=", "platformid=", "affiliate_id=", "affiliateid=",
        "pub_id=", "pubid=", "publisher_id=", "publisherid=", "sub_id=", "subid=",
        "source=", "utm_source=", "utm_medium=", "utm_campaign=", "utm_content=", "utm_term=",
        "gclid=", "fbclid=", "msclkid=", "yclid=", "dclid=", "li_fat_id=", "ttclid=",
        "twclid=", "s_cid=", "igshid=", "pinid=", "rdt_cid=", "scid=", "mc_cid=",
        "mc_eid=", "ml_subscriber=", "ml_subscriber_hash=", "vero_id=", "sailthru_id=",
        "klaviyo_id=", "omni_id=", "cmp_id=", "bm_uniq_id=", "ref=", "referrer=",
        "from=", "channel=", "media=", "campaign=", "content=", "term="
    ]

    /// 判断一个值是否是广告URL（必须是字符串、是URL格式、且URL中包含广告相关关键词）
    /// 用于避免误判正常字段（如普通的图片链接、用户头像等）
    private static func 是广告URL(值: Any) -> Bool {
        // 必须是字符串类型
        guard let 字符串值 = 值 as? String else { return false }
        let 小写值 = 字符串值.lowercased()
        // 必须是URL格式（以http://、https://或//开头）
        guard 小写值.hasPrefix("http://") || 小写值.hasPrefix("https://") || 小写值.hasPrefix("//") else {
            return false
        }
        // URL中必须包含广告相关关键词
        return 广告URL关键词.contains { 小写值.contains($0) }
    }

    /// 递归遍历JSON对象，识别会员和广告字段
    private static func 遍历JSON对象(对象: Any, 路径前缀: String, 结果: inout 分析结果) {
        if let 字典 = 对象 as? [String: Any] {
            for (键, 值) in 字典 {
                let 当前路径 = 路径前缀.isEmpty ? 键 : "\(路径前缀).\(键)"
                let 小写键 = 键.lowercased()

                // 检查是否为数组（可能是广告列表）
                if let 数组 = 值 as? [Any], !数组.isEmpty {
                    // 检查数组名是否含广告标记关键词（广告开关/配置列表，可直接识别）
                    if 广告标记关键词.contains(where: { 小写键.contains($0.lowercased()) }) {
                        结果.广告字段.append(识别字段(
                            字段路径: 当前路径,
                            当前值: "[数组(\(数组.count)项)]",
                            类型: .广告数组
                        ))
                    }
                    // 检查数组名是否含广告资源关键词（必须判断数组内容是否真的是广告相关，避免误判）
                    else if 广告资源关键词.contains(where: { 小写键.contains($0.lowercased()) }) {
                        // 判断数组第一项是否是广告URL，或是否包含广告相关字段
                        var 是广告数组 = false
                        if let 第一项 = 数组.first as? String {
                            是广告数组 = 是广告URL(值: 第一项)
                        } else if let 第一项 = 数组.first as? [String: Any] {
                            是广告数组 = 第一项.keys.contains { 键名 in
                                let 小写 = 键名.lowercased()
                                return 广告标记关键词.contains(where: { 小写.contains($0.lowercased()) }) ||
                                       广告资源关键词.contains(where: { 小写.contains($0.lowercased()) })
                            }
                        }
                        if 是广告数组 {
                            结果.广告字段.append(识别字段(
                                字段路径: 当前路径,
                                当前值: "[数组(\(数组.count)项)]",
                                类型: .广告数组
                            ))
                        }
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
                // 检查广告资源字段（必须确认是广告URL才识别，避免误判正常字段导致网页打不开）
                else if 广告资源关键词.contains(where: { 小写键 == $0.lowercased() || 小写键.hasSuffix($0.lowercased()) }) {
                    // 【关键修复】只有当字段值真的是广告URL时才识别为广告字段
                    // 避免把普通的图片链接、用户头像、正常页面链接等误判为广告链接而清空
                    if 是广告URL(值: 值) {
                        let 类型: 识别字段.字段类型 = (小写键.contains("url") || 小写键.contains("link")) ? .广告链接 : .广告图片
                        结果.广告字段.append(识别字段(
                            字段路径: 当前路径,
                            当前值: String(describing: 值),
                            类型: 类型
                        ))
                    }
                }
                // 检查广告数组字段（必须是数组且内容是广告相关才识别，避免误判）
                else if 广告数组关键词.contains(where: { 小写键 == $0.lowercased() || 小写键.hasSuffix($0.lowercased()) }) {
                    if let 数组 = 值 as? [Any], !数组.isEmpty {
                        // 判断数组内容是否真的是广告相关
                        var 是广告数组 = false
                        if let 第一项 = 数组.first as? String {
                            是广告数组 = 是广告URL(值: 第一项)
                        } else if let 第一项 = 数组.first as? [String: Any] {
                            是广告数组 = 第一项.keys.contains { 键名 in
                                let 小写 = 键名.lowercased()
                                return 广告标记关键词.contains(where: { 小写.contains($0.lowercased()) }) ||
                                       广告资源关键词.contains(where: { 小写.contains($0.lowercased()) })
                            }
                        } else {
                            // 数组第一项不是字符串也不是字典，可能是基本类型数组，根据字段名判断
                            是广告数组 = true
                        }
                        if 是广告数组 {
                            结果.广告字段.append(识别字段(
                                字段路径: 当前路径,
                                当前值: String(describing: 值),
                                类型: .广告数组
                            ))
                        }
                    }
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

        // 直接修改字段代码块（按用户指定格式：分段注释+每字段详细log）
        var 修改代码块 = ""

        // ====== 确认对象存在（统一初始化父级路径） ======
        修改代码块 += "    // ====== 确认对象存在 ======\n"
        修改代码块 += 初始化代码

        // ====== 修改基础信息（会员+用户信息，每个字段后加详细log） ======
        let 有基础信息 = !结果.会员字段.isEmpty ||
                        !结果.用户核心字段.filter({ $0.类型 != .用户ID && $0.类型 != .登录Token }).isEmpty
        if 有基础信息 {
            修改代码块 += "    // ====== 修改基础信息 ======\n"

            // 会员状态修改
            let 会员状态字段 = 结果.会员字段.filter { $0.类型 == .会员状态 }
            for 字段 in 会员状态字段 {
                let 字段名 = 字段.字段路径.components(separatedBy: ".").last ?? 字段.字段路径
                修改代码块 += "    body.\(字段.字段路径) = 1;\n"
                修改代码块 += "    console.log(\"✅ 已成功设置会员状态：\(字段名) = 1\");\n"
            }

            // 会员到期时间修改
            let 会员到期字段 = 结果.会员字段.filter { $0.类型 == .会员到期时间 }
            for 字段 in 会员到期字段 {
                let 字段名 = 字段.字段路径.components(separatedBy: ".").last ?? 字段.字段路径
                let 是否时间戳 = Double(字段.当前值) != nil && (Double(字段.当前值) ?? 0) > 1000000000
                let 永久值 = 是否时间戳 ? "4070908800" : "\"2099-12-31 23:59:59\""
                修改代码块 += "    body.\(字段.字段路径) = \(永久值);\n"
                修改代码块 += "    console.log(\"✅ 已成功设置会员到期：\(字段名) = \(永久值)\");\n"
            }

            // 会员等级修改
            let 会员等级字段 = 结果.会员字段.filter { $0.类型 == .会员等级 }
            for 字段 in 会员等级字段 {
                let 字段名 = 字段.字段路径.components(separatedBy: ".").last ?? 字段.字段路径
                let 是否数字 = Int(字段.当前值) != nil
                let 最高值 = 是否数字 ? "6" : "\"VIP6\""
                修改代码块 += "    body.\(字段.字段路径) = \(最高值);\n"
                修改代码块 += "    console.log(\"✅ 已成功设置会员等级：\(字段名) = \(最高值)\");\n"
            }

            // 用户昵称修改
            let 用户名字段 = 结果.用户核心字段.filter { $0.类型 == .用户名 }
            for 字段 in 用户名字段 {
                let 字段名 = 字段.字段路径.components(separatedBy: ".").last ?? 字段.字段路径
                修改代码块 += "    body.\(字段.字段路径) = \"新昵称\";\n"
                修改代码块 += "    console.log(\"✅ 已成功修改昵称：\(字段名) = 新昵称\");\n"
            }

            // 积分余额修改
            let 积分字段 = 结果.用户核心字段.filter { $0.类型 == .积分余额 }
            for 字段 in 积分字段 {
                let 字段名 = 字段.字段路径.components(separatedBy: ".").last ?? 字段.字段路径
                let 是否数字 = Double(字段.当前值) != nil
                let 新值 = 是否数字 ? "999999" : "\"999999\""
                修改代码块 += "    body.\(字段.字段路径) = \(新值);\n"
                修改代码块 += "    console.log(\"✅ 已成功设置积分余额：\(字段名) = \(新值)\");\n"
            }

            // 手机号掩码
            let 手机号字段 = 结果.用户核心字段.filter { $0.类型 == .手机号 }
            for 字段 in 手机号字段 {
                let 字段名 = 字段.字段路径.components(separatedBy: ".").last ?? 字段.字段路径
                修改代码块 += "    body.\(字段.字段路径) = String(body.\(字段.字段路径) || \"\").replace(/(\\d{3})\\d{4}(\\d{4})/, \"$1****$2\");\n"
                修改代码块 += "    console.log(\"✅ 已成功掩码手机号：\(字段名)\");\n"
            }

            // 邮箱掩码
            let 邮箱字段 = 结果.用户核心字段.filter { $0.类型 == .邮箱 }
            for 字段 in 邮箱字段 {
                let 字段名 = 字段.字段路径.components(separatedBy: ".").last ?? 字段.字段路径
                修改代码块 += "    { let _e = String(body.\(字段.字段路径) || \"\"); let _at = _e.indexOf(\"@\"); if (_at > 2) { body.\(字段.字段路径) = _e.substring(0, 2) + \"****\" + _e.substring(_at); } }\n"
                修改代码块 += "    console.log(\"✅ 已成功掩码邮箱：\(字段名)\");\n"
            }

            // 头像修改
            let 头像字段列表 = 结果.用户核心字段.filter { $0.类型 == .头像 }
            for 字段 in 头像字段列表 {
                let 字段名 = 字段.字段路径.components(separatedBy: ".").last ?? 字段.字段路径
                修改代码块 += "    body.\(字段.字段路径) = \"https://default-avatar.com/default.png\";\n"
                修改代码块 += "    console.log(\"✅ 已成功设置头像：\(字段名)\");\n"
            }

            // 性别修改
            let 性别字段列表 = 结果.用户核心字段.filter { $0.类型 == .性别 }
            for 字段 in 性别字段列表 {
                let 字段名 = 字段.字段路径.components(separatedBy: ".").last ?? 字段.字段路径
                let 是否数字 = Int(字段.当前值) != nil
                let 性别值 = 是否数字 ? "1" : "\"男\""
                修改代码块 += "    body.\(字段.字段路径) = \(性别值);\n"
                修改代码块 += "    console.log(\"✅ 已成功设置性别：\(字段名) = \(性别值)\");\n"
            }

            // 生日修改
            let 生日字段列表 = 结果.用户核心字段.filter { $0.类型 == .生日 }
            for 字段 in 生日字段列表 {
                let 字段名 = 字段.字段路径.components(separatedBy: ".").last ?? 字段.字段路径
                let 是否时间戳 = Double(字段.当前值) != nil && (Double(字段.当前值) ?? 0) > 1000000000
                let 生日值 = 是否时间戳 ? "946684800" : "\"2000-01-01\""
                修改代码块 += "    body.\(字段.字段路径) = \(生日值);\n"
                修改代码块 += "    console.log(\"✅ 已成功设置生日：\(字段名) = \(生日值)\");\n"
            }
        }

        // ====== 广告清除（globalData/appver置空+普通字段删除+数组过滤，每个操作后加log） ======
        let 广告标记字段 = 结果.广告字段.filter { $0.类型 == .广告标记 || $0.类型 == .广告链接 || $0.类型 == .广告图片 }
        let 特殊置空字段 = 广告标记字段.filter { 字段 in
            let 小写路径 = 字段.字段路径.lowercased()
            return 小写路径.hasSuffix("globaldata") || 小写路径.hasSuffix("appver")
        }
        let 普通删除字段 = 广告标记字段.filter { 字段 in
            let 小写路径 = 字段.字段路径.lowercased()
            return !小写路径.hasSuffix("globaldata") && !小写路径.hasSuffix("appver")
        }
        let 广告数组字段 = 结果.广告字段.filter { $0.类型 == .广告数组 }

        if !特殊置空字段.isEmpty || !普通删除字段.isEmpty || !广告数组字段.isEmpty {
            修改代码块 += "    // ====== 广告清除 ======\n"

            // globalData/appver置空（用if判断包裹）
            for 字段 in 特殊置空字段 {
                let 字段名 = 字段.字段路径.components(separatedBy: ".").last ?? 字段.字段路径
                修改代码块 += "    if (body.\(字段.字段路径) !== undefined) {\n"
                修改代码块 += "        body.\(字段.字段路径) = {};\n"
                修改代码块 += "        console.log(\"✅ 已成功清除 \(字段名)\");\n"
                修改代码块 += "    }\n"
            }

            // 普通广告字段递归删除
            if !普通删除字段.isEmpty {
                let 字段列表文本 = 普通删除字段.map { "\"\($0.字段路径)\"" }.joined(separator: ", ")
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
                修改代码块 += "    console.log(\"✅ 已成功删除 \(普通删除字段.count) 个广告字段\");\n"
            }

            // 广告数组过滤
            if !广告数组字段.isEmpty {
                修改代码块 += "    function 是否为广告项(项) {\n"
                修改代码块 += "        if (!项 || typeof 项 !== \"object\") return false;\n"
                修改代码块 += "        return 项.isAd === true || 项.is_ad === true || 项.hasAd === true\n"
                修改代码块 += "            || 项.ad !== undefined || 项.ad_id !== undefined\n"
                修改代码块 += "            || 项.type === \"ad\" || 项.type === \"advert\";\n"
                修改代码块 += "    }\n"
                for 字段 in 广告数组字段 {
                    let 父级路径 = 字段.字段路径.components(separatedBy: ".").dropLast().joined(separator: ".")
                    let 数组名 = 字段.字段路径.components(separatedBy: ".").last ?? 字段.字段路径
                    if 父级路径.isEmpty {
                        修改代码块 += "    if (Array.isArray(body.\(数组名))) { body.\(数组名) = body.\(数组名).filter(function(项) { try { return !是否为广告项(项); } catch (e) { return true; } }); console.log(\"✅ 已成功过滤广告数组：\(数组名)\"); }\n"
                    } else {
                        修改代码块 += "    if (body.\(父级路径) && Array.isArray(body.\(父级路径).\(数组名))) { body.\(父级路径).\(数组名) = body.\(父级路径).\(数组名).filter(function(项) { try { return !是否为广告项(项); } catch (e) { return true; } }); console.log(\"✅ 已成功过滤广告数组：\(字段.字段路径)\"); }\n"
                    }
                }
            }
        }

        // ====== 敏感信息（已识别，保留原始值不修改，仅注释说明） ======
        let 用户ID字段列表 = 结果.用户核心字段.filter { $0.类型 == .用户ID }
        let Token字段列表 = 结果.用户核心字段.filter { $0.类型 == .登录Token }
        if !用户ID字段列表.isEmpty || !Token字段列表.isEmpty {
            修改代码块 += "    // ====== 敏感信息（已识别，保留原始值不修改） ======\n"
            for 字段 in 用户ID字段列表 {
                修改代码块 += "    // 已识别用户ID字段：\(字段.字段路径)（当前值：\(字段.当前值)），保留原始值\n"
            }
            for 字段 in Token字段列表 {
                修改代码块 += "    // 已识别登录Token字段：\(字段.字段路径)，保留原始值（修改可能导致登录失效）\n"
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
\(修改代码块)
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
