import SwiftUI

/// JS脚本测试面板，提供URL输入、方法选择、请求头/体编辑、环境管理、沙箱执行与彩色输出
struct 脚本测试面板: View {
    /// 编辑器视图模型（获取脚本内容）
    @ObservedObject var 编辑器视图模型: 脚本编辑器视图模型
    /// 测试视图模型
    @ObservedObject var 测试视图模型: 脚本测试视图模型
    /// 网址是否已被用户首次编辑（用于点击清除默认网址）
    @State private var 网址已首次编辑 = false
    /// 请求头区域是否展开（默认折叠）
    @State private var 请求头已展开 = false

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
                if let 耗时 = 测试视图模型.最后耗时, !测试视图模型.正在执行 {
                    Text("耗时 \(String(format: "%.2f", 耗时))s")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // HTTP方法选择器
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(测试视图模型.可用方法, id: \.self) { 方法 in
                        Button(action: {
                            测试视图模型.请求方法 = 方法
                            // 请求体默认折叠，不随方法切换自动展开，用户手动展开
                        }) {
                            Text(方法)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(测试视图模型.请求方法 == 方法 ? .white : 方法颜色(方法))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(测试视图模型.请求方法 == 方法 ? 方法颜色(方法) : 方法颜色(方法).opacity(0.12))
                                .cornerRadius(6)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // URL输入行（默认显示测试网址，首次点击编辑时自动清除）
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .foregroundColor(.secondary)
                    .frame(width: 20) // 20pt图标宽度，对齐输入框
                TextField("输入测试网址，如 https://httpbin.org/get",
                          text: $测试视图模型.目标网址,
                          onEditingChanged: { 正在编辑 in
                              // 首次进入编辑状态时自动清除默认网址，方便用户重新输入
                              if 正在编辑 && !网址已首次编辑 {
                                  测试视图模型.目标网址 = ""
                                  网址已首次编辑 = true
                              }
                          })
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
                    测试视图模型.当前弹窗 = .网址管理
                }
                按钮(标题: "环境", 图标: "square.stack", 颜色: Color(UIColor.systemTeal)) {
                    测试视图模型.当前弹窗 = .环境管理
                }
                Spacer()
                按钮(标题: "清空", 图标: "trash", 颜色: .gray) {
                    测试视图模型.清空输出()
                }
                if 测试视图模型.正在执行 {
                    按钮(标题: "停止", 图标: "stop.fill", 颜色: .red) {
                        测试视图模型.停止执行()
                    }
                } else {
                    按钮(标题: "运行测试", 图标: "play.fill", 颜色: .green) {
                        测试视图模型.执行测试(脚本内容: 编辑器视图模型.脚本.内容)
                    }
                }
            }
            .padding(.horizontal, 16)

            // 请求体编辑（可折叠，POST/PUT/PATCH时默认展开）
            if 测试视图模型.展开请求体 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("请求体（JSON/文本）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: {
                            测试视图模型.展开请求体 = false
                        }) {
                            Image(systemName: "chevron.up")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    TextEditor(text: $测试视图模型.请求体文本)
                        .font(.system(size: 12, design: .monospaced)) // 12pt等宽字体，请求体编辑
                        .frame(height: 80) // 80pt高度，足够编辑JSON
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 16)
            } else {
                // 折叠状态显示展开按钮
                HStack {
                    Button(action: {
                        测试视图模型.展开请求体 = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                            Text("请求体")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
            }

            // 请求头编辑（可折叠，默认折叠）
            VStack(alignment: .leading, spacing: 6) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { // 0.2秒展开/收起动画，流畅自然
                        请求头已展开.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: 请求头已展开 ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("请求头（key:value，一行一个）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if !请求头已展开 && !测试视图模型.请求头文本.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("（已配置）")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        Spacer()
                    }
                }
                if 请求头已展开 {
                    TextEditor(text: $测试视图模型.请求头文本)
                        .font(.system(size: 12, design: .monospaced)) // 12pt等宽字体，请求头编辑
                        .frame(height: 应用常量.请求头编辑高度) // 固定高度，控制Header区域大小
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .transition(.opacity) // 淡入淡出过渡，展开收起更柔和
                }
            }
            .padding(.horizontal, 16)

            // 测试输出（彩色 + 自动滚动 + 复制/分享/清空 + 行数统计）
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("测试输出")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    // 自动滚动开关
                    Button(action: {
                        测试视图模型.自动滚动.toggle()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: 测试视图模型.自动滚动 ? "arrow.down.circle.fill" : "arrow.down.circle")
                                .font(.caption2)
                            Text("滚动")
                                .font(.caption2)
                        }
                        .foregroundColor(测试视图模型.自动滚动 ? .blue : .secondary)
                    }
                    // 自动换行开关
                    Button(action: {
                        测试视图模型.自动换行.toggle()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: 测试视图模型.自动换行 ? "text.word.spacing" : "text.alignleft")
                                .font(.caption2)
                            Text("换行")
                                .font(.caption2)
                        }
                        .foregroundColor(测试视图模型.自动换行 ? .blue : .secondary)
                    }
                    if !测试视图模型.测试输出.isEmpty {
                        // 复制按钮
                        Button(action: {
                            测试视图模型.复制输出()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption2)
                                Text("复制")
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                        }
                        // 分享按钮
                        Button(action: {
                            测试视图模型.分享输出()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.caption2)
                                Text("分享")
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                        }
                        // 清空按钮
                        Button(action: {
                            测试视图模型.清空输出()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "trash")
                                    .font(.caption2)
                                Text("清空")
                                    .font(.caption2)
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                // 统计信息行
                if !测试视图模型.测试输出.isEmpty {
                    HStack(spacing: 12) {
                        Text("\(测试视图模型.输出行数) 行")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(测试视图模型.测试输出.count) 字符")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if let 耗时 = 测试视图模型.最后耗时 {
                            Text("耗时 \(String(format: "%.3f", 耗时))s")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                // 彩色输出区域，自动滚动到底部
                彩色输出视图(输出文本: 测试视图模型.测试输出, 自动滚动: 测试视图模型.自动滚动, 自动换行: 测试视图模型.自动换行)
                    .frame(minHeight: 应用常量.测试输出最小高度) // 最小高度，保证输出区域可视
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        // 复制成功提示浮层
        .overlay(复制成功浮层)
        // iOS14兼容：单sheet+枚举，避免多sheet并列时只有一个能弹出的bug
        .sheet(item: $测试视图模型.当前弹窗) { 弹窗类型 in
            switch 弹窗类型 {
            case .网址管理:
                网址管理弹窗(测试视图模型: 测试视图模型)
            case .环境管理:
                测试环境管理弹窗(测试视图模型: 测试视图模型)
            }
        }
    }

    // MARK: - 辅助视图

    /// 复制成功提示浮层
    private var 复制成功浮层: some View {
        Group {
            if 测试视图模型.显示复制成功 {
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("已复制到剪贴板")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(8)
                    .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom))
            }
        }
    }

    /// 根据HTTP方法返回对应颜色
    private func 方法颜色(_ 方法: String) -> Color {
        switch 方法 {
        case "GET": return .green
        case "POST": return .blue
        case "PUT": return .orange
        case "DELETE": return .red
        case "PATCH": return .purple
        default: return .gray
        }
    }
}

// MARK: - 彩色输出视图（自动滚动到底部）

/// 彩色测试输出视图，按日志级别着色，自动滚动到最新内容
struct 彩色输出视图: View {
    /// 输出文本
    let 输出文本: String
    /// 是否自动滚动到底部
    let 自动滚动: Bool
    /// 是否自动换行
    let 自动换行: Bool
    /// 滚动视图底部锚点ID
    private let 底部锚点 = "底部锚点"

    var body: some View {
        ScrollViewReader { 代理 in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if 输出文本.isEmpty {
                        Text("点击「运行测试」执行脚本，输出将显示在这里...")
                            .font(.system(size: 12, design: .monospaced)) // 12pt等宽字体，控制台输出风格
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(Array(输出文本.components(separatedBy: "\n").enumerated()), id: \.offset) { 索引, 行 in
                            Text(行.isEmpty ? " " : 行)
                                .font(.system(size: 12, design: .monospaced)) // 12pt等宽字体，控制台输出风格
                                .foregroundColor(行颜色(行))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: !自动换行, vertical: false) // 控制是否自动换行
                        }
                    }
                    // 底部锚点，用于自动滚动
                    Color.clear
                        .frame(height: 1)
                        .id(底部锚点)
                }
                .padding(8)
            }
            .onChange(of: 输出文本) { _ in
                // 输出变化时自动滚动到底部（仅当自动滚动开启时）
                if 自动滚动 {
                    withAnimation(.easeOut(duration: 0.2)) {
                        代理.scrollTo(底部锚点, anchor: .bottom)
                    }
                }
            }
        }
    }

    /// 根据行内容前缀返回对应颜色
    private func 行颜色(_ 行: String) -> Color {
        if 行.hasPrefix("[JS错误]") || 行.hasPrefix("[网络错误]") || 行.hasPrefix("[超时]") || 行.hasPrefix("❌") {
            return .red
        } else if 行.hasPrefix("[通知]") {
            return Color(UIColor.systemBlue)
        } else if 行.hasPrefix("[网络请求]") || 行.hasPrefix("[请求头]") || 行.hasPrefix("[请求体]") {
            return .orange
        } else if 行.hasPrefix("[响应头]") || 行.hasPrefix("[响应体]") || 行.hasPrefix("[网络响应]") || 行.hasPrefix("[输入响应体]") {
            return Color(UIColor.systemTeal)
        } else if 行.hasPrefix("[完成]") {
            return .green
        } else if 行.hasPrefix("[修改后响应体]") {
            return Color(UIColor.systemGreen) // 修改后响应体用绿色，突出显示输出结果
        } else if 行.hasPrefix("[状态码]") {
            return Color(UIColor.systemOrange)
        } else if 行.hasPrefix("[容错]") || 行.hasPrefix("[降级]") || 行.hasPrefix("[兜底]") {
            return Color(UIColor.systemYellow) // 容错日志用黄色
        } else if 行.hasPrefix("[日志]") {
            return Color(UIColor.systemGray)
        } else if 行.hasPrefix("[耗时]") {
            return .purple
        } else if 行.hasPrefix("[已停止]") {
            return .red
        } else if 行.hasPrefix("==========") {
            return .secondary
        } else if 行.hasPrefix("目标网址：") || 行.hasPrefix("请求方法：") || 行.hasPrefix("请求头：") || 行.hasPrefix("模拟响应体：") {
            return .secondary
        }
        return .primary
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
