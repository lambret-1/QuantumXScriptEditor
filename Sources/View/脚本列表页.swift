import SwiftUI

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
    /// 下载完成后要分享的IPA文件URL
    @State private var 分享文件URL: URL?
    /// 是否显示分享面板
    @State private var 显示分享面板 = false

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
        // 分享面板（下载IPA完成后弹出）
        .sheet(isPresented: $显示分享面板) {
            if let 文件URL = 分享文件URL {
                分享面板视图(文件URL: 文件URL) {
                    显示分享面板 = false
                    分享文件URL = nil
                }
                .background(透明背景()) // 透明背景，只显示系统分享面板
            }
        }
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
                更新检测弹窗(更新信息: App更新模型(版本号: "", 标签: "", 发布说明: "", 下载地址: "", 页面地址: "", 发布时间: ""), 检测中: true)
            } else if 显示更新弹窗, let 信息 = 更新信息 {
                更新检测弹窗(更新信息: 信息, 关闭回调: {
                    显示更新弹窗 = false
                }, 下载完成回调: { 文件URL in
                    分享文件URL = 文件URL
                    显示更新弹窗 = false
                    显示分享面板 = true
                })
            } else if 显示无更新弹窗 {
                无更新提示弹窗 {
                    显示无更新弹窗 = false
                }
            }
        }
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
