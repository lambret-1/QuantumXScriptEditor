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

    init(脚本: 脚本模型, 存储: 脚本存储) {
        _视图模型 = StateObject(wrappedValue: 脚本编辑器视图模型(脚本: 脚本, 存储: 存储))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 顶部工具栏
                工具栏视图(视图模型: 视图模型, 使用代码键盘: $使用代码键盘, 显示智能分析: $显示智能分析)

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
        // iOS14兼容：单sheet+枚举，避免多sheet并列时只有一个能弹出的bug
        .sheet(item: $视图模型.当前弹窗) { 弹窗类型 in
            switch 弹窗类型 {
            case .模板:
                模板选择弹窗(视图模型: 视图模型)
            case .补全:
                代码补全弹窗(视图模型: 视图模型)
            }
        }
        // 重命名输入覆盖层（iOS14 Alert不支持TextField，使用自定义覆盖层）
        .overlay(重命名覆盖层)
        // 智能分析弹窗覆盖层
        .overlay(智能分析覆盖层)
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
}

// MARK: - 工具栏视图

/// 编辑器顶部工具栏
struct 工具栏视图: View {
    @ObservedObject var 视图模型: 脚本编辑器视图模型
    /// 是否使用自定义代码键盘绑定
    @Binding var 使用代码键盘: Bool
    /// 是否显示智能分析弹窗绑定
    @Binding var 显示智能分析: Bool

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
                }
                工具按钮(标题: "补全", 图标: "textformat", 颜色: .orange) {
                    视图模型.当前弹窗 = .补全
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
                // 字体大小按键（点击循环切换常用字号，自动记忆）
                Button(action: {
                    let 常用字号: [CGFloat] = [10, 12, 14, 16, 18, 20, 24]
                    if let 当前索引 = 常用字号.firstIndex(of: 视图模型.字体大小) {
                        let 下一个索引 = (当前索引 + 1) % 常用字号.count
                        视图模型.设置字体大小(常用字号[下一个索引])
                    } else {
                        视图模型.设置字体大小(14)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "textformat.size")
                            .font(.system(size: 14)) // 14pt图标，与文字对齐
                        Text("\(Int(视图模型.字体大小))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.teal)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.teal.opacity(0.12)) // 淡青色背景，标识字体设置
                    .cornerRadius(8)
                }
                // 一键删除代码按钮（字体大小键右边）
                Button(action: {
                    视图模型.清空代码()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14)) // 14pt图标
                        .foregroundColor(.red)
                        .frame(width: 36, height: 36) // 36pt正方形按钮，紧凑布局
                        .background(Color.red.opacity(0.12)) // 淡红色背景
                        .cornerRadius(8)
                }
                // 一键复制代码按钮（字体大小键右边）
                Button(action: {
                    视图模型.复制代码()
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14)) // 14pt图标
                        .foregroundColor(.blue)
                        .frame(width: 36, height: 36) // 36pt正方形按钮，紧凑布局
                        .background(Color.blue.opacity(0.12)) // 淡蓝色背景
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGray6))
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
        }
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
