import SwiftUI

/// 脚本列表页，展示本地所有脚本，支持新建、删除、进入编辑
struct 脚本列表页: View {
    /// 列表视图模型
    @StateObject private var 视图模型 = 脚本列表视图模型()
    /// 退出模式（iOS14兼容）
    @Environment(\.presentationMode) private var 退出模式

    var body: some View {
        NavigationView {
            ZStack {
                // 列表内容
                List {
                    if 视图模型.存储.脚本列表.isEmpty {
                        空态视图()
                    } else {
                        ForEach(视图模型.存储.脚本列表) { 脚本 in
                            NavigationLink(destination: 脚本编辑器页(脚本: 脚本, 存储: 视图模型.存储)) {
                                脚本行视图(脚本: 脚本)
                            }
                        }
                        .onDelete { 索引集 in
                            索引集.forEach { 索引 in
                                视图模型.删除脚本(视图模型.存储.脚本列表[索引])
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle()) // iOS14兼容的分组列表样式
                .navigationBarTitle("圈X脚本编辑器", displayMode: .large)
                .navigationBarItems(trailing:
                    Button(action: {
                        视图模型.显示新建弹窗 = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2) // 标题2字号，加号按钮醒目
                    }
                )

                // 错误提示浮层
                if let 错误 = 视图模型.错误提示 {
                    VStack {
                        Spacer()
                        Text(错误)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.85))
                            .cornerRadius(8)
                            .padding(.bottom, 20)
                    }
                    .transition(.move(edge: .bottom))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            视图模型.错误提示 = nil
                        }
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // 竖屏单栏堆叠样式，避免iPad分栏
        // 新建脚本输入弹窗覆盖层（iOS14 Alert不支持TextField，使用自定义覆盖层）
        .overlay(新建脚本弹窗覆盖层)
    }

    /// 新建脚本输入弹窗覆盖层（因为iOS14 Alert不支持TextField）
    private var 新建脚本弹窗覆盖层: some View {
        Group {
            if 视图模型.显示新建弹窗 {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        视图模型.显示新建弹窗 = false
                    }
                新建脚本弹窗(视图模型: 视图模型)
                    .transition(.scale)
            }
        }
    }
}

// MARK: - 脚本行视图

/// 列表中的单个脚本行
struct 脚本行视图: View {
    let 脚本: 脚本模型

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(脚本.名称)
                .font(.headline)
                .lineLimit(1)
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(格式化时间(脚本.修改时间))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(脚本.内容.count) 字符")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    /// 格式化时间为简短字符串
    private func 格式化时间(_ 日期: Date) -> String {
        let 格式化器 = DateFormatter()
        格式化器.dateFormat = "yyyy-MM-dd HH:mm"
        return 格式化器.string(from: 日期)
    }
}

// MARK: - 空态视图

/// 脚本列表为空时的空态展示
struct 空态视图: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48)) // 48pt大图标，空态视觉焦点
                .foregroundColor(.secondary)
            Text("还没有脚本")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("点击右上角 + 号创建你的第一个圈X脚本")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 新建脚本弹窗

/// 新建脚本输入弹窗（iOS14兼容，自定义弹窗）
struct 新建脚本弹窗: View {
    @ObservedObject var 视图模型: 脚本列表视图模型
    @State private var 输入名称 = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("新建脚本")
                .font(.headline)
            TextField("请输入脚本名称", text: $输入名称)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
            HStack(spacing: 12) {
                Button("取消") {
                    视图模型.显示新建弹窗 = false
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.systemGray6)
                .cornerRadius(8)

                Button("创建") {
                    视图模型.新脚本名称 = 输入名称
                    视图模型.新建脚本()
                    输入名称 = ""
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
