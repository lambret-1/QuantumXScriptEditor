import SwiftUI

/// 脚本编辑器页面，包含工具栏、编辑器、静态检查、测试面板
struct 脚本编辑器页: View {
    /// 编辑器视图模型
    @StateObject private var 视图模型: 脚本编辑器视图模型
    /// 测试面板视图模型
    @StateObject private var 测试视图模型 = 脚本测试视图模型()
    /// 是否使用自定义代码键盘（默认false，使用系统键盘）
    @State private var 使用代码键盘 = false

    init(脚本: 脚本模型, 存储: 脚本存储) {
        _视图模型 = StateObject(wrappedValue: 脚本编辑器视图模型(脚本: 脚本, 存储: 存储))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 顶部工具栏
                工具栏视图(视图模型: 视图模型, 使用代码键盘: $使用代码键盘)

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

                // 字体大小调整
                字体调整视图(字体大小: $视图模型.字体大小)

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
        .sheet(isPresented: $视图模型.显示模板弹窗) {
            模板选择弹窗(视图模型: 视图模型)
        }
        .sheet(isPresented: $视图模型.显示补全弹窗) {
            代码补全弹窗(视图模型: 视图模型)
        }
        // 重命名输入覆盖层（iOS14 Alert不支持TextField，使用自定义覆盖层）
        .overlay(重命名覆盖层)
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
}

// MARK: - 工具栏视图

/// 编辑器顶部工具栏
struct 工具栏视图: View {
    @ObservedObject var 视图模型: 脚本编辑器视图模型
    /// 是否使用自定义代码键盘绑定
    @Binding var 使用代码键盘: Bool

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
                    .foregroundColor(使用代码键盘 ? .white : .indigo)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(使用代码键盘 ? Color.indigo : Color.indigo.opacity(0.12))
                    .cornerRadius(8)
                }
                工具按钮(标题: "保存", 图标: "square.and.arrow.down", 颜色: .blue) {
                    视图模型.保存脚本()
                }
                工具按钮(标题: "模板", 图标: "square.grid.2x2", 颜色: .purple) {
                    视图模型.显示模板弹窗 = true
                }
                工具按钮(标题: "补全", 图标: "textformat", 颜色: .orange) {
                    视图模型.显示补全弹窗 = true
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

// MARK: - 字体调整视图

/// 编辑器字体大小调整
struct 字体调整视图: View {
    @Binding var 字体大小: CGFloat

    var body: some View {
        HStack {
            Text("字体大小")
                .font(.caption)
                .foregroundColor(.secondary)
            Slider(value: $字体大小, in: 10...24, step: 1) // 10-24pt范围，1pt步进
                .accentColor(.blue)
            Text("\(Int(字体大小))pt")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 40) // 固定宽度40pt，对齐数字
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
