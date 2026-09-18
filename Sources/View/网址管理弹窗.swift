import SwiftUI

/// 网址管理弹窗，管理收藏与历史记录，支持收藏切换、删除、清空历史
struct 网址管理弹窗: View {
    /// 测试视图模型
    @ObservedObject var 测试视图模型: 脚本测试视图模型
    /// 退出模式（iOS14兼容）
    @Environment(\.presentationMode) private var 退出模式

    var body: some View {
        NavigationView {
            List {
                // 收藏区域
                Section(header: 标签头(标题: "⭐ 收藏地址", 图标: "star.fill")) {
                    if 测试视图模型.网址存储.收藏列表.isEmpty {
                        空行提示(文本: "暂无收藏地址，左滑历史记录可收藏")
                    } else {
                        ForEach(测试视图模型.网址存储.收藏列表) { 记录 in
                            网址记录行(记录: 记录, 测试视图模型: 测试视图模型) {
                                测试视图模型.目标网址 = 记录.网址
                                退出模式.wrappedValue.dismiss()
                            }
                        }
                        .onDelete { 索引集 in
                            索引集.forEach { 索引 in
                                测试视图模型.网址存储.删除记录(测试视图模型.网址存储.收藏列表[索引])
                            }
                        }
                    }
                }

                // 历史区域
                Section(header: HStack {
                    标签头(标题: "🕒 历史记录", 图标: "clock")
                    Spacer()
                    if !测试视图模型.网址存储.历史列表.isEmpty {
                        Button("清空") {
                            测试视图模型.网址存储.清空历史()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }) {
                    if 测试视图模型.网址存储.历史列表.isEmpty {
                        空行提示(文本: "暂无历史记录")
                    } else {
                        ForEach(测试视图模型.网址存储.历史列表) { 记录 in
                            网址记录行(记录: 记录, 测试视图模型: 测试视图模型) {
                                测试视图模型.目标网址 = 记录.网址
                                退出模式.wrappedValue.dismiss()
                            }
                        }
                        .onDelete { 索引集 in
                            索引集.forEach { 索引 in
                                测试视图模型.网址存储.删除记录(测试视图模型.网址存储.历史列表[索引])
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("地址管理", displayMode: .inline)
            .navigationBarItems(trailing:
                Button("关闭") {
                    退出模式.wrappedValue.dismiss()
                }
                .font(.subheadline)
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - 网址记录行

/// 单条网址记录行
struct 网址记录行: View {
    let 记录: 网址记录模型
    @ObservedObject var 测试视图模型: 脚本测试视图模型
    let 使用动作: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // 收藏按钮
            Button(action: {
                测试视图模型.网址存储.切换收藏(记录)
            }) {
                Image(systemName: 记录.是否已收藏 ? "star.fill" : "star")
                    .foregroundColor(记录.是否已收藏 ? .yellow : .gray)
                    .frame(width: 24, height: 24) // 24pt点击区域，确保易点击
            }
            // 网址文本
            VStack(alignment: .leading, spacing: 2) {
                Text(记录.网址)
                    .font(.system(size: 14)) // 14pt网址文本
                    .lineLimit(1)
                    .foregroundColor(.primary)
                Text(格式化时间(记录.使用时间))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            // 使用按钮
            Button("使用") {
                使用动作()
            }
            .font(.subheadline)
            .foregroundColor(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(6)
        }
        .padding(.vertical, 2)
    }

    private func 格式化时间(_ 日期: Date) -> String {
        let 格式化器 = DateFormatter()
        格式化器.dateFormat = "MM-dd HH:mm"
        return 格式化器.string(from: 日期)
    }
}

// MARK: - 辅助视图

/// 分区标签头
struct 标签头: View {
    let 标题: String
    let 图标: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: 图标)
                .font(.caption)
            Text(标题)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

/// 空行提示
struct 空行提示: View {
    let 文本: String

    var body: some View {
        Text(文本)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
    }
}
