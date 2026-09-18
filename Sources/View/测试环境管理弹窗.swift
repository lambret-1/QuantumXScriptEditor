import SwiftUI

/// 测试环境管理弹窗，保存和切换多套URL+请求头组合
struct 测试环境管理弹窗: View {
    /// 测试视图模型
    @ObservedObject var 测试视图模型: 脚本测试视图模型
    /// 退出模式（iOS14兼容）
    @Environment(\.presentationMode) private var 退出模式

    var body: some View {
        NavigationView {
            List {
                // 已保存环境
                Section(header: Text("已保存环境").font(.subheadline)) {
                    if 测试视图模型.环境存储.环境列表.isEmpty {
                        Text("暂无保存的环境")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(测试视图模型.环境存储.环境列表) { 环境 in
                            环境行视图(环境: 环境) {
                                测试视图模型.应用环境(环境)
                                退出模式.wrappedValue.dismiss()
                            }
                        }
                        .onDelete { 索引集 in
                            索引集.forEach { 索引 in
                                测试视图模型.环境存储.删除环境(测试视图模型.环境存储.环境列表[索引])
                            }
                        }
                    }
                }

                // 保存当前为新环境
                Section(header: Text("保存当前为新环境").font(.subheadline)) {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("环境名称（如：测试环境、正式环境）", text: $测试视图模型.新环境名称)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.subheadline)
                        Button(action: {
                            测试视图模型.保存为新环境()
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("保存当前URL和请求头")
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(测试视图模型.新环境名称.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(8)
                        }
                        .disabled(测试视图模型.新环境名称.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("测试环境管理", displayMode: .inline)
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

// MARK: - 环境行视图

/// 单个测试环境行
struct 环境行视图: View {
    let 环境: 测试环境模型
    let 应用动作: () -> Void

    var body: some View {
        Button(action: 应用动作) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(环境.环境名称)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.blue)
                }
                Text(环境.目标网址)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if !环境.请求头.isEmpty {
                    Text("请求头：\(环境.请求头.count)个")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
