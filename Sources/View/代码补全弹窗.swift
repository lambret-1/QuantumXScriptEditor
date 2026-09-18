import SwiftUI

/// 代码补全弹窗，手动触发时展示全部补全项，支持搜索过滤
struct 代码补全弹窗: View {
    /// 编辑器视图模型
    @ObservedObject var 视图模型: 脚本编辑器视图模型
    /// 搜索关键词
    @State private var 搜索词 = ""
    /// 退出模式（iOS14兼容）
    @Environment(\.presentationMode) private var 退出模式

    /// 过滤后的补全项
    private var 过滤后列表: [代码补全项] {
        if 搜索词.trimmingCharacters(in: .whitespaces).isEmpty {
            return 代码补全服务.全部候选项
        }
        return 代码补全服务.过滤候选项(前缀: 搜索词)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索API或说明", text: $搜索词)
                        .font(.subheadline)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    if !搜索词.isEmpty {
                        Button(action: { 搜索词 = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // 补全项列表
                List {
                    ForEach(过滤后列表) { 项 in
                        补全项行视图(项: 项) {
                            视图模型.插入补全项(项)
                            退出模式.wrappedValue.dismiss()
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationBarTitle("代码补全", displayMode: .inline)
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

// MARK: - 补全项行视图

/// 单个补全项行
struct 补全项行视图: View {
    let 项: 代码补全项
    let 插入动作: () -> Void

    var body: some View {
        Button(action: 插入动作) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(项.触发词)
                        .font(.system(size: 15, design: .monospaced)) // 15pt等宽字体，API名醒目
                        .foregroundColor(Color(UIColor.systemBlue))
                    Spacer()
                    Text(项.分类.rawValue)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.6))
                        .cornerRadius(4)
                }
                Text(项.中文说明)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                // 插入代码预览
                Text(项.插入代码.prefix(60))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(4)
                    .background(Color(.systemGray6))
                    .cornerRadius(4)
            }
            .padding(.vertical, 4)
        }
    }
}
