# 圈X脚本编辑器 iOS

> 最低支持 **iOS 14.0** | 纯原生 Swift + SwiftUI | XcodeGen 构建
> ⚠️ 本工具仅为本地JS文本编辑器与沙箱预调试工具，**不执行真实圈X脚本、不提供代理能力**。脚本需导出后在 QuantumX 客户端内加载运行。沙箱环境不等于圈X真实运行环境，仅用于本地预调试。

## 功能清单

### 核心编辑
- 本地 `.js` 脚本管理：新建、重命名、删除、保存
- 带行号代码编辑器，底层 UITextView 保证 iOS14 输入体验
- 圈X JS 语法高亮：注释、字符串、JS关键字、圈X内置对象分色显示
- 字体大小调节（10-24pt）
- 文件 App 共享，可直接导入导出 `.js` 脚本

### 新手友好
- **新手代码键盘**：自定义代码键盘替代系统键盘，5大页面（英文26键/符号/关键字/圈X/片段），英文页标准QWERTY布局支持Shift大小写切换，含Tab/空格/删除/换行功能键，一键切换系统键盘，补全栏右侧切换按钮随时切换
- **代码补全**：80+ 补全项，覆盖圈X全量API与常用JS片段（加密编码/日期时间/字符串处理/正则匹配/数学运算/JSON处理等12大分类），输入 `$` 自动唤起候选条（键盘上方），也可手动打开补全弹窗搜索
- **脚本模板库**：15+ 内置模板，按6大分类（请求修改/响应处理/网络请求/存储通知/工具函数），全部附带中文注释、用途说明、使用场景
- **静态检查**：检测缺少 `$done()`、括号不匹配、异步回调遗漏 `$done`、引号未配对、残留 `console.log`，每项附带中文修复建议
- **代码格式化**：一键按大括号层级自动调整缩进（4空格）

### 应用更新
- **自动检测更新**：App启动时每日自动检测GitHub最新Release，有新版本时弹窗提示
- **手动检测更新**：列表页左上角按钮可随时手动检测更新
- **更新弹窗**：展示版本号对比、发布说明、发布时间，支持一键下载更新、查看更新详情、忽略此版本
- **App内下载IPA**：点击下载更新后App内直接下载IPA，实时显示下载进度条，下载失败可重试
- **下载完成弹出系统分享面板**：IPA下载完成后自动弹出iOS系统分享面板，可通过AltStore/TrollStore/文件等方式侧载安装
- **CI/CD自动发布**：每次推送master分支，GitHub Actions自动构建并发布Release

### JS沙箱测试
- 自定义测试URL，支持任意网址
- URL历史记录与收藏管理：收藏切换、单条删除、一键清空历史（收藏保留）
- 自定义请求头编辑（key:value 一行一个）
- 多套测试环境保存与快速切换
- 模拟圈X内置对象：`$request` / `$response` / `$notify` / `$persistentStore` / `$httpClient.get/post` / `$done`
- `$httpClient` 发起真实网络请求，回调构造 `$response` 对象
- JS执行超时保护（8秒），防止死循环卡死

## 技术架构

```
Sources/
├── App/           应用入口
├── Model/         数据模型（脚本/网址/测试环境/补全项/常量）
├── Store/         本地持久化（脚本文件存储/网址UserDefaults/环境UserDefaults）
├── ViewModel/     页面状态管理（列表/编辑器/测试面板）
├── Service/       业务逻辑（语法高亮/静态检查/JS沙箱/代码补全/格式化）
├── View/          SwiftUI视图（列表/编辑器/弹窗/测试面板）
└── Template/      圈X脚本模板库
```

- 架构模式：MVVM
- 数据存储：脚本文件存于 App 文档目录 `QuantumXScripts/`；网址与环境存于 UserDefaults
- 无第三方依赖，纯原生框架（Foundation / SwiftUI / UIKit / JavaScriptCore）

## 构建方式

使用 XcodeGen 生成 Xcode 项目：

```bash
brew install xcodegen
xcodegen generate
open 圈X脚本编辑器.xcodeproj
```

- Xcode 版本：15.4+
- 最低部署目标：iOS 14.0
- CI/CD：GitHub Actions 自动构建未签名 IPA

## 版本历史

### v1.5.5
- 继续修复Share Extension共享扩展未出现在iOS共享菜单的问题：
  - 将NSExtensionActivationRule从字典格式改为谓词格式（SUBQUERY），明确指定支持public.file-url、public.plain-text、public.source-code、public.data四种UTI类型，确保系统能准确判断我们的扩展可以处理.js文件
  - 谓词格式比字典格式更精确，可以控制哪些类型的共享内容会触发我们的扩展显示
  - 涉及文件：Sources/共享扩展/Info.plist

### v1.5.4
- 修复Share Extension共享扩展未出现在iOS共享菜单的问题（找到两个根本原因）：
  - 【根本原因1】dependencies方向反了。之前是共享扩展依赖主App，正确应该是主App依赖共享扩展，这样Xcode才会自动将共享扩展嵌入到App包的PlugIns目录中。已修改：主App添加dependencies: [target: 共享扩展]，移除共享扩展的dependencies
  - 【根本原因2】共享扩展视图控制器没有使用标准基类。之前继承自UIViewController，已改为继承自SLComposeServiceViewController（iOS标准分享扩展视图控制器），并添加@objc(共享扩展视图控制器)标记确保NSExtensionPrincipalClass能正确找到类
  - 【界面优化】共享扩展使用标准分享界面，显示文件名、字符数、内容预览，右上角按钮改为"导入"，点击后通过剪贴板和quantumx URL Scheme传递文件内容给主App
  - 涉及文件：Sources/共享扩展/共享扩展视图控制器.swift、Project.yml

### v1.5.3
- 新增Share Extension（共享扩展），彻底解决App未出现在iOS共享菜单的问题：
  - 【根本原因】CFBundleDocumentTypes方式对侧载/巨魔商店安装的App经常无效，因为系统LaunchServices无法正确注册UTI。Share Extension是独立的扩展target，会出现在共享面板中间一行的活动图标中，不依赖UTI注册
  - 【新增共享扩展target】在Project.yml中添加"共享扩展"app-extension target，bundleId为com.quantumx.editor.share，依赖主App
  - 【共享扩展功能】用户在其他App中分享.js/.txt文件时，共享面板中间一行会显示"导入到圈X脚本编辑器"图标，点击后自动读取文件内容，通过剪贴板传递给主App，然后打开主App创建新脚本
  - 【URL Scheme】主App新增quantumx:// URL Scheme，共享扩展通过quantumx://import?name=文件名打开主App，主App解析URL后读取剪贴板内容创建脚本，完成后自动清除剪贴板保护隐私
  - 【支持格式】共享扩展支持.js/.mjs/.cjs/.txt文件，以及纯文本内容，支持UTF-8/GBK/ASCII多编码读取
  - 【涉及文件】Sources/共享扩展/Info.plist、Sources/共享扩展/共享扩展视图控制器.swift、Sources/App/圈X脚本编辑器App.swift、Info.plist、Project.yml

### v1.5.2
- 彻底修复App未出现在iOS共享菜单的问题（找到两个根本原因）：
  - 【根本原因1】Project.yml中的LSSupportsOpeningDocumentsInPlace: true会覆盖Info.plist中的设置，导致Info.plist改了也没用。已同步将Project.yml中改为false
  - 【根本原因2】Bundle Identifier包含中文字符（com.quantumx.editor.圈X脚本编辑器），因为XcodeGen默认用bundleIdPrefix+target name生成，而target name是中文。包含非ASCII字符的Bundle Identifier可能导致UTI注册失败。已给target显式设置bundleId: com.quantumx.editor（纯ASCII）
  - 【配置简化】移除自定义UTI（com.quantumx.javascript-source）和UTExportedTypeDeclarations，只使用系统标准UTI（public.source-code/public.plain-text/public.data），确保系统能识别
  - 【扩展支持】CFBundleTypeExtensions添加txt扩展名，增加出现在共享菜单的概率
  - 涉及文件：Info.plist、Project.yml

### v1.5.1
- 继续修复App未出现在iOS共享菜单/打开方式列表中的问题：
  - 【修改1】LSSupportsOpeningDocumentsInPlace从true改为false，确保App在共享菜单中显示为"拷贝到圈X脚本编辑器"而非"打开方式"
  - 【修改2】LSItemContentTypes中同时添加public.source-code和public.plain-text系统标准UTI，确保系统能识别我们App支持源码/文本文件，提高出现在共享菜单的概率
  - 【重要提示】iOS系统会缓存App的UTI声明，直接覆盖安装可能不会刷新。必须先卸载旧版App，再重新安装新版，才能在共享菜单中看到我们App
  - 涉及文件：Info.plist

### v1.5.0
- 修复App未出现在iOS共享菜单/打开方式列表中的问题：
  - 【根本原因】之前使用UTImportedTypeDeclarations（导入类型声明）+ com.netscape.javascript-source UTI，导入类型声明只适用于系统已内置但未完全识别的类型，而com.netscape.javascript-source不是iOS系统内置UTI，导致系统无法正确关联.js文件与我们App
  - 【修复方案1】改用UTExportedTypeDeclarations（导出类型声明），作为Owner主动导出自定义UTI（com.quantumx.javascript-source），系统安装App后会注册这个UTI并关联.js/.mjs/.cjs扩展名
  - 【修复方案2】CFBundleDocumentTypes的LSItemContentTypes只保留自定义UTI（com.quantumx.javascript-source），与UTExportedTypeDeclarations中的UTTypeIdentifier完全一致
  - 【修复方案3】文档选择器中的documentTypes同步更新为自定义UTI
  - 【效果】安装App后，系统会在"打开方式"和"共享"菜单的"拷贝到..."列表中显示我们App，LSHandlerRank=Owner确保优先显示
  - 涉及文件：Info.plist、脚本列表页.swift

### v1.4.9
- 新增App内导入.js文件功能，解决系统默认打开方式跳转到其他App的问题：
  - 【问题原因】iOS系统会记住用户上次选择的默认打开方式，如果之前选过用其他App（如全能签）打开.js文件，之后每次都会默认用那个App打开，即使我们的App声明了Owner优先级
  - 【解决方案】在脚本列表页导航栏新增"导入文件"按钮（文件夹+加号图标），点击后弹出系统文档选择器，直接从App内选择.js文件导入，完全绕过系统默认打开方式
  - 【文档选择器】使用UIDocumentPickerViewController封装，只允许选择JavaScript源码文件（UTI: com.netscape.javascript-source/public.javascript-source/public.source-code/public.plain-text），支持单选
  - 【文件读取】支持UTF-8/GBK/ASCII多种编码自动尝试读取，安全范围资源访问
  - 【自动导入】选择文件后自动创建新脚本并导航到编辑器，显示导入成功提示
  - 【格式校验】仅支持.js/.mjs/.cjs格式文件，其他格式提示错误
  - 涉及文件：脚本列表页.swift

### v1.4.8
- 新增支持通过系统"打开方式"优先使用本App打开.js文件：
  - 【Info.plist配置】添加CFBundleDocumentTypes声明App能够编辑JavaScript文件，LSHandlerRank设置为Owner让App在打开方式列表中优先显示
  - 【支持格式】支持.js/.mjs/.cjs三种扩展名，同时声明com.netscape.javascript-source、public.javascript-source、public.source-code三个UTI
  - 【UTI导入声明】添加UTImportedTypeDeclarations确保系统正确识别.js文件扩展名和MIME类型
  - 【文件读取】App入口添加.onOpenURL处理，支持安全范围资源访问，自动尝试UTF-8/GBK/ASCII多种编码读取文件内容
  - 【自动导入】读取文件后通过NotificationCenter发送通知，脚本列表页监听通知后自动创建新脚本并导航到编辑器
  - 【编程式导航】NavigationLink改为tag+selection绑定，外部文件导入后自动打开编辑器
  - 【视图模型扩展】新增从外部文件创建脚本方法，支持带内容创建
  - 涉及文件：Info.plist、圈X脚本编辑器App.swift、脚本列表页.swift、脚本列表视图模型.swift

### v1.4.7
- 彻底修复测试输出区域无限放大导致测试面板超出屏幕的bug：
  - 【根本原因】v1.4.6仅通过UITextView自身高度约束限制高度，但SwiftUI中UIViewRepresentable的布局由intrinsicContentSize决定，UITextView的intrinsicContentSize不受自身高度约束限制，导致内容过多时intrinsicContentSize无限大，SwiftUI布局被撑大
  - 【修复方案1】创建受限高度UITextView子类`受限高度文本视图`，重写intrinsicContentSize属性，返回受最大高度（屏幕高度40%）限制的高度，从根源上防止SwiftUI布局无限放大
  - 【修复方案2】内容变化时调用invalidateIntrinsicContentSize()通知SwiftUI重新计算布局
  - 【修复方案3】SwiftUI层面添加frame(maxHeight:屏幕高度40%)双重保险
  - 【动态滚动模式】内容高度≤最大高度时禁用内部滚动跟随外部ScrollView，内容高度>最大高度时启用内部滚动固定最大高度
  - 涉及文件：脚本测试面板.swift

### v1.4.6
- 修复测试输出区域内容过多时超出屏幕显示的bug：
  - 【根本原因】v1.4.4将彩色输出视图改为UITextView禁用内部滚动+高度自适应后，没有设置最大高度限制，当输出内容很多（如几万字符响应体）时，UITextView高度会非常大，导致整个测试面板超出屏幕
  - 【修复方案】添加最大高度限制（屏幕高度的45%），根据内容高度动态切换滚动模式：
    - 内容高度≤最大高度：禁用内部滚动，高度自适应，跟随外部ScrollView一起滑动
    - 内容高度>最大高度：启用内部滚动，固定最大高度，防止超出屏幕
  - 【自动滚动适配】根据当前滚动模式选择不同的自动滚动方式：内部滚动模式用scrollRangeToVisible，外部滚动模式用选中末尾触发外部滚动
  - 【代码优化】提取更新高度约束为独立方法，避免重复代码
  - 涉及文件：脚本测试面板.swift

### v1.4.5
- 智能分析综合模板按照用户指定格式全面重写：
  - 【分段注释】新增"确认对象存在"、"修改基础信息"、"广告清除"、"敏感信息"四个分段注释
  - 【每字段详细log】每个字段修改后都增加console.log("✅ 已成功设置...")，包含字段名和新值
  - 【会员状态/到期/等级】每个字段修改后单独打印log
  - 【用户基础信息】昵称、积分、手机号掩码、邮箱掩码、头像、性别、生日每个字段修改后单独打印log
  - 【广告清除】globalData/appver置空用if(字段!==undefined)判断包裹，每个字段清除后打印log；普通广告字段删除后打印总数；广告数组过滤后打印log
  - 【敏感信息】用户ID和登录Token仅注释说明，保留原始值
  - 【日志编号】[1]触发→[1.1]响应存在→[2]Body长度→[2.1]前100字符→[2.2]确认JSON→[3]函数开始→[4]函数结束→[5]JSON解析成功→[6]脚本执行成功
  - 涉及文件：智能分析服务.swift

### v1.4.4
- 修复测试输出区域独立滚动问题，改为跟随全局ScrollView一起滑动：
  - 【问题】v1.4.3将彩色输出视图改为UITextView后，isScrollEnabled=true导致UITextView成为独立滚动区域，用户滑动时输出区域自己滚动，不能和测试面板其他内容一起滑动
  - 【修复】设置isScrollEnabled=false禁用UITextView内部滚动，通过sizeThatFits计算内容高度并更新高度约束，让UITextView完整显示所有内容，高度自适应后自然跟随外部ScrollView一起滑动
  - 【自动滚动】禁用内部滚动后，自动滚动到底部改为通过选中末尾文本触发外部ScrollView自动滚动到可见区域，0.3秒后自动清除选中避免视觉干扰
  - 【保留功能】文本可选择复制、彩色显示、自动换行开关、空态提示全部保留
  - 涉及文件：脚本测试面板.swift

### v1.4.3
- 脚本测试面板输出区域开启文本选择功能：
  - 【根本原因】原彩色输出视图使用SwiftUI的ScrollView+Text实现，Text在iOS14上不可选择，用户无法长按选中复制输出内容
  - 【修复方案】将彩色输出视图重写为UITextView封装（UIViewRepresentable），isEditable=false+isSelectable=true，用户可长按选中任意文本进行复制
  - 【保留功能】彩色文本显示（NSAttributedString按日志级别着色）、自动滚动到底部、自动换行开关、空态提示全部保留
  - 【iOS14兼容】UITextView是UIKit基础控件，iOS14完全支持，不依赖SwiftUI的textSelection修饰符（iOS15+才有）
  - 涉及文件：脚本测试面板.swift

### v1.4.2
- 修复综合模板字段覆盖不全问题：
  - 【根本原因】综合模板只处理了会员状态/到期时间/等级、广告标记/链接/图片、用户名、积分余额、手机号、邮箱，遗漏了广告数组、用户ID、头像、登录Token、性别、生日共6种字段类型
  - 【新增广告数组过滤】识别到广告数组时，生成是否为广告项判断函数，过滤数组中的广告项（支持isAd/is_ad/hasAd/ad/ad_id/type=ad等多种标记）
  - 【新增用户ID识别】识别到用户ID字段时，模板中注释说明已识别，敏感信息保留原始值不修改
  - 【新增头像修改】识别到头像字段时，设为默认头像URL
  - 【新增登录Token识别】识别到登录Token字段时，模板中注释说明已识别，敏感信息保留原始值（修改可能导致登录失效）
  - 【新增性别修改】识别到性别字段时，设为1=男（数字型）或"男"（字符串型）
  - 【新增生日修改】识别到生日字段时，设为默认日期2000-01-01（时间戳型设为946684800）
  - 涉及文件：智能分析服务.swift

### v1.4.1
- 智能分析新增globalData、appver广告配置识别：
  - 【新增识别关键词】广告标记关键词列表新增globalData、appver，智能分析时自动识别这两个全局广告配置/应用版本配置字段
  - 【特殊处理】识别到globalData或appver时，模板中不删除字段而是设为{}空对象（清空广告配置），其他广告字段仍然递归删除
  - 【综合模板】综合模板中分离特殊置空字段和普通删除字段，分别生成对应代码
  - 【单字段模板】去广告字段模板也支持globalData/appver特殊处理
  - 涉及文件：智能分析服务.swift

### v1.4.0
- 修复代码编辑器输入时屏幕乱跳bug：
  - 【根本原因】textViewDidChange中每次输入都重新设置attributedText导致UITextView重新布局，同时SwiftUI绑定触发updateUIView二次刷新，两者共同造成滚动位置跳动
  - 【修复1】textViewDidChange中保存当前contentOffset，重新设置attributedText后恢复，确保滚动位置不变
  - 【修复2】新增正在编辑标志位，编辑过程中（textViewDidBeginEditing到textViewDidEndEditing）跳过updateUIView中的外部文本同步，防止二次刷新
  - 【修复3】textViewDidChange结束后异步重置标志位，确保当前runloop完成后才允许外部同步
  - 涉及文件：带行号编辑器.swift

### v1.3.9
- 智能分析模板优化与字段名统一：
  - 【智能分析综合模板重写】置顶的"全部导入"综合模板改为IIFE包裹+function封装+每一步详细log（$response确认、Body长度+前100字符预览、JSON确认、函数入口/出口、顶层字段列表），与内置代码模板风格统一
  - 【智能分析通用模板重写】未识别到字段时的通用模板也改为IIFE+function+详细log风格，示例字段名使用小写isvip
  - 【isvip小写统一】内置代码模板中会员状态示例字段名从isVip改为小写isvip，与圈X实战脚本风格一致
  - 涉及文件：圈X代码模板.swift、智能分析服务.swift

### v1.3.8
- 模板优化与静态检查调整：
  - 【模板增加function封装】核心模板（修改响应JSON字段、去广告删除JSON字段）的修改逻辑封装为独立function，代码结构更清晰，便于新手理解和复用
  - 【每一步详细log】模板中每个关键步骤都增加console.log输出：$response存在确认、Body长度+前100字符预览、JSON响应确认、function入口/出口日志、每个字段修改明细、顶层字段列表等，方便调试时追踪脚本执行流程
  - 【移除console.log静态检查警告】删除语法检查中"检测到console.log调试输出"的提示项，console.log是圈X标准调试写法，不应作为警告提示
  - 涉及文件：圈X代码模板.swift、脚本静态检查服务.swift

### v1.3.7
- 所有代码模板完全对齐用户提供的圈X实战规范脚本：
  - 【统一$done调用】所有响应处理类模板中原样放行的`$done()`统一改为`$done({})`，与用户提供的规范脚本完全一致（共41处）
  - 【规范流程确认】所有响应处理类模板已严格遵循圈X实战五步法：IIFE包裹→$response存在性检查→响应体空值检查→Content-Type/首字符判断非JSON放行→try-catch→JSON.parse→修改字段→JSON.stringify→$done({body:...})→catch中$done({})原样放行
  - 涉及文件：圈X代码模板.swift

### v1.3.6
- 修复沙箱JSON解析失败"Unterminated string"根本原因：
  - 【根本原因】`请求真实响应体`方法中调用`解码JSON转义`对原始响应体进行解码，将JSON中的`\"`解码成`"`、`\n`解码成实际换行符、`\\`解码成`\`，破坏了JSON结构，导致脚本中`JSON.parse()`报"Unterminated string"错误
  - 【修复方案】响应体保持原始JSON格式传给脚本执行，`解码JSON转义`仅用于显示预览（让用户看到中文），不影响脚本执行；缓存的也是原始响应体
  - 涉及文件：脚本测试视图模型.swift

### v1.3.5
- 修复更新窗口异常超出屏幕 + APP前台进入立即检查更新：
  - 【修复窗口超出屏幕】根本原因是富文本视图isScrollEnabled=false导致在ScrollView中高度计算异常，内容过多时弹窗无限增高超出屏幕。修复方案：富文本视图新增可滚动参数，更新弹窗中改为内部滚动（isScrollEnabled=true），去掉外层ScrollView；弹窗整体限制最大高度为屏幕高度85%
  - 【新增前台检测更新】APP从后台进入前台时（willEnterForegroundNotification）立即触发更新检测，不受启动时24小时限制；为避免频繁切换APP重复请求，增加2分钟最小间隔；检测失败静默处理不打扰用户；有新版本且未显示弹窗时才弹出
  - 涉及文件：富文本视图.swift、更新检测弹窗.swift、脚本列表页.swift

### v1.3.4
- 所有代码模板按照圈X实战标准脚本原理全面重写：
  - 【统一流程】所有响应处理类模板统一遵循圈X实战五步法：IIFE包裹→$response存在性检查→响应体空值检查→Content-Type/首字符判断非JSON放行→try-catch包裹JSON.parse→修改字段→JSON.stringify→$done返回→catch中原样放行
  - 【IIFE包裹】所有响应处理和请求体修改模板全部用(function(){...})()包裹，隔离变量避免污染全局，并添加中文注释说明IIFE作用
  - 【非JSON判断】新增Content-Type响应头检查+响应体首字符判断，非JSON响应（网页/图片等）直接放行，不破坏原始内容
  - 【分级日志】所有模板统一使用🚀[1]📦[2]✅[3]👑[4]🧹等带编号的分级日志，与真实圈X脚本风格一致
  - 【终极兜底】所有模板catch块中统一$done()原样放行，保证无论脚本发生什么异常都不会崩溃
  - 【覆盖范围】修改响应JSON字段、替换响应文本、去广告删除字段、去广告数组过滤、去广告批量删字段、HTML去广告、关键词屏蔽、条件通知、修改POST请求体共9个模板全部重写
  - 涉及文件：圈X代码模板.swift

### v1.3.3
- 修复沙箱多处故障，全面加固运行稳定性：
  - 【修复$notify重复注入】移除重置上下文中的$notify注入，统一在执行脚本时注入一次，避免参数签名不一致导致的崩溃
  - 【修复$notify参数类型】改用JSValue接收所有参数，手动判断isString后再转换，避免JS传undefined或非字符串时Swift侧String类型崩溃
  - 【修复console.log多参数】用JS包装console.log支持任意数量参数，对象自动JSON.stringify，与真实console.log行为一致
  - 【修复$done重复调用】新增done已调用标志位，多次调用$done时只执行第一次，后续调用输出提示并忽略，避免重复输出
  - 【修复线程安全】所有输出文本修改统一在主队列async执行，避免后台线程与主线程同时修改输出文本导致的崩溃或乱序
  - 【移除冗余注入】移除重置上下文中的$persistentStore注入，统一在执行脚本时注入，避免内存存储被覆盖
  - 涉及文件：脚本沙箱服务.swift

### v1.3.2
- 语法检查功能大幅加强，从6项检查扩展到16项：
  - 【基础语法】缺少$done检查、括号匹配（大/圆/方括号）、引号配对（双/单/反引号）、$done重复调用检测
  - 【圈X专项】API误用检测（$console/$persistentStore/$httpClient/$argument等Surge API混淆）、$response存在性检查、响应体空值检查、JSON.parse try-catch安全检查、$task异步回调$done检查、$notify参数检查、敏感信息硬编码检测
  - 【代码质量】IIFE包裹推荐、严格相等(===)检查、分号缺失提示、console.log调试输出统计、模板字符串兼容性提示、未使用变量检测
  - 【输出优化】检查结果汇总增加错误/警告/提示数量统计，每项检查都有中文描述和具体修复建议
  - 涉及文件：脚本静态检查服务.swift

### v1.3.1
- 更新窗口发布说明增加富文本显示：
  - 【新增】发布说明从纯Text改为富文本视图，支持Markdown格式渲染
  - 【支持格式】标题(#/##/###)、粗体(**text**)、斜体(*text*)、行内代码(`code`)、代码块(```)、无序列表(-/*)、有序列表(1.)、引用(>)、链接([text](url))、分割线(---)
  - 【iOS14兼容】使用UITextView+NSAttributedString实现，不依赖iOS15+的SwiftUI Markdown支持
  - 【新增文件】富文本视图.swift（包含富文本视图UIViewRepresentable和完整Markdown解析器）
  - 涉及文件：富文本视图.swift（新增）、更新检测弹窗.swift

### v1.3.0
- 修复iOS14上地址库和环境按钮点击无反应的bug：
  - 【根本原因】`.sheet(item:)`在iOS14上存在已知bug，枚举驱动的弹窗无法正常弹出，表现为按钮点击后无任何反应
  - 【修复方案】所有`.sheet(item:)`改为`.sheet(isPresented:)`+单独布尔状态`显示弹窗`驱动，按钮点击时同时设置`当前弹窗`类型和`显示弹窗=true`
  - 【覆盖范围】测试面板（地址库/环境弹窗）和编辑器页面（模板/补全弹窗）全部修复
  - 【按钮增强】自定义按钮组件添加`.contentShape(Rectangle())`确保整个按钮区域可点击，添加`.buttonStyle(PlainButtonStyle())`去除默认样式避免iOS14点击高亮异常
  - 涉及文件：脚本测试视图模型.swift、脚本编辑器视图模型.swift、脚本测试面板.swift、脚本编辑器页.swift

### v1.2.9
- 脚本测试输出增加真实请求头和请求体显示：
  - 【新增】获取真实响应体时，在输出中显示真实发送的请求信息：HTTP方法、目标网址、完整请求头（键值对列表）、请求体（POST/PUT/PATCH时）
  - 【新增】显示真实响应状态码和响应体长度，方便对比请求与响应
  - 【修复】请求体去除首尾空白后再发送，避免空白字符影响请求
  - 【修复】dataTask闭包增加[weak self]弱引用，避免循环引用
  - 涉及文件：脚本测试视图模型.swift

### v1.2.8
- 修复部分JSON转义序列未解码的问题：
  - 【问题】之前只解码了\uXXXX Unicode转义，其他标准JSON转义序列（\"双引号、\\反斜杠、\/正斜杠、\n换行、\r回车、\t制表符、\b退格、\f换页）仍显示为转义形式
  - 【修复】将`解码Unicode转义`方法升级为`解码JSON转义`，用统一正则表达式一次性匹配并解码所有9种标准JSON转义序列
  - 【实现细节】正则`\\\\(?:([\\\\\"/bfnrt])|u([0-9a-fA-F]{4}))`同时匹配普通转义和\u转义，从后往前替换避免范围偏移，\\双重反斜杠优先正确处理
  - 涉及文件：脚本测试视图模型.swift

### v1.2.7
- 重构脚本测试核心逻辑：$response.body改为动态从目标网址真实获取，不再使用固定默认数据：
  - 【核心改变】点击"运行测试"时自动真实请求目标网址获取响应体，获取成功后注入$response.body执行脚本，与圈X真实运行环境一致
  - 【缓存优先】相同网址已有缓存时直接使用缓存，跳过网络请求，提升重复测试速度
  - 【提取通用方法】新增`请求真实响应体`私有方法，统一处理网络请求+Unicode解码，执行测试和手动获取响应体均复用此方法，消除重复代码
  - 【失败处理】获取响应体失败时显示具体错误原因和提示，不再静默使用默认数据
  - 【手动获取保留】"获取响应体"按钮保留用于手动预获取和缓存，获取成功后后续运行测试直接使用缓存
  - 涉及文件：脚本测试视图模型.swift

### v1.2.6
- 修复脚本内容为空时仍显示默认响应体的问题：
  - 【问题】用户未输入任何脚本代码直接点击运行测试时，沙箱仍使用默认模拟响应体并显示，造成困惑
  - 【修复】执行测试前增加脚本内容空值检查，去除空白后为空则提示"请先在编辑器中输入脚本代码，再运行测试"，不执行测试、不显示响应体
  - 涉及文件：脚本测试视图模型.swift

### v1.2.5
- 修复获取缓存的JSON显示乱码问题：
  - 【问题原因】很多服务器返回的JSON会把中文字符转义为\uXXXX格式（如\u66f4\u65b0=\u66f4\u65b0"更新"），直接显示为乱码
  - 【解决方案】新增`解码Unicode转义`静态方法，用NSRegularExpression匹配所有\uXXXX序列并替换为实际Unicode字符（从后往前替换避免范围偏移）
  - 【应用时机】获取真实响应体后自动解码，缓存解码后的响应体（解码后的JSON同样合法，脚本JSON.parse可正常解析）
  - 【显示优化】响应体预览和输出均显示解码后的可读中文，输出提示"Unicode转义已解码为可读中文"
  - 涉及文件：脚本测试视图模型.swift

### v1.2.4
- 修复沙箱中console.log等函数报错"is not a function"的严重问题：
  - 【根本原因】@convention(block)闭包放入Swift字典[String: Any]后整体注入JavaScriptCore时，闭包被桥接为NSObject对象而非JS函数，导致调用时报"console.log is not a function. console.log is an instance of NSObject"
  - 【修复方案】所有含闭包的对象改用JSValue(newObjectIn:)创建JS对象，再逐个调用setObject(_:forKeyedSubscript:)设置闭包属性，确保闭包被正确桥接为JS函数
  - 【修复范围】console对象（log函数）、$console对象、$prefs对象（setValueForKey/valueForKey）、$persistentStore对象（write/read）、$httpClient对象（get/post）
  - 【未受影响】$notify、$nativeFetch等直接setObject单个闭包的注入方式原本就正确
  - 涉及文件：脚本沙箱服务.swift

### v1.2.3
- 修复新手教程弹窗"多余窗口"和"关闭按钮点不了"问题：
  - 【根本原因】新手教程弹窗使用.sheet弹出，sheet自带全屏背景+弹窗内部半透明遮罩形成"多余窗口"，且关闭按钮受sheet布局影响点击区域异常
  - 【修复方案】将新手教程弹窗从.sheet改为.overlay覆盖层（与智能分析弹窗一致），去掉sheet自带背景，只保留弹窗内部半透明遮罩
  - 【关闭按钮优化】关闭按钮点击区域从图标大小扩大到44pt×44pt（iOS推荐最小可点击尺寸），增加.contentShape(Rectangle())确保整个区域可点击
  - 【布局优化】弹窗垂直间距从40pt改为20pt，弹窗更居中，避免上下空白过多
  - 【代码清理】去掉编辑器弹窗类型枚举中不再使用的.教程case
  - 涉及文件：脚本编辑器页.swift、新手教程弹窗.swift、脚本编辑器视图模型.swift

### v1.2.2
- 新增新手教程功能（基于圈X官方文档整理）：
  - 编辑器顶部工具栏新增"教程"按钮，点击打开新手教程弹窗
  - 教程内容覆盖4大分类：基础语法（let/const/var/if/else/for/while/function/return/try-catch/typeof）、数据类型（String/Number/Boolean/Array/Object/undefined/null）、圈X专用API（$done/$request/$response/$task.fetch/$prefs/$notify/console.log/setTimeout）、常用操作（JSON.parse/JSON.stringify/安全访问嵌套对象/数组filter/delete删除属性/字符串替换）
  - 每个教程项包含：关键词、中文说明、可运行代码示例
  - 支持按分类筛选（全部/基础语法/数据类型/圈X专用API/常用操作）
  - 支持关键词搜索（如输入"$done"快速定位）
  - 圈X专用API部分特别标注：$done必须调用、console前面不加$、$task.fetch不是$httpClient、$prefs不是$persistentStore等新手易错点
  - 涉及文件：新手教程弹窗.swift（新建）、脚本编辑器页.swift、脚本编辑器视图模型.swift

### v1.2.1
- JS脚本测试网络速度全面优化：
  - 【核心功能】新增"一键获取真实响应体"按钮：真实请求目标网址获取响应体并缓存，执行脚本时直接使用缓存数据，避免脚本中重复发起网络请求
  - 【缓存机制】相同网址不重复请求，直接使用缓存；显示缓存字符数状态；支持一键清除缓存
  - 【获取中状态】显示加载指示器和取消按钮，8秒超时平衡速度和容忍度
  - 【输出优化】$task.fetch网络请求不再输出完整请求头/响应头（只输出字段数量和状态码），响应体只预览前500字符（原2000字符），大幅减少大文本输出开销
  - 【超时优化】$task.fetch网络请求超时从10秒缩短为8秒
  - 【输入响应体优化】沙箱执行时大响应体只预览前500字符，避免输出完整大文本影响速度
  - 涉及文件：脚本测试视图模型.swift、脚本测试面板.swift、脚本沙箱服务.swift

### v1.2.0
- 智能分析全部导入模块（综合模板）及所有单字段模板全面优化，采用用户提供的圈X实战脚本风格：
  - 【核心优化】统一初始化父级路径（只检查一次）→ 直接修改字段（不再重复判断），代码更简洁高效
  - 新增`收集所有父级路径`辅助方法：从字段路径列表中收集所有需要初始化的父级路径，去重并按层级排序
  - 新增`生成统一初始化代码`辅助方法：生成`if (!路径 || typeof 路径 !== "object" || Array.isArray(路径)) 路径 = {};`风格的初始化代码
  - 综合模板（全部导入）：会员状态/到期时间/等级/昵称/积分/隐私掩码全部改为直接赋值`body.字段路径 = 值`，广告删除保持函数式递归
  - 单字段模板同步优化：会员状态/会员到期/会员等级/修改昵称/修改积分/隐私保护全部改为统一初始化+直接修改风格
  - 所有模板增加`console.log("✔️...完成")`执行完成日志，与用户提供的实战脚本风格一致
  - 手机号/邮箱掩码增加`|| ""`空值保护，避免undefined导致replace报错
  - 涉及文件：智能分析服务.swift

### v1.1.9
- 所有模板中VIP会员状态字段赋值从`=true`统一改为`=1`（圈X脚本中会员状态常用数字1表示）：
  - 内置模板库「修改响应JSON字段」模板：`body.data.isVip = true` → `= 1`
  - 智能分析服务「会员状态字段关键词」注释：布尔型→数字型（值为1/0）
  - 智能分析服务「解锁会员」模板说明：设为true→设为1
  - 智能分析服务通用模板示例注释：`body.data.isVip = true` → `= 1`
  - 智能分析服务综合模板生成中会员状态赋值：`= true` → `= 1`
  - 智能分析服务单字段会员状态模板：`= true` → `= 1`
  - 代码补全服务「修改响应体」补全项：`body.data.isVip = true` → `= 1`
  - 涉及文件：圈X代码模板.swift、智能分析服务.swift、代码补全服务.swift

### v1.1.8
- 自动更新检测与手动更新检测全面修复：
  - 【核心修复】网络失败不再误报"已是最新版本"：新增`更新检测错误`枚举，区分网络不可用/请求超时/服务器错误/API限流/数据解析失败等具体错误类型
  - 【手动检测】检测失败时弹出`检测失败弹窗`，显示具体错误原因并提供"重新检测"按钮，不再错误地显示"无更新"弹窗
  - 【自动检测】检测成功后才记录检测时间，网络失败时不记录，确保下次启动仍可自动检测（修复失败后24小时不再检测的问题）
  - 【超时优化】网络请求超时从5秒延长到10秒，网络不佳时给足响应时间
  - 【API限流】新增GitHub API 403限流状态码处理，给出明确提示
  - 涉及文件：App更新服务.swift、更新检测弹窗.swift、脚本列表页.swift

### v1.1.7
- JS脚本测试面板请求头输入框改为可折叠，默认折叠状态：
  - 标题行增加展开/折叠箭头（chevron.right/down），点击切换
  - 折叠时若已配置请求头内容，标题旁显示蓝色"（已配置）"标记，提示用户有内容
  - 展开/收起带0.2秒easeInOut动画和opacity过渡，流畅自然
  - 涉及文件：脚本测试面板.swift

### v1.1.6
- 编辑器操作栏位置修正：按用户要求将字体大小/删除/复制按钮从顶部工具栏移回编辑器下方原字体大小区域
- 字体大小拆分为两个独立按键：A-缩小按钮和A+增大按钮，中间显示当前字号，支持10-24pt范围步进调整，到达边界自动禁用
- 右侧保留一键删除（清空代码区）和一键复制（复制全部代码到剪贴板）按钮
- 字号设置通过UserDefaults持久化，自动记忆用户上次使用的字体大小
- 涉及文件：脚本编辑器页.swift

### v1.1.5
- 编辑器工具栏交互优化：
  - 【字体大小改按键】移除底部Slider字体调整，改为顶部工具栏字体大小按键（Aa图标+当前字号），点击循环切换常用字号10/12/14/16/18/20/24pt
  - 【自动记忆字号】字体大小通过UserDefaults持久化存储，启动时自动读取用户上次使用的字号，无需每次重新调整
  - 【一键删除】字体大小键右侧新增一键删除按钮（trash图标红色），点击立即清空代码区内容
  - 【一键复制】字体大小键右侧新增一键复制按钮（doc.on.doc图标蓝色），点击将代码区全部内容复制到系统剪贴板
- 涉及文件：脚本编辑器视图模型.swift、脚本编辑器页.swift

### v1.1.4
- 智能分析功能三大升级：
  - 【四步流程全覆盖】智能分析动态生成的所有模板（会员状态/到期/等级/去广告字段/去广告数组/导出用户信息/隐私保护/修改昵称/修改积分/通用模板）全部统一为圈X标准四步扁平结构：第一步获取$response.body不是JSON放行→第二步JSON.parse转对象→第三步修改字段→第四步JSON.stringify调用$done，彻底告别嵌套try
  - 【综合模板置顶】新增"⭐ 全部导入"综合模板，自动将所有识别到的会员解锁/去广告/用户信息修改/隐私保护字段合并到一个完整脚本中，一键插入即用，在模板列表中置顶显示
  - 【一键删除/一键粘贴】智能分析弹窗输入框顶部新增"一键粘贴"按钮（自动读取剪贴板内容填入）和"一键删除"按钮（清空输入框），操作更便捷
- 涉及文件：智能分析服务.swift、智能分析弹窗.swift

### v1.1.3
- 全部模板按圈X标准四步流程重构，新手一看就懂：
  - 第一步：获取 $response.body，不是JSON就原样放行
  - 第二步：JSON.parse() 把文本"翻译"成脚本能修改的对象
  - 第三步：修改对象里的字段
  - 第四步：JSON.stringify() 把对象重新"压回"文本，调用 $done({ body: ... })
- 所有响应处理类模板（修改响应JSON字段/去广告删除字段/去广告数组过滤/去广告数组批量删除/条件通知/修改POST请求体）统一四步结构，每步都有明确中文注释
- 纯文本处理类模板（替换响应文本/HTML去广告/关键词屏蔽）标注"不需要JSON.parse"，流程同样清晰
- 全部模板catch块错误输出统一为安全写法`错误 && 错误.message ? 错误.message : String(错误)`，彻底避免Error对象拼接输出[object Object]
- 涉及文件：圈X代码模板.swift

### v1.1.2
- 智能分析功能全面升级：字段路径智能识别与模板生成
  - 提取公共`生成安全导航`方法，自动处理任意嵌套层级（data.user.isVip / data.info.VIP / root.isVip），不再一成不变写死在data里
  - 导航代码新增`typeof !== "object"`和`Array.isArray`检查，父级为数组/字符串/数字时自动替换为空对象，确保赋值一定生效
  - 所有5个字段修改模板（会员状态/会员到期/会员等级/修改昵称/修改积分）统一使用智能导航，根级字段自动跳过导航
  - 隐私保护模板导航代码新增`typeof === "object"`类型检查
  - 分析结果路径展示改用`›`分隔符（data › user › isVip），层级更直观
  - 全部模板catch块错误输出改为安全写法`错误 && 错误.message ? 错误.message : String(错误)`，避免Error对象拼接输出[object Object]
- 涉及文件：智能分析服务.swift、智能分析弹窗.swift

### v1.1.1
- 全面检查并修复代码模板中的错误：
  - 【严重】「运行环境检测」模板：`isJSBox`变量未定义直接使用，导致`ReferenceError: isJSBox is not defined`，已补充定义`const isJSBox = typeof $app != "undefined" && typeof $http != "undefined"`
  - 【严重】「修改响应JSON字段」模板：catch块中`console.log("...: " + 错误)`直接拼接Error对象会输出`[object Object]`而非错误信息，已改为`错误 && 错误.message ? 错误.message : String(错误)`
  - 【改进】「修改请求头（UA）」和「修改请求头（Cookie）」模板：原写法`const headers = $request.headers`直接引用可能因不可变对象导致修改不生效，已改为`Object.assign({}, $request.headers)`创建可变副本后修改再赋值回去
- 涉及文件：圈X代码模板.swift

### v1.1.0
- 彻底修复更新下载完成后弹出接近满屏多余窗口的问题：
  - 完全移除 `分享面板视图`、`分享文本视图` 两个 `UIViewControllerRepresentable` 封装及其内部的 `分享面板容器控制器`、`文本分享容器控制器`
  - 移除脚本列表页的 `.sheet(item: $分享URL)` 和 `分享URL` 状态变量
  - 移除测试面板弹窗枚举中的 `.分享输出` case 和对应的 sheet
  - 新增纯静态 `分享服务` 枚举，提供 `分享文件(文件URL:)` 和 `分享文本(文本:)` 两个方法
  - `分享服务` 直接获取当前最顶层视图控制器（递归沿 presentedViewController 链查找），从顶层直接 present `UIActivityViewController`，无任何中间容器
  - iOS14兼容：使用 `connectedScenes` + `UIWindowScene` 获取 keyWindow，不使用已废弃的 `UIApplication.shared.keyWindow`
  - iPad适配：设置 `popoverPresentationController` 的 sourceView/sourceRect 从屏幕中间弹出
  - 所有分享入口（脚本长按分享、IPA下载完成分享、测试输出分享）均改为直接调用 `分享服务`
- 涉及文件：分享面板视图.swift（完全重写）、脚本列表页.swift、脚本测试面板.swift、脚本测试视图模型.swift

### v1.0.9
- 学习圈X官网JS脚本规范，全面完善沙箱与代码模板：
  - 沙箱新增注入圈X原生API：`$task.fetch`（Promise风格网络请求）、`$prefs.setValueForKey/valueForKey`（持久化存储）、`$notify(title,subtitle,message,options)`（通知弹窗）
  - 沙箱同时兼容注入Surge API：`$httpClient.get/post`、`$persistentStore.write/read`，跨平台脚本均可运行
  - 模板库3个模板从Surge API改为圈X原生API：GET请求`$httpClient.get`→`$task.fetch`、POST请求`$httpClient.post`→`$task.fetch`、持久化`$persistentStore`→`$prefs`
  - 新增「运行环境检测」模板：判断圈X/Surge/Node环境，提供跨平台通知和网络请求封装
  - 新增「通知弹窗带链接」模板：`$notify`第四个参数`{"open-url": "..."}`实现点击跳转
  - 代码补全新增`$prefs.setValueForKey`/`$prefs.valueForKey`/`$notify带链接`/`环境检测`4项
  - 代码补全标注`$httpClient`/`$persistentStore`为Surge API，提示圈X用户使用原生API
- 修复更新窗口"已是最新版本"确认按钮点击后延迟很久才能关闭的问题：
  - `无更新提示弹窗`改用明确Button(action:) + PlainButtonStyle，避免iOS14默认按钮样式延迟
  - `更新弹窗覆盖层`添加`.animation(nil)`禁用弹窗动画，确保点击后立即关闭
  - 按钮添加`.transition(.opacity)`快速淡入淡出
- 修复iOS弹窗有多余空白窗口跟随的问题：
  - 分享面板容器控制器（文件分享+文本分享）设置`modalPresentationStyle = .overFullScreen`，消除sheet卡片背景残留
  - `completionWithItemsHandler`中先回调SwiftUI关闭sheet，再立即dismiss容器自身，避免透明空白窗口残留
- 涉及文件：脚本沙箱服务.swift、圈X代码模板.swift、代码补全服务.swift、更新检测弹窗.swift、脚本列表页.swift、分享面板视图.swift

### v1.0.8
- 修复圈X控制台写法错误：所有模板中`$console.log`改为圈X标准写法`console.log`（圈X中console前面无需加$）
- 沙箱服务同时注入`console`和`$console`两个对象，新老写法均兼容
- 代码补全触发词`$console`改为`console`，插入代码使用标准`console.log()`
- 静态检查服务更新console.log提示文案：修正"圈X环境中console.log不会显示"的错误描述，改为提示发布前移除调试代码
- 学习用户提供的真实圈X脚本代码风格，全面改进「修改响应JSON字段」核心模板：
  - 增加$response存在性检查（typeof undefined/null），挂在请求阶段时给出明确错误提示
  - 增加响应体空值检查，204/304或未开启MitM时给出明确提示
  - 增加响应体长度和前100字符预览日志，方便调试
  - 采用分级日志风格（🚀[1]📦[2]✅[3]👑[4]🎉[5]❌），与真实圈X脚本一致
  - 字段修改失败时输出body下可用键列表，帮助新手定位字段路径
  - catch块输出完整错误对象（e而非e.message），信息更全面
- 涉及文件：脚本沙箱服务.swift、圈X代码模板.swift、智能分析服务.swift、代码补全服务.swift、脚本静态检查服务.swift

### v1.0.7
- 修复测试输出中$done返回值显示为Swift字典格式（{ body = "{}"; statusCode = 200; }）导致用户无法直观看到修改后响应体的问题
- 改进$done输出格式：
  - 解析$done返回的字典，分别展示状态码、响应头、响应体
  - 响应体自动尝试JSON美化输出（prettyPrint），非JSON则原样显示
  - 超长响应体自动截断（2000字符）
- 输出结构优化，明确区分输入与输出：
  - `[输入响应体]`：脚本执行前的模拟响应体（青色）
  - `---------- 脚本执行 ----------`：分隔线
  - `[修改后响应体]`：脚本执行后$done返回的响应体（绿色）
  - `[状态码]`：HTTP状态码（橙色）
- 新增容错日志颜色标识：`[容错]`/`[降级]`/`[兜底]`显示为黄色，`[日志]`显示为灰色
- 涉及文件：脚本沙箱服务.swift、脚本测试面板.swift

### v1.0.6
- JS脚本测试功能三项优化：
  1. 请求体默认折叠：移除POST/PUT/PATCH方法切换时自动展开请求体的行为，用户手动点击展开
  2. 测试网址默认值+点击清除：网址输入框默认填充 https://h5.xxoox20.org/api/init，用户首次点击进入编辑状态时自动清除默认网址，可重新输入
  3. 增强测试输出功能：
     - 输出区域新增行数统计（与字符数并列显示）
     - 输出区域新增清空按钮（一键清除输出）
     - 输出区域新增分享按钮（通过系统分享面板导出输出文本）
     - 输出区域新增自动滚动开关（可关闭自动滚动查看历史输出）
     - 输出区域新增自动换行开关（可关闭换行横向滚动查看长行）
     - 耗时统计移至输出区域统计行
- 新增`分享文本视图`组件（UIActivityViewController的SwiftUI封装，支持纯文本分享）
- 涉及文件：脚本测试面板.swift、脚本测试视图模型.swift、分享面板视图.swift

### v1.0.5
- 修复模板功能在iOS14上点击按钮无反应的兼容性问题（iOS16正常）
- 根因1（主要）：iOS14不支持同一视图上多个并列`.sheet(isPresented:)`修饰符，导致模板弹窗无法弹出（iOS15已修复此bug）
- 修复1：全项目重构所有多sheet为单sheet+枚举方案：
  - 脚本编辑器页：模板弹窗+补全弹窗 → `编辑器弹窗类型`枚举 + `.sheet(item:)`
  - 脚本测试面板：网址管理+环境管理 → `测试面板弹窗类型`枚举 + `.sheet(item:)`
  - 脚本列表页：IPA分享+脚本分享 → 单一`分享URL: URL?` + `.sheet(item:)`（添加URL: Identifiable扩展）
- 根因2：iOS14中`List`内的`Button`使用默认样式时点击可能无响应
- 修复2：模板行视图和补全项行视图添加`.buttonStyle(PlainButtonStyle())`
- 修复3：`Text(String.prefix())`显式转换为`String`，避免Substring类型歧义
- 涉及文件：脚本编辑器页.swift、脚本测试面板.swift、脚本列表页.swift、模板选择弹窗.swift、代码补全弹窗.swift、脚本编辑器视图模型.swift、脚本测试视图模型.swift

### v1.0.4
- 修复脚本测试沙箱中"Return statements are only valid inside functions"语法错误
- 根因：圈X真实运行时会将脚本包装在函数上下文中，允许顶层return语句；但App内JS沙箱直接evaluateScript在全局上下文执行，顶层return非法
- 修复：沙箱执行前将用户代码包装在立即执行函数(IIFE) `(function() { ... })();` 中，与圈X环境完全一致
- 修复：沙箱新增注入`$response`对象（含默认模拟响应体），响应修改类模板可正常测试
- 修复：沙箱新增注入`$console`对象，模板中的`$console.log`调试输出可正常显示
- 修复：所有模板中`const 原始响应体 = $response.body`改为`const 原始响应体 = ($response && $response.body) || ""`，在$response未定义时不会崩溃
- 涉及文件：脚本沙箱服务.swift、圈X代码模板.swift、智能分析服务.swift、代码补全服务.swift

### v1.0.3
- 全面检查并修复所有模板中的9处潜在错误：
  1. 修复"修改请求体（POST）"模板缺少JSON解析try-catch，请求体非JSON时会崩溃
  2. 修复"GET请求并处理响应"模板缺少响应JSON解析容错
  3. 修复"POST请求提交数据"模板直接将完整response.body传入$notify可能导致通知过长
  4. 修复"持久化存储读写"模板parseInt可能返回NaN导致计算异常，增加isNaN检查
  5. 修复"URL参数解析工具"模板decodeURIComponent可能因非法编码抛出异常，增加try-catch和降级返回
  6. 修复"条件通知弹窗"模板JSON解析失败和异常兜底时调用$done()而非返回原始响应体，可能导致响应丢失
  7. 修复智能分析服务中会员状态/到期/等级/昵称/积分5个生成模板的导航代码只检查undefined不检查null，字段为null时后续访问会崩溃
  8. 修复智能分析服务中隐私保护模板导航代码只检查undefined不检查null
  9. 修复智能分析服务中导出用户信息模板未保存原始响应体，异常时调用$done()可能导致响应丢失
- 所有修复遵循核心原则：无论脚本执行过程中发生什么异常，都必须保证返回有效的响应体

### v1.0.2
- 所有脚本模板增加四级容错机制，确保无论接口数据如何变动都不会崩溃
- 四级容错体系：
  - 基础容错：空值保护（所有字段访问前检查存在性）、类型转换（String()/Number()/Boolean()确保类型正确）
  - 进阶容错：数据校验（修改前验证字段类型和结构）、降级处理（字段缺失时跳过修改并记录日志）
  - 高级容错：异常隔离（try-catch包裹核心逻辑，单个字段/项处理失败不影响其他）、日志记录（$console.log记录容错和降级事件）
  - 终极容错：兜底返回（外层try-catch捕获所有异常，任何情况下都返回原始响应体$response.body）
- 涉及模板：模板库全部9个响应处理模板 + 智能分析服务全部10个生成模板
- 代码补全新增：「四级容错模板」和「安全读取嵌套字段」两个补全项
- 核心原则：无论脚本执行过程中发生什么异常，都必须保证返回有效的响应体

### v1.0.1
- 修复所有响应修改模板的`$done`返回值格式，确保APP能正常接收数据
- 统一使用`$done({ body: JSON.stringify(body) })`格式返回修改后的响应体
- 涉及文件：圈X代码模板.swift（9个响应模板）、智能分析服务.swift（10个生成模板）、代码补全服务.swift（7个补全项）、代码键盘视图.swift（6个键盘按钮）
- 修复内容：
  - 所有`$response.body = ...; $done($response);`改为`$done({ body: ... });`
  - 所有提前返回guard的`$done($response)`改为`$done()`（原样透传）
  - 修复代码键盘中错误的`$done({response: $response})`和`$done({request: $request})`格式
  - 字符串类型响应（HTML/文本替换）使用`$done({ body: body })`
  - 修改状态码/响应头时保留原响应体：`$done({ body: $response.body, statusCode: 200 })`

### v1.0.0
- 获取信息功能新增用户核心信息识别，里程碑版本v1.0.0
- 自动识别9类用户核心信息字段：
  - 用户ID（userId/uid/id/memberId等）
  - 用户名/昵称（userName/nickname/name/displayName等）
  - 手机号（phone/mobile/tel/phoneNumber等）
  - 邮箱（email/mail/emailAddress等）
  - 头像（avatar/headImg/photo/portrait等）
  - 积分余额（points/score/balance/coin/money等）
  - 登录Token（token/accessToken/sessionId/jwt等）
  - 性别（gender/sex等）
  - 生日（birthday/birthDate/age等）
- 短关键词（id/name/phone/token等）仅精确匹配，避免误判
- 分析结果新增蓝色「用户核心信息」展示区域，显示字段路径、当前值、类型标签
- 自动生成4类用户信息模板：
  - 导出用户核心信息：通过通知弹窗展示所有识别到的用户信息
  - 隐私保护：手机号中间4位星号、邮箱前缀星号掩码
  - 修改用户昵称：一键修改用户昵称字段
  - 修改积分余额：一键修改积分/余额数值（自动判断数字/字符串类型）

### v0.9.9
- 全新应用图标设计，完美契合「圈X脚本编辑器」名称：
  - 发光圆环代表「圈」（QuantumX的环形轨道）
  - 圆环右侧的X标记代表「X」
  - 中心的</>代码符号代表「脚本编辑器」
  - 紫蓝渐变背景，科技感十足，扁平化现代设计
- 图标尺寸1024x1024，适配iOS全尺寸设备

### v0.9.8
- 顶部工具栏新增「获取信息」智能分析按钮
- 用户粘贴抓包数据（JSON/cURL/HAR/键值对）后自动识别：
  - 会员信息：会员状态(isVip/vip/member)、到期时间(vipExpire/expire)、会员等级(level/vipLevel)
  - 广告信息：广告标记(isAd/ad)、广告链接(adUrl)、广告图片(adImage)、广告数组
- 识别结果分类展示，显示字段路径、当前值、类型标签
- 根据识别结果自动生成对应脚本模板：
  - 解锁会员状态（字段设为true）
  - 会员永久有效（到期时间设为2099年，自动判断时间戳/日期格式）
  - 提升会员等级（设为最高级，自动判断数字/字符串类型）
  - 去广告（批量删除识别到的广告字段）
  - 去广告数组（从列表中过滤广告项）
- 点击「插入到代码区」将生成的模板代码追加到编辑器末尾
- 全部模板附带中文注释和识别字段说明，新手可直接使用

### v0.9.7
- 响应模板库新增6个去广告相关模板（全部附带中文注释和配置区）：
  - 去广告（删除JSON字段）：支持多级路径递归删除ad/banner等广告字段
  - 去广告数组（列表过滤广告项）：按type/is_ad/ad_id等字段从信息流数组中过滤广告卡片
  - 去广告数组（批量删除多字段）：遍历数组批量删除每一项的ad_url/ad_image等广告字段
  - 去广告（HTML页面移除广告节点）：正则匹配移除class含ad的div/iframe/Google AdSense/广告script
  - 去广告（关键词屏蔽返回空）：检测响应含广告关键词则返回空响应阻断
  - 阻断响应（返回空）：已有模板，归入去广告场景

### v0.9.6
- 修复代码补全功能不可用问题：inputAccessoryView动态高度（0pt↔44pt）在iOS上不可靠，改为固定44pt高度+空态占位提示
- 补全候选栏空态显示提示文字"输入代码触发补全建议"，有候选时自动切换为横向滚动候选按钮
- 补全资料库扩充至100+项，新增：
  - 圈X高级API：$prefs、$config、$console、$task.fetch（Promise风格）
  - 请求处理：读取Cookie、修改UA、重写请求方法
  - 响应处理：安全解析JSON、注入JS到HTML、修改状态码
  - 加密编码：SHA1、SHA256、HMAC签名、随机字符串、时间戳nonce
  - 控制流：提前结束$done、三元表达式、可选链访问
  - 存储：删除存储键、存储布尔值
  - 字符串：重复、填充、反转
  - 数学：范围随机数、千分位格式化
  - JSON：安全访问嵌套字段、对象转数组、数组去重

### v0.9.5
- 脚本测试功能全面优化
- 新增HTTP方法选择器：GET/POST/PUT/DELETE/PATCH，各方法不同颜色标识
- 新增请求体编辑区（可折叠），POST/PUT/PATCH自动展开，支持JSON/文本
- 新增停止执行按钮，运行中可随时中断脚本和网络请求
- 新增复制输出按钮，一键复制测试结果到剪贴板
- 新增执行耗时统计，显示脚本执行秒数
- 测试输出彩色化：错误红色、通知蓝色、网络请求橙色、响应青色、完成绿色、耗时紫色
- 网络请求输出完整请求头、请求体、响应头、响应体（超长自动截断）
- 输出区域自动滚动到底部，实时查看最新日志

### v0.9.4
- 脚本列表长按文件名添加上下文菜单（重力菜单）
- 支持重命名：弹出输入框修改脚本名称
- 支持删除：二次确认后删除脚本文件
- 支持分享：通过系统分享面板分享.js脚本文件
- 支持打开所在文件夹：跳转系统文件App查看QuantumXScripts目录

### v0.9.3
- 修复更新检测弹窗卡顿问题：网络超时从10秒缩短至5秒，快速失败
- 检测中弹窗新增"取消"按钮，点击背景也可取消，无需等待网络返回
- 新增取消网络请求能力，取消后不再回调结果
- 避免并发检测请求，新检测自动取消旧任务

### v0.9.2
- 代码键盘删除底部工具栏，Tab键移至英文键盘左下角，换行键移至右下角
- 英文键盘去掉@和#键，第五行布局：Tab+, . ! ?+空格+& /+换行
- 代码键盘改为默认不弹出，顶部工具栏新增手动开关按钮，点击切换系统/代码键盘
- 补全辅助栏移除键盘切换按钮，界面更简洁

### v0.9.1
- CI优化：添加concurrency并发控制，同一分支只保留最新构建，取消旧运行
- IPA文件名改为APP名称+版本号格式：QuantumXScriptEditor-v0.9.1.ipa
- 版本号采用0.0.1递增规则，逢九进一

### v0.9.0
- 修复键盘输入时屏幕乱跳bug：键盘高度固定280pt，移除自适尺寸，英文页面顶部对齐固定行高
- 英文键盘扩充为5行布局：数字行(0-9)+QWERTY+ASDF+ZXCV(Shift/删除)+符号空格行
- 符号空格行：左侧,.!? + 弹性空格 + 右侧@#&/，不留空白
- 禁止页面内滚动视图垂直弹跳，输入更稳定

### v0.8.0
- 代码键盘新增英文26键QWERTY页面，设为默认首页
- 英文键盘支持Shift大小写切换，输入大写后自动切回小写
- 标准三行键盘布局（QWERTY/ASDFG/ZXCVB），第二行错位缩进
- 第三行集成Shift键与删除键，操作更便捷

### v0.7.0
- 更新下载改为App内直接下载IPA，实时显示下载进度条
- 下载完成后自动弹出iOS系统分享面板，支持AltStore/TrollStore/文件等侧载方式
- 下载失败可一键重试
- 下载过程中禁止关闭弹窗，防止中断

### v0.6.0
- 新增新手友好代码键盘：4大页面（符号50+/关键字40+/圈X30+/片段25+），共130+快捷按键
- 代码键盘含Tab/空格/删除/换行功能键，支持左右滑动切换页面
- 补全栏新增键盘切换按钮，一键在自定义代码键盘与系统键盘间切换
- 代码键盘默认启用，新手无需切换系统键盘即可输入常用代码

### v0.5.0
- 代码补全库扩充至80+项，新增加密编码/日期时间/字符串处理/正则匹配/数学运算/JSON处理等6大分类
- CI/CD自动发布Release：推送master自动构建并发布GitHub Release
- App端新增自动检测更新（启动时每日一次）
- App端新增手动检测更新（列表页左上角按钮）
- 更新弹窗：版本对比、发布说明、一键下载、忽略版本

### v0.4.0
- 新增代码补全（键盘上方候选条 + 手动搜索弹窗）
- 新增脚本模板库（15+模板，6大分类，全中文注释）
- 新增静态检查增强（中文错误解读 + 修复建议）
- 新增代码格式化
- 新增JS沙箱测试面板（URL历史/收藏/自定义请求头/多环境/真实网络请求/超时保护）
- 最低支持iOS14

### v0.3.0
- 带行号代码编辑器
- 语法高亮
- 脚本本地管理

## 免责声明

本工具仅供学习与开发调试使用。用户需自行承担使用本工具编写的脚本所带来的一切后果。本工具不与 QuantumX 客户端通信，无法替代真实环境测试。
