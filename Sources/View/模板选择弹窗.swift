import SwiftUI

/// 脚本模板选择弹窗，按分类展示模板，点击插入到编辑器
struct 模板选择弹窗: View {
    /// 编辑器视图模型
    @ObservedObject var 视图模型: 脚本编辑器视图模型
    /// 当前选中的分类
    @State private var 选中分类: 圈X代码模板.模板分类? = nil
    /// 退出模式（iOS14兼容）
    @Environment(\.presentationMode) private var 退出模式

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 分类选择横向滚动条
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        分类按钮(标题: "全部", 选中: 选中分类 == nil) {
                            选中分类 = nil
                        }
                        ForEach(圈X代码模板.模板分类.allCases, id: \.self) { 分类 in
                            分类按钮(标题: 分类.rawValue, 选中: 选中分类 == 分类) {
                                选中分类 = 分类
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(Color(.systemGray6))

                // 模板列表
                List {
                    ForEach(圈X代码模板.按分类筛选(分类: 选中分类)) { 模板 in
                        模板行视图(模板: 模板) {
                            视图模型.插入模板(模板)
                            退出模式.wrappedValue.dismiss()
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationBarTitle("脚本模板库", displayMode: .inline)
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

// MARK: - 分类按钮

/// 模板分类筛选按钮
struct 分类按钮: View {
    let 标题: String
    let 选中: Bool
    let 动作: () -> Void

    var body: some View {
        Button(action: 动作) {
            Text(标题)
                .font(.subheadline)
                .fontWeight(选中 ? .semibold : .regular)
                .foregroundColor(选中 ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(选中 ? Color.blue : Color(.systemGray5))
                .cornerRadius(16) // 16pt圆角，胶囊形分类按钮
        }
    }
}

// MARK: - 模板行视图

/// 单个模板行，展示标题、用途、场景，点击插入
struct 模板行视图: View {
    let 模板: 圈X代码模板
    let 插入动作: () -> Void

    var body: some View {
        Button(action: 插入动作) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(模板.标题)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "square.and.arrow.down")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                Text(模板.用途说明)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Text("场景：\(模板.使用场景)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                // 代码预览
                Text(模板.代码.prefix(80) + "...")
                    .font(.system(size: 11, design: .monospaced)) // 11pt等宽字体，代码预览
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(6)
                    .background(Color(.systemGray6))
                    .cornerRadius(4)
            }
            .padding(.vertical, 4)
        }
    }
}
