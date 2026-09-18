import SwiftUI

/// 更新检测弹窗，展示新版本信息并提供下载入口
struct 更新检测弹窗: View {
    /// 更新信息
    let 更新信息: App更新模型
    /// 是否显示检测中状态
    var 检测中: Bool = false
    /// 关闭回调
    var 关闭回调: (() -> Void)?
    /// 忽略此版本回调
    var 忽略回调: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    if !检测中 {
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

            // 发布说明（可滚动）
            ScrollView {
                Text(更新信息.发布说明)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(maxHeight: 150) // 发布说明最大高度150pt，避免弹窗过高
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)

            // 操作按钮
            VStack(spacing: 10) {
                // 下载更新按钮
                Button(action: {
                    if !更新信息.下载地址.isEmpty {
                        App更新服务.打开下载地址(更新信息.下载地址)
                    } else {
                        App更新服务.打开Release页面(更新信息.页面地址)
                    }
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

                // 查看Release页面
                Button(action: {
                    App更新服务.打开Release页面(更新信息.页面地址)
                }) {
                    Text("查看更新详情")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                // 忽略与关闭
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

// MARK: - 无更新提示弹窗

/// 无更新时的提示弹窗
struct 无更新提示弹窗: View {
    var 关闭回调: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { 关闭回调?() }

            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44)) // 44pt大图标
                    .foregroundColor(.green)
                Text("已是最新版本")
                    .font(.headline)
                Text("当前版本 v\(App更新服务.当前版本号)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("确定") {
                    关闭回调?()
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue)
                .cornerRadius(10)
                .padding(.top, 6)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 60)
        }
    }
}
