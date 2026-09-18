import SwiftUI

/// JS脚本测试面板，提供URL输入、请求头编辑、环境管理、沙箱执行与输出
struct 脚本测试面板: View {
    /// 编辑器视图模型（获取脚本内容）
    @ObservedObject var 编辑器视图模型: 脚本编辑器视图模型
    /// 测试视图模型
    @ObservedObject var 测试视图模型: 脚本测试视图模型

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 面板标题
            HStack {
                Image(systemName: "play.circle")
                    .foregroundColor(.blue)
                Text("JS脚本测试")
                    .font(.headline)
                Spacer()
                if 测试视图模型.正在执行 {
                    活动指示器视图()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // URL输入行
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .foregroundColor(.secondary)
                    .frame(width: 20) // 20pt图标宽度，对齐输入框
                TextField("输入测试网址，如 https://httpbin.org/get", text: $测试视图模型.目标网址)
                    .font(.system(size: 14))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
            }
            .padding(.horizontal, 16)

            // 操作按钮行
            HStack(spacing: 10) {
                按钮(标题: "地址库", 图标: "bookmark", 颜色: .purple) {
                    测试视图模型.显示网址管理 = true
                }
                按钮(标题: "环境", 图标: "square.stack", 颜色: Color(UIColor.systemTeal)) {
                    测试视图模型.显示环境管理 = true
                }
                Spacer()
                按钮(标题: "清空", 图标: "trash", 颜色: .gray) {
                    测试视图模型.清空输出()
                }
                按钮(标题: 测试视图模型.正在执行 ? "执行中..." : "运行测试", 图标: "play.fill", 颜色: .green) {
                    测试视图模型.执行测试(脚本内容: 编辑器视图模型.脚本.内容)
                }
                .disabled(测试视图模型.正在执行)
            }
            .padding(.horizontal, 16)

            // 请求头编辑
            VStack(alignment: .leading, spacing: 6) {
                Text("请求头（key:value，一行一个）")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $测试视图模型.请求头文本)
                    .font(.system(size: 12, design: .monospaced)) // 12pt等宽字体，请求头编辑
                    .frame(height: 应用常量.请求头编辑高度) // 固定高度，控制Header区域大小
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 16)

            // 测试输出
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("测试输出")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(测试视图模型.测试输出.count) 字符")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                ScrollView {
                    Text(测试视图模型.测试输出.isEmpty ? "点击「运行测试」执行脚本，输出将显示在这里..." : 测试视图模型.测试输出)
                        .font(.system(size: 12, design: .monospaced)) // 12pt等宽字体，控制台输出风格
                        .foregroundColor(测试视图模型.测试输出.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(minHeight: 应用常量.测试输出最小高度) // 最小高度，保证输出区域可视
                .background(Color(.systemGray6))
                .cornerRadius(6)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $测试视图模型.显示网址管理) {
            网址管理弹窗(测试视图模型: 测试视图模型)
        }
        .sheet(isPresented: $测试视图模型.显示环境管理) {
            测试环境管理弹窗(测试视图模型: 测试视图模型)
        }
    }
}

// MARK: - 通用按钮

/// 测试面板通用按钮
private struct 按钮: View {
    let 标题: String
    let 图标: String
    let 颜色: Color
    let 动作: () -> Void

    var body: some View {
        Button(action: 动作) {
            HStack(spacing: 4) {
                Image(systemName: 图标)
                    .font(.system(size: 12)) // 12pt小图标
                Text(标题)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(颜色)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(颜色.opacity(0.12))
            .cornerRadius(6)
        }
        .disabled(false)
    }
}

// MARK: - 活动指示器（iOS14兼容）

/// 加载活动指示器
struct 活动指示器视图: UIViewRepresentable {
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let 指示器 = UIActivityIndicatorView(style: .medium)
        指示器.startAnimating()
        return 指示器
    }
    func updateUIView(_ 视图: UIActivityIndicatorView, context: Context) {}
}
