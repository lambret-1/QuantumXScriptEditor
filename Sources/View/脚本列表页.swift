import SwiftUI

/// URL扩展遵循Identifiable（iOS14兼容：用于.sheet(item:)）
extension URL: Identifiable {
    public var id: String { absoluteString }
}

/// 脚本列表页，展示本地所有脚本，支持新建、删除、进入编辑、更新检测
struct 脚本列表页: View {
    /// 列表视图模型
    @StateObject private var 视图模型 = 脚本列表视图模型()
    /// 退出模式（iOS14兼容）
    @Environment(\.presentationMode) private var 退出模式
    /// 更新信息
    @State private var 更新信息: App更新模型?
    /// 是否显示更新弹窗
    @State private var 显示更新弹窗 = false
    /// 是否显示无更新弹窗
    @State private var 显示无更新弹窗 = false
    /// 是否正在检测更新
    @State private var 检测更新中 = false
    /// 是否显示更新检测中弹窗
    @State private var 显示检测中弹窗 = false
    /// 要分享的文件URL（IPA或脚本文件，iOS14兼容：单sheet+可选URL，避免多sheet并列bug）
    @State private var 分享URL: URL?
    // MARK: - 长按上下文菜单状态
    /// 长按选中的脚本
    @State private var 长按选中脚本: 脚本模型?
    /// 是否显示重命名弹窗
    @State private var 显示重命名弹窗 = false
    /// 重命名输入文本
    @State private var 重命名输入 = ""
    /// 是否显示删除确认弹窗
    @State private var 显示删除确认 = false
    /// 文件夹提示文本（打开文件夹后显示）
    @State private var 文件夹提示: String?

    var body: some View {
        NavigationView {
            ZStack {
                // 列表内容
                List {
                    if 视图模型.存储.脚本列表.isEmpty {
                        空态视图()
                    } else {
                        ForEach(视图模型.存储.脚本列表) { 脚本 in
                            NavigationLink(destination: 脚本编辑器页(脚本: 脚本, 存储: 视图模型.存储)) {
                                脚本行视图(脚本: 脚本)
                            }
                            .contextMenu {
                                // 重命名
                                Button(action: {
                                    长按选中脚本 = 脚本
                                    重命名输入 = 脚本.名称
                                    显示重命名弹窗 = true
                                }) {
                                    Label("重命名", systemImage: "pencil")
                                }
                                // 分享
                                Button(action: {
                                    长按选中脚本 = 脚本
                                    分享URL = 视图模型.存储.获取脚本文件URL(脚本)
                                }) {
                                    Label("分享", systemImage: "square.and.arrow.up")
                                }
                                // 打开所在文件夹
                                Button(action: {
                                    打开所在文件夹()
                                }) {
                                    Label("打开所在文件夹", systemImage: "folder")
                                }
                                // 删除（破坏性操作）
                                Button(action: {
                                    长按选中脚本 = 脚本
                                    显示删除确认 = true
                                }) {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { 索引集 in
                            索引集.forEach { 索引 in
                                视图模型.删除脚本(视图模型.存储.脚本列表[索引])
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle()) // iOS14兼容的分组列表样式
                .navigationBarTitle("圈X脚本编辑器", displayMode: .large)
                .navigationBarItems(
                    leading:
                        Button(action: {
                            手动检测更新()
                        }) {
                            Image(systemName: "arrow.up.arrow.down.circle")
                                .font(.title3) // 标题3字号，更新检测按钮
                        },
                    trailing:
                        Button(action: {
                            视图模型.显示新建弹窗 = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2) // 标题2字号，加号按钮醒目
                        }
                )
                .onAppear {
                    自动检测更新()
                }

                // 错误提示浮层
                if let 错误 = 视图模型.错误提示 {
                    VStack {
                        Spacer()
                        Text(错误)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.85))
                            .cornerRadius(8)
                            .padding(.bottom, 20)
                    }
                    .transition(.move(edge: .bottom))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            视图模型.错误提示 = nil
                        }
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // 竖屏单栏堆叠样式，避免iPad分栏
        // 新建脚本输入弹窗覆盖层（iOS14 Alert不支持TextField，使用自定义覆盖层）
        .overlay(新建脚本弹窗覆盖层)
        // 更新检测弹窗覆盖层
        .overlay(更新弹窗覆盖层)
        // iOS14兼容：单sheet+可选URL，避免多sheet并列时只有一个能弹出的bug
        .sheet(item: $分享URL) { 文件URL in
            分享面板视图(文件URL: 文件URL) {
                分享URL = nil
            }
            .background(透明背景()) // 透明背景，只显示系统分享面板
        }
        // 重命名弹窗覆盖层
        .overlay(重命名弹窗覆盖层)
        // 删除确认弹窗覆盖层
        .overlay(删除确认覆盖层)
        // 文件夹提示浮层
        .overlay(文件夹提示覆盖层)
    }

    // MARK: - 更新检测逻辑

    /// 自动检测更新（启动时每日一次）
    private func 自动检测更新() {
        guard App更新服务.需要自动检测 else { return }
        App更新服务.记录检测时间()
        App更新服务.检测最新版本 { 信息 in
            guard let 信息 = 信息 else { return }
            // 检查是否被忽略
            if let 忽略版本 = App更新服务.忽略版本号, 忽略版本 == 信息.版本号 {
                return
            }
            if App更新服务.有新版本(最新版本: 信息.版本号, 当前版本: App更新服务.当前版本号) {
                更新信息 = 信息
                显示更新弹窗 = true
            }
        }
    }

    /// 手动检测更新
    private func 手动检测更新() {
        检测更新中 = true
        显示检测中弹窗 = true
        App更新服务.检测最新版本 { 信息 in
            检测更新中 = false
            显示检测中弹窗 = false
            guard let 信息 = 信息 else {
                // 检测失败，提示无更新（避免用户困惑）
                显示无更新弹窗 = true
                return
            }
            if App更新服务.有新版本(最新版本: 信息.版本号, 当前版本: App更新服务.当前版本号) {
                更新信息 = 信息
                显示更新弹窗 = true
            } else {
                显示无更新弹窗 = true
            }
        }
    }

    /// 更新弹窗覆盖层
    private var 更新弹窗覆盖层: some View {
        Group {
            if 显示检测中弹窗 {
                更新检测弹窗(
                    更新信息: App更新模型(版本号: "", 标签: "", 发布说明: "", 下载地址: "", 页面地址: "", 发布时间: ""),
                    检测中: true,
                    关闭回调: {
                        显示检测中弹窗 = false
                    },
                    取消回调: {
                        App更新服务.取消检测()
                    }
                )
            } else if 显示更新弹窗, let 信息 = 更新信息 {
                更新检测弹窗(更新信息: 信息, 关闭回调: {
                    显示更新弹窗 = false
                }, 下载完成回调: { 文件URL in
                    显示更新弹窗 = false
                    分享URL = 文件URL
                })
            } else if 显示无更新弹窗 {
                无更新提示弹窗 {
                    显示无更新弹窗 = false
                }
            }
        }
        .animation(nil) // 【关键修复】禁用弹窗动画，确保点击确定后立即关闭，无延迟
    }

    /// 新建脚本输入弹窗覆盖层（因为iOS14 Alert不支持TextField）
    private var 新建脚本弹窗覆盖层: some View {
        Group {
            if 视图模型.显示新建弹窗 {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        视图模型.显示新建弹窗 = false
                    }
                新建脚本弹窗(视图模型: 视图模型)
                    .transition(.scale)
            }
        }
    }

    // MARK: - 长按上下文菜单操作

    /// 打开脚本所在文件夹（跳转到系统文件App）
    private func 打开所在文件夹() {
        // iOS通过shareddocuments:// URL scheme打开文件App
        if let url = URL(string: "shareddocuments://") {
            UIApplication.shared.open(url, options: [:]) { 成功 in
                if 成功 {
                    文件夹提示 = "已打开文件App，请进入「圈X脚本编辑器」→ QuantumXScripts 文件夹"
                } else {
                    文件夹提示 = "无法打开文件App，请手动前往文件App查看"
                }
                // 3秒后自动隐藏提示
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    文件夹提示 = nil
                }
            }
        }
    }

    /// 确认重命名脚本
    private func 确认重命名() {
        guard let 脚本 = 长按选中脚本 else { return }
        let 新名称 = 重命名输入.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !新名称.isEmpty else {
            视图模型.错误提示 = "脚本名称不能为空"
            return
        }
        do {
            try 视图模型.存储.重命名脚本(脚本, 新名称: 新名称)
            显示重命名弹窗 = false
            长按选中脚本 = nil
            重命名输入 = ""
        } catch {
            视图模型.错误提示 = error.localizedDescription
        }
    }

    /// 确认删除脚本
    private func 确认删除() {
        guard let 脚本 = 长按选中脚本 else { return }
        视图模型.删除脚本(脚本)
        显示删除确认 = false
        长按选中脚本 = nil
    }

    /// 重命名弹窗覆盖层
    private var 重命名弹窗覆盖层: some View {
        Group {
            if 显示重命名弹窗 {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        显示重命名弹窗 = false
                        长按选中脚本 = nil
                    }
                VStack(spacing: 16) {
                    Text("重命名脚本")
                        .font(.headline)
                    TextField("脚本名称", text: $重命名输入)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    HStack(spacing: 12) {
                        Button("取消") {
                            显示重命名弹窗 = false
                            长按选中脚本 = nil
                        }
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)

                        Button("确定") {
                            确认重命名()
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(重命名输入.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(8)
                        .disabled(重命名输入.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(20)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .padding(.horizontal, 32)
                .transition(.scale)
            }
        }
    }

    /// 删除确认弹窗覆盖层
    private var 删除确认覆盖层: some View {
        Group {
            if 显示删除确认, let 脚本 = 长按选中脚本 {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        显示删除确认 = false
                        长按选中脚本 = nil
                    }
                VStack(spacing: 16) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 40)) // 40pt删除图标，醒目提示
                        .foregroundColor(.red)
                    Text("删除脚本")
                        .font(.headline)
                    Text("确定要删除「\(脚本.名称)」吗？此操作不可撤销。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        Button("取消") {
                            显示删除确认 = false
                            长按选中脚本 = nil
                        }
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)

                        Button("删除") {
                            确认删除()
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .cornerRadius(8)
                    }
                }
                .padding(20)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .padding(.horizontal, 32)
                .transition(.scale)
            }
        }
    }

    /// 文件夹提示浮层
    private var 文件夹提示覆盖层: some View {
        Group {
            if let 提示 = 文件夹提示 {
                VStack {
                    Spacer()
                    Text(提示)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(10)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom))
            }
        }
    }
}

// MARK: - 脚本行视图

/// 列表中的单个脚本行
struct 脚本行视图: View {
    let 脚本: 脚本模型

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(脚本.名称)
                .font(.headline)
                .lineLimit(1)
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(格式化时间(脚本.修改时间))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(脚本.内容.count) 字符")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    /// 格式化时间为简短字符串
    private func 格式化时间(_ 日期: Date) -> String {
        let 格式化器 = DateFormatter()
        格式化器.dateFormat = "yyyy-MM-dd HH:mm"
        return 格式化器.string(from: 日期)
    }
}

// MARK: - 空态视图

/// 脚本列表为空时的空态展示
struct 空态视图: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48)) // 48pt大图标，空态视觉焦点
                .foregroundColor(.secondary)
            Text("还没有脚本")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("点击右上角 + 号创建你的第一个圈X脚本")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 新建脚本弹窗

/// 新建脚本输入弹窗（iOS14兼容，自定义弹窗）
struct 新建脚本弹窗: View {
    @ObservedObject var 视图模型: 脚本列表视图模型
    @State private var 输入名称 = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("新建脚本")
                .font(.headline)
            TextField("请输入脚本名称", text: $输入名称)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
            HStack(spacing: 12) {
                Button("取消") {
                    视图模型.显示新建弹窗 = false
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)

                Button("创建") {
                    视图模型.新脚本名称 = 输入名称
                    视图模型.新建脚本()
                    输入名称 = ""
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(输入名称.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.blue)
                .cornerRadius(8)
                .disabled(输入名称.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal, 40)
    }
}

// MARK: - 透明背景（用于sheet透明）

/// 透明背景视图，使sheet背景透明，只显示内容
struct 透明背景: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let 视图 = UIView()
        视图.backgroundColor = .clear
        return 视图
    }
    func updateUIView(_ 视图: UIView, context: Context) {}
}
