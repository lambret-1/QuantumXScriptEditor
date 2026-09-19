import SwiftUI

/// 脚本编辑器页面，包含工具栏、编辑器、静态检查、测试面板
struct 脚本编辑器页: View {
    /// 编辑器视图模型
    @StateObject private var 视图模型: 脚本编辑器视图模型
    /// 测试面板视图模型
    @StateObject private var 测试视图模型 = 脚本测试视图模型()
    /// 是否使用自定义代码键盘（默认false，使用系统键盘）
    @State private var 使用代码键盘 = false
    /// 是否显示智能分析弹窗
    @State private var 显示智能分析 = false
    /// 是否显示新手教程弹窗（使用overlay覆盖层，避免sheet自带背景造成多余窗口）
    @State private var 显示新手教程 = false

    init(脚本: 脚本模型, 存储: 脚本存储) {
        _视图模型 = StateObject(wrappedValue: 脚本编辑器视图模型(脚本: 脚本, 存储: 存储))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 顶部工具栏
                工具栏视图(视图模型: 视图模型, 使用代码键盘: $使用代码键盘, 显示智能分析: $显示智能分析, 显示新手教程: $显示新手教程)

                // 保存/格式化提示条
                if let 提示 = 视图模型.保存提示 {
                    提示条视图(文本: 提示, 颜色: .green)
                }
                if let 提示 = 视图模型.格式化提示 {
                    提示条视图(文本: 提示, 颜色: .blue)
                }

                // 静态检查结果
                if let 结果 = 视图模型.检查结果 {
                    静态检查结果视图(结果: 结果)
                }

                // 代码编辑器（固定高度，避免ScrollView嵌套滚动问题）
                带行号代码编辑器(文本: $视图模型.脚本.内容, 字体大小: 视图模型.字体大小, 使用代码键盘: $使用代码键盘)
                    .frame(height: 420) // 编辑器固定高度420pt，内部可滚动，外部页面也可滚动

                // 编辑器操作栏：字体缩小/增大 + 一键删除 + 一键复制
                编辑器操作栏视图(视图模型: 视图模型)

                // JS测试面板
                脚本测试面板(编辑器视图模型: 视图模型, 测试视图模型: 测试视图模型)
            }
        }
        .navigationBarTitle(视图模型.脚本.名称, displayMode: .inline)
        .navigationBarItems(trailing:
            Button("重命名") {
                视图模型.重命名输入 = 视图模型.脚本.名称
                视图模型.显示重命名弹窗 = true
            }
            .font(.subheadline)
        )
        // iOS14兼容：sheet(item:)在iOS14有bug无法弹出，改用isPresented+枚举判断
        .sheet(isPresented: $视图模型.显示弹窗) {
            if let 弹窗类型 = 视图模型.当前弹窗 {
                switch 弹窗类型 {
                case .模板:
                    模板选择弹窗(视图模型: 视图模型)
                case .补全:
                    代码补全弹窗(视图模型: 视图模型)
                }
            }
        }
        // 重命名输入覆盖层（iOS14 Alert不支持TextField，使用自定义覆盖层）
        .overlay(重命名覆盖层)
        // 智能分析弹窗覆盖层
        .overlay(智能分析覆盖层)
        // 新手教程弹窗覆盖层（使用overlay而非sheet，避免sheet自带背景造成多余窗口）
        .overlay(新手教程覆盖层)
    }

    /// 重命名输入弹窗覆盖层
    private var 重命名覆盖层: some View {
        Group {
            if 视图模型.显示重命名弹窗 {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        视图模型.显示重命名弹窗 = false
                    }
                重命名弹窗(视图模型: 视图模型)
                    .transition(.scale)
            }
        }
    }

    /// 智能分析弹窗覆盖层
    private var 智能分析覆盖层: some View {
        Group {
            if 显示智能分析 {
                智能分析弹窗(
                    插入回调: { 模板代码 in
                        // 将生成的模板追加到代码区末尾
                        if 视图模型.脚本.内容.isEmpty {
                            视图模型.脚本.内容 = 模板代码
                        } else {
                            视图模型.脚本.内容 += "\n\n" + 模板代码
                        }
                    },
                    关闭回调: {
                        显示智能分析 = false
                    }
                )
            }
        }
    }

    /// 新手教程弹窗覆盖层（使用overlay而非sheet，避免sheet自带背景造成多余窗口）
    private var 新手教程覆盖层: some View {
        Group {
            if 显示新手教程 {
                新手教程弹窗(关闭回调: {
                    显示新手教程 = false
                })
            }
        }
    }
}

// MARK: - 工具栏视图

/// 编辑器顶部工具栏
struct 工具栏视图: View {
    @ObservedObject var 视图模型: 脚本编辑器视图模型
    /// 是否使用自定义代码键盘绑定
    @Binding var 使用代码键盘: Bool
    /// 是否显示智能分析弹窗绑定
    @Binding var 显示智能分析: Bool
    /// 是否显示新手教程弹窗绑定
    @Binding var 显示新手教程: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 代码键盘开关（顶部工具栏，手动切换）
                Button(action: {
                    使用代码键盘.toggle()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: 使用代码键盘 ? "keyboard.fill" : "keyboard")
                            .font(.system(size: 14)) // 14pt图标，与文字对齐
                        Text(使用代码键盘 ? "代码键盘" : "系统键盘")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(使用代码键盘 ? .white : Color(UIColor.systemIndigo))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(使用代码键盘 ? Color(UIColor.systemIndigo) : Color(UIColor.systemIndigo).opacity(0.12))
                    .cornerRadius(8)
                }
                工具按钮(标题: "保存", 图标: "square.and.arrow.down", 颜色: .blue) {
                    视图模型.保存脚本()
                }
                工具按钮(标题: "模板", 图标: "square.grid.2x2", 颜色: .purple) {
                    视图模型.当前弹窗 = .模板
                    视图模型.显示弹窗 = true
                }
                工具按钮(标题: "补全", 图标: "textformat", 颜色: .orange) {
                    视图模型.当前弹窗 = .补全
                    视图模型.显示弹窗 = true
                }
                工具按钮(标题: "教程", 图标: "book.fill", 颜色: Color(UIColor.systemTeal)) {
                    显示新手教程 = true
                }
                工具按钮(标题: "获取信息", 图标: "wand.and.stars", 颜色: Color(UIColor.systemPurple)) {
                    显示智能分析 = true
                }
                工具按钮(标题: "格式化", 图标: "text.alignleft", 颜色: .green) {
                    视图模型.执行格式化()
                }
                工具按钮(标题: "检查", 图标: "checkmark.shield", 颜色: .red) {
                    视图模型.执行静态检查()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGray6))
    }
}

// MARK: - 编辑器操作栏视图

/// 编辑器下方操作栏：字体缩小/增大 + 一键删除 + 一键复制
struct 编辑器操作栏视图: View {
    @ObservedObject var 视图模型: 脚本编辑器视图模型
    /// 可用字号列表（从小到大）
    private let 可用字号: [CGFloat] = [10, 11, 12, 13, 14, 15, 16, 17, 18, 20, 22, 24]

    var body: some View {
        HStack(spacing: 10) {
            // 字体缩小按钮（A-）
            Button(action: {
                if let 当前索引 = 可用字号.firstIndex(of: 视图模型.字体大小), 当前索引 > 0 {
                    视图模型.设置字体大小(可用字号[当前索引 - 1])
                } else if 视图模型.字体大小 > 可用字号.first! {
                    视图模型.设置字体大小(max(可用字号.first!, 视图模型.字体大小 - 1))
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 12)) // 12pt小图标
                    Text("A-")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(Color(UIColor.systemTeal))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemTeal).opacity(0.12)) // 淡青色背景
                .cornerRadius(8)
            }
            .disabled(视图模型.字体大小 <= 可用字号.first!)

            // 当前字号显示
            Text("\(Int(视图模型.字体大小))pt")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 44) // 固定宽度44pt，对齐数字

            // 字体增大按钮（A+）
            Button(action: {
                if let 当前索引 = 可用字号.firstIndex(of: 视图模型.字体大小), 当前索引 < 可用字号.count - 1 {
                    视图模型.设置字体大小(可用字号[当前索引 + 1])
                } else if 视图模型.字体大小 < 可用字号.last! {
                    视图模型.设置字体大小(min(可用字号.last!, 视图模型.字体大小 + 1))
                }
            }) {
                HStack(spacing: 4) {
                    Text("A+")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "textformat.size")
                        .font(.system(size: 14)) // 14pt大图标
                }
                .foregroundColor(Color(UIColor.systemTeal))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemTeal).opacity(0.12)) // 淡青色背景
                .cornerRadius(8)
            }
            .disabled(视图模型.字体大小 >= 可用字号.last!)

            // 一键删除按钮
            Button(action: {
                视图模型.清空代码()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 14)) // 14pt图标
                    Text("删除")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.12)) // 淡红色背景
                .cornerRadius(8)
            }

            // 一键复制按钮
            Button(action: {
                视图模型.复制代码()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14)) // 14pt图标
                    Text("复制")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.12)) // 淡蓝色背景
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

/// 通用工具按钮
struct 工具按钮: View {
    let 标题: String
    let 图标: String
    let 颜色: Color
    let 动作: () -> Void

    var body: some View {
        Button(action: 动作) {
            HStack(spacing: 5) {
                Image(systemName: 图标)
                    .font(.system(size: 14)) // 14pt图标，与文字对齐
                Text(标题)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(颜色)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(颜色.opacity(0.12)) // 淡色背景，区分按钮功能
            .cornerRadius(8)
            .contentShape(Rectangle()) // iOS14兼容：确保整个按钮区域可点击
        }
        .buttonStyle(PlainButtonStyle()) // iOS14兼容：去除默认按钮样式，避免点击高亮异常
    }
}

// MARK: - 提示条视图

/// 顶部提示条
struct 提示条视图: View {
    let 文本: String
    let 颜色: Color

    var body: some View {
        Text(文本)
            .font(.caption)
            .foregroundColor(颜色)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(颜色.opacity(0.1))
    }
}

// MARK: - 静态检查结果视图

/// 静态检查结果展示
struct 静态检查结果视图: View {
    let 结果: 脚本静态检查服务.检查结果

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: 结果.存在错误 ? "xmark.shield" : "checkmark.shield")
                    .foregroundColor(结果.存在错误 ? .red : .green)
                Text("静态检查结果")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            if 结果.问题列表.isEmpty {
                Text("✅ 未发现问题（仅文本规则检查，不保证运行时正常）")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                ForEach(结果.问题列表) { 问题 in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(问题.级别 == .错误 ? Color.red : (问题.级别 == .警告 ? Color.orange : Color.blue))
                                .frame(width: 8, height: 8) // 8pt圆点，标识问题级别
                            Text(问题.描述)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        Text("修复：\(问题.修复建议)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 14)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
    }
}

// MARK: - 重命名弹窗

/// 重命名输入弹窗
struct 重命名弹窗: View {
    @ObservedObject var 视图模型: 脚本编辑器视图模型
    @State private var 输入名称 = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("重命名脚本")
                .font(.headline)
            TextField("新名称", text: $输入名称)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onAppear {
                    输入名称 = 视图模型.脚本.名称
                }
            HStack(spacing: 12) {
                Button("取消") {
                    视图模型.显示重命名弹窗 = false
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)

                Button("确定") {
                    视图模型.重命名输入 = 输入名称
                    视图模型.重命名脚本()
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
