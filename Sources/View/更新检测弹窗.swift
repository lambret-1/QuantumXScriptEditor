import SwiftUI

/// 更新检测弹窗，展示新版本信息并提供下载入口
struct 更新检测弹窗: View {
    /// 更新信息
    let 更新信息: App更新模型
    /// 是否显示检测中状态
    var 检测中: Bool = false
    /// 关闭回调
    var 关闭回调: (() -> Void)?
    /// 取消检测回调（检测中点击取消时调用）
    var 取消回调: (() -> Void)?
    /// 忽略此版本回调
    var 忽略回调: (() -> Void)?
    /// 下载完成回调（参数为本地IPA文件URL）
    var 下载完成回调: ((URL) -> Void)?
    /// 下载中状态
    @State private var 下载中 = false
    /// 下载进度（0.0~1.0）
    @State private var 下载进度: Double = 0
    /// 下载失败提示
    @State private var 下载失败 = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    if 检测中 {
                        // 检测中点击背景也可以取消
                        取消回调?()
                        关闭回调?()
                    } else if !下载中 {
                        关闭回调?()
                    }
                }

            VStack(spacing: 16) {
                if 检测中 {
                    检测中视图
                } else {
                    新版本信息视图
                }
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - 检测中视图

    private var 检测中视图: some View {
        VStack(spacing: 16) {
            // iOS14兼容的活动指示器
            活动指示器()
                .frame(width: 40, height: 40) // 40pt加载指示器大小
            Text("正在检测更新...")
                .font(.headline)
            Text("当前版本 v\(App更新服务.当前版本号)")
                .font(.caption)
                .foregroundColor(.secondary)
            // 取消按钮，用户可随时取消检测
            Button(action: {
                取消回调?()
                关闭回调?()
            }) {
                Text("取消")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 20)
    }

    // MARK: - 新版本信息视图

    private var 新版本信息视图: some View {
        VStack(spacing: 14) {
            // 标题图标
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 44)) // 44pt大图标，更新提示视觉焦点
                .foregroundColor(.blue)

            // 版本标题
            VStack(spacing: 4) {
                Text("发现新版本")
                    .font(.headline)
                HStack(spacing: 8) {
                    Text("v\(App更新服务.当前版本号)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .strikethrough()
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("v\(更新信息.版本号)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                if !更新信息.发布时间.isEmpty {
                    Text("发布时间：\(更新信息.发布时间)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // 发布说明（富文本，支持Markdown格式，可滚动）
            ScrollView {
                富文本视图(文本: 更新信息.发布说明, 字体大小: 13)
                    .frame(minHeight: 0) // 自适应内容高度
            }
            .frame(maxHeight: 180) // 发布说明最大高度180pt，富文本需要更多空间
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)

            // 操作按钮
            VStack(spacing: 10) {
                // 下载更新按钮（下载中显示进度条）
                if 下载中 {
                    VStack(spacing: 8) {
                        // 进度条
                        进度条视图(进度: 下载进度)
                            .frame(height: 8) // 进度条高度8pt
                        HStack {
                            Text("正在下载...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(下载进度 * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } else if 下载失败 {
                    // 下载失败状态
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("下载失败，请重试")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        Button(action: {
                            开始下载()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.subheadline)
                                Text("重新下载")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.orange)
                            .cornerRadius(10)
                        }
                    }
                } else {
                    // 正常下载按钮
                    Button(action: {
                        开始下载()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.to.line")
                                .font(.subheadline)
                            Text("下载更新")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                }

                // 查看Release页面
                Button(action: {
                    App更新服务.打开Release页面(更新信息.页面地址)
                }) {
                    Text("查看更新详情")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                // 忽略与关闭（下载中不显示）
                if !下载中 {
                    HStack(spacing: 20) {
                        Button(action: {
                            App更新服务.忽略版本(更新信息.版本号)
                            忽略回调?()
                            关闭回调?()
                        }) {
                            Text("忽略此版本")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Button(action: {
                            关闭回调?()
                        }) {
                            Text("稍后提醒")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 下载逻辑

    /// 开始下载IPA
    private func 开始下载() {
        guard !更新信息.下载地址.isEmpty else {
            下载失败 = true
            return
        }
        下载中 = true
        下载失败 = false
        下载进度 = 0

        App更新服务.下载IPA(
            下载地址: 更新信息.下载地址,
            进度回调: { 进度 in
                下载进度 = 进度
            },
            完成回调: { 文件URL in
                下载中 = false
                if let 文件URL = 文件URL {
                    // 下载完成，回调文件路径，由上层弹出分享面板
                    下载完成回调?(文件URL)
                } else {
                    下载失败 = true
                }
            }
        )
    }
}

// MARK: - 进度条视图

/// 简易进度条（iOS14兼容，不使用ProgressView）
struct 进度条视图: View {
    /// 进度（0.0~1.0）
    let 进度: Double

    var body: some View {
        GeometryReader { 几何 in
            ZStack(alignment: .leading) {
                // 背景轨道
                RoundedRectangle(cornerRadius: 4) // 4pt圆角轨道
                    .fill(Color(UIColor.systemGray5))
                // 进度填充
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue)
                    .frame(width: 几何.size.width * CGFloat(min(max(进度, 0), 1)))
            }
        }
    }
}

// MARK: - 活动指示器（iOS14兼容）

/// 加载活动指示器
struct 活动指示器: UIViewRepresentable {
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let 指示器 = UIActivityIndicatorView(style: .medium)
        指示器.startAnimating()
        return 指示器
    }
    func updateUIView(_ 视图: UIActivityIndicatorView, context: Context) {}
}

// MARK: - 检测失败提示弹窗

/// 更新检测失败时的提示弹窗（区分于"无更新"，网络不佳时显示具体错误原因）
struct 检测失败弹窗: View {
    /// 错误信息
    let 错误信息: String
    /// 重试回调
    var 重试回调: (() -> Void)?
    /// 关闭回调
    var 关闭回调: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .contentShape(Rectangle()) // 确保整个背景可点击
                .onTapGesture { 关闭回调?() }

            VStack(spacing: 14) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 44)) // 44pt大图标，网络错误视觉焦点
                    .foregroundColor(.orange)
                Text("检测更新失败")
                    .font(.headline)
                Text(错误信息)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true) // 自动换行显示完整错误信息

                // 操作按钮
                VStack(spacing: 10) {
                    // 重试按钮
                    Button(action: {
                        重试回调?()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline)
                            Text("重新检测")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle()) // iOS14兼容：去除默认按钮样式

                    // 关闭按钮
                    Button(action: {
                        关闭回调?()
                    }) {
                        Text("关闭")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 48)
        }
        .transition(.opacity) // 快速淡入淡出
    }
}

// MARK: - 无更新提示弹窗

/// 无更新时的提示弹窗
struct 无更新提示弹窗: View {
    var 关闭回调: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .contentShape(Rectangle()) // 确保整个背景可点击
                .onTapGesture { 立即关闭() }

            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44)) // 44pt大图标
                    .foregroundColor(.green)
                Text("已是最新版本")
                    .font(.headline)
                Text("当前版本 v\(App更新服务.当前版本号)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                // 【关键修复】使用明确的Button action + PlainButtonStyle，避免iOS14默认按钮样式导致的点击延迟
                Button(action: {
                    立即关闭()
                }) {
                    Text("确定")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle()) // iOS14兼容：去除默认按钮样式，确保点击立即响应
                .padding(.top, 6)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 60)
        }
        .transition(.opacity) // 快速淡入淡出，避免默认动画延迟
    }

    /// 立即关闭弹窗（确保在主线程同步执行，无延迟）
    private func 立即关闭() {
        关闭回调?()
    }
}
