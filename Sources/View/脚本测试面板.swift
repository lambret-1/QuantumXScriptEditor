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
                    测试视图模型.显示弹窗 = true
                }
                按钮(标题: "环境", 图标: "square.stack", 颜色: Color(UIColor.systemTeal)) {
                    测试视图模型.当前弹窗 = .环境管理
                    测试视图模型.显示弹窗 = true
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

            // 辅助操作行：获取真实响应体（带缓存）+ 清除缓存
            HStack(spacing: 10) {
                if 测试视图模型.正在获取响应体 {
                    // 获取中状态：显示加载和取消
                    Button(action: {
                        测试视图模型.取消获取响应体()
                    }) {
                        HStack(spacing: 4) {
                            活动指示器视图()
                                .frame(width: 14, height: 14) // 14pt小加载指示器
                            Text("请求中...")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8) // 8pt垂直内边距，辅助按钮紧凑
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                } else {
                    // 获取真实响应体按钮
                    Button(action: {
                        测试视图模型.获取真实响应体()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                                .font(.caption)
                            Text(测试视图模型.真实响应体 != nil ? "刷新响应体" : "获取响应体")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8) // 8pt垂直内边距
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }

                // 清除缓存按钮（有缓存时显示）
                if 测试视图模型.真实响应体 != nil {
                    Button(action: {
                        测试视图模型.清除响应体缓存()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.caption)
                            Text("清缓存")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8) // 8pt垂直内边距
                        .background(Color(UIColor.systemGray5))
                        .cornerRadius(8)
                    }
                }

                // 广告分析按钮（一键分析响应体中的广告信息并生成屏蔽脚本）
                Button(action: {
                    测试视图模型.分析广告信息()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.slash")
                            .font(.caption)
                        Text("广告分析")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8) // 8pt垂直内边距
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }

                // 缓存状态指示
                if let 响应体 = 测试视图模型.真实响应体, !响应体.isEmpty {
                    Text("\(响应体.count)字符")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
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

            // 模拟响应体编辑（可折叠，默认折叠，用于离线测试和广告分析，与真实响应体分开）
            if 测试视图模型.展开模拟响应体 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("模拟响应体（JSON，用于离线测试/广告分析）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: {
                            测试视图模型.展开模拟响应体 = false
                        }) {
                            Image(systemName: "chevron.up")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    TextEditor(text: $测试视图模型.模拟响应体文本)
                        .font(.system(size: 12, design: .monospaced)) // 12pt等宽字体，模拟响应体编辑
                        .frame(height: 80) // 80pt高度，足够编辑JSON
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 16)
            } else {
                // 折叠状态显示展开按钮
                HStack {
                    Button(action: {
                        测试视图模型.展开模拟响应体 = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                            Text("模拟响应体")
                                .font(.caption)
                            if !测试视图模型.模拟响应体文本.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("(\(测试视图模型.模拟响应体文本.count)字符)")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
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
                    .frame(minHeight: 应用常量.测试输出最小高度, maxHeight: UIScreen.main.bounds.height * 0.4) // 最小高度+最大高度双重限制，防止无限放大
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        // 复制成功提示浮层
        .overlay(复制成功浮层)
        // 广告分析弹窗覆盖层
        .overlay(广告分析弹窗覆盖层)
        // iOS14兼容：sheet(item:)在iOS14有bug无法弹出，改用isPresented+枚举判断
        .sheet(isPresented: $测试视图模型.显示弹窗) {
            if let 弹窗类型 = 测试视图模型.当前弹窗 {
                switch 弹窗类型 {
                case .网址管理:
                    网址管理弹窗(测试视图模型: 测试视图模型)
                case .环境管理:
                    测试环境管理弹窗(测试视图模型: 测试视图模型)
                }
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

    /// 广告分析弹窗覆盖层
    private var 广告分析弹窗覆盖层: some View {
        Group {
            if 测试视图模型.显示广告分析弹窗 {
                广告分析弹窗(
                    测试视图模型: 测试视图模型,
                    编辑器视图模型: 编辑器视图模型,
                    关闭: {
                        测试视图模型.显示广告分析弹窗 = false
                    }
                )
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

// MARK: - 受限高度UITextView子类（防止intrinsicContentSize无限放大）

/// 受限高度的UITextView子类，重写intrinsicContentSize强制受最大高度限制
/// 解决SwiftUI中UIViewRepresentable包装UITextView时内容过多导致无限放大的问题
class 受限高度文本视图: UITextView {
    /// 最大高度限制，超过后启用内部滚动
    var 最大高度: CGFloat = 300

    /// 重写intrinsicContentSize，返回受最大高度限制的高度，防止SwiftUI布局无限放大
    override var intrinsicContentSize: CGSize {
        let 计算尺寸 = sizeThatFits(CGSize(width: bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width, height: .greatestFiniteMagnitude))
        let 受限高度 = min(计算尺寸.height, 最大高度)
        return CGSize(width: UIView.noIntrinsicMetric, height: 受限高度)
    }
}

// MARK: - 彩色输出视图（UITextView封装，支持文本选择+跟随外部滚动）

/// 彩色测试输出视图，按日志级别着色，支持文本选择复制，内容少时跟随外部ScrollView，内容多时内部滚动
/// 使用受限高度UITextView子类保证不会无限放大，iOS14兼容
struct 彩色输出视图: UIViewRepresentable {
    /// 输出文本
    let 输出文本: String
    /// 是否自动滚动到底部
    let 自动滚动: Bool
    /// 是否自动换行
    let 自动换行: Bool

    func makeUIView(context: Context) -> UITextView {
        let 文本视图 = 受限高度文本视图()
        文本视图.最大高度 = UIScreen.main.bounds.height * 0.4 // 最大高度为屏幕高度的40%，防止超出屏幕
        文本视图.isEditable = false // 不可编辑，仅可选择
        文本视图.isSelectable = true // 开启文本选择，用户可长按选中复制
        文本视图.isScrollEnabled = false // 默认禁用内部滚动，让高度自适应内容，跟随外部ScrollView一起滑动
        文本视图.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular) // 12pt等宽字体，控制台输出风格
        文本视图.backgroundColor = .systemBackground
        文本视图.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8) // 内边距8pt
        文本视图.autoresizingMask = [.flexibleWidth]
        return 文本视图
    }

    func updateUIView(_ 文本视图: UITextView, context: Context) {
        // 转换为受限高度子类
        guard let 受限视图 = 文本视图 as? 受限高度文本视图 else { return }

        // 设置自动换行
        受限视图.textContainer.lineBreakMode = 自动换行 ? .byWordWrapping : .byClipping

        if 输出文本.isEmpty {
            // 空态提示
            let 提示属性: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel
            ]
            受限视图.attributedText = NSAttributedString(string: "点击「运行测试」执行脚本，输出将显示在这里...", attributes: 提示属性)
            受限视图.isScrollEnabled = false
            受限视图.invalidateIntrinsicContentSize() // 通知SwiftUI重新计算布局
            return
        }

        // 生成彩色属性文本（按行着色）
        let 属性文本 = NSMutableAttributedString()
        let 行列表 = 输出文本.components(separatedBy: "\n")
        for (索引, 行) in 行列表.enumerated() {
            let 显示文本 = 行.isEmpty ? " " : 行
            let 行属性: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: 行颜色(行)
            ]
            属性文本.append(NSAttributedString(string: 显示文本, attributes: 行属性))
            if 索引 < 行列表.count - 1 {
                属性文本.append(NSAttributedString(string: "\n", attributes: 行属性))
            }
        }
        受限视图.attributedText = 属性文本

        // 计算内容高度，根据是否超过最大高度动态切换滚动模式
        DispatchQueue.main.async {
            let 计算尺寸 = 受限视图.sizeThatFits(CGSize(width: 受限视图.bounds.width, height: .greatestFiniteMagnitude))
            if 计算尺寸.height > 受限视图.最大高度 {
                // 内容超过最大高度：启用内部滚动，固定最大高度，防止超出屏幕
                受限视图.isScrollEnabled = true
            } else {
                // 内容不超过最大高度：禁用内部滚动，高度自适应内容，跟随外部ScrollView一起滑动
                受限视图.isScrollEnabled = false
            }
            受限视图.invalidateIntrinsicContentSize() // 通知SwiftUI重新计算布局
        }

        // 自动滚动到底部
        if 自动滚动 && 属性文本.length > 0 {
            DispatchQueue.main.async {
                if 受限视图.isScrollEnabled {
                    // 内部滚动模式：直接滚动到末尾
                    let 底部范围 = NSMakeRange(属性文本.length - 1, 1)
                    受限视图.scrollRangeToVisible(底部范围)
                } else {
                    // 外部滚动模式：通过选中末尾触发外部ScrollView自动滚动到可见区域
                    let 末尾范围 = NSMakeRange(属性文本.length - 1, 0)
                    受限视图.selectedRange = 末尾范围
                    // 延迟清除选中，避免视觉干扰
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        受限视图.selectedRange = NSMakeRange(NSNotFound, 0)
                    }
                }
            }
        }
    }

    /// 根据行内容前缀返回对应颜色（UIColor版本，用于NSAttributedString）
    private func 行颜色(_ 行: String) -> UIColor {
        if 行.hasPrefix("[JS错误]") || 行.hasPrefix("[网络错误]") || 行.hasPrefix("[超时]") || 行.hasPrefix("❌") {
            return .red
        } else if 行.hasPrefix("[通知]") {
            return .systemBlue
        } else if 行.hasPrefix("[网络请求]") || 行.hasPrefix("[请求头]") || 行.hasPrefix("[请求体]") {
            return .orange
        } else if 行.hasPrefix("[响应头]") || 行.hasPrefix("[响应体]") || 行.hasPrefix("[网络响应]") || 行.hasPrefix("[输入响应体]") {
            return .systemTeal
        } else if 行.hasPrefix("[完成]") {
            return .systemGreen
        } else if 行.hasPrefix("[修改后响应体]") {
            return .systemGreen
        } else if 行.hasPrefix("[状态码]") {
            return .systemOrange
        } else if 行.hasPrefix("[容错]") || 行.hasPrefix("[降级]") || 行.hasPrefix("[兜底]") {
            return .systemYellow
        } else if 行.hasPrefix("[日志]") {
            return .systemGray
        } else if 行.hasPrefix("[耗时]") {
            return .purple
        } else if 行.hasPrefix("[已停止]") {
            return .red
        } else if 行.hasPrefix("==========") {
            return .secondaryLabel
        } else if 行.hasPrefix("目标网址：") || 行.hasPrefix("请求方法：") || 行.hasPrefix("请求头：") || 行.hasPrefix("模拟响应体：") {
            return .secondaryLabel
        }
        return .label
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
            .contentShape(Rectangle()) // iOS14兼容：确保整个按钮区域可点击，避免点击边缘无反应
        }
        .buttonStyle(PlainButtonStyle()) // iOS14兼容：去除默认按钮样式，避免点击高亮异常
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
