import SwiftUI

/// 智能分析弹窗，用户粘贴抓包数据后自动识别会员/广告信息并生成脚本模板
struct 智能分析弹窗: View {
    /// 插入模板回调（参数为生成的模板代码）
    let 插入回调: (String) -> Void
    /// 关闭回调
    let 关闭回调: () -> Void

    /// 用户粘贴的原始文本
    @State private var 原始文本 = ""
    /// 分析结果
    @State private var 分析结果: 智能分析服务.分析结果?
    /// 生成的模板列表
    @State private var 模板列表: [智能分析服务.生成模板] = []
    /// 是否正在分析
    @State private var 分析中 = false
    /// 选中的模板索引
    @State private var 选中模板ID: UUID?

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    关闭回调()
                }

            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Image(systemName: "wand.and.stars")
                        .foregroundColor(.purple)
                    Text("智能分析")
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        关闭回调()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // 粘贴输入区
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("粘贴抓包数据")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                // 一键粘贴按钮
                                Button(action: {
                                    if let 剪贴板内容 = UIPasteboard.general.string {
                                        原始文本 = 剪贴板内容
                                    }
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "doc.on.clipboard")
                                            .font(.caption2)
                                        Text("一键粘贴")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                                }
                                // 一键删除按钮
                                Button(action: {
                                    原始文本 = ""
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "trash")
                                            .font(.caption2)
                                        Text("一键删除")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(4)
                                }
                            }
                            TextEditor(text: $原始文本)
                                .font(.system(size: 11, design: .monospaced)) // 11pt等宽字体，粘贴数据编辑
                                .frame(height: 120) // 120pt高度，足够粘贴一段JSON
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            Text("支持格式：JSON响应体、cURL命令、HAR、键值对文本")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        // 分析按钮
                        Button(action: {
                            执行分析()
                        }) {
                            HStack(spacing: 6) {
                                if 分析中 {
                                    活动指示器视图()
                                } else {
                                    Image(systemName: "magnifyingglass")
                                }
                                Text(分析中 ? "分析中..." : "开始分析")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(原始文本.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.purple)
                            .cornerRadius(8)
                        }
                        .disabled(原始文本.trimmingCharacters(in: .whitespaces).isEmpty || 分析中)

                        // 分析结果
                        if let 结果 = 分析结果 {
                            分析结果视图(结果: 结果)
                        }

                        // 生成的模板列表
                        if !模板列表.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("生成的模板（点击插入到代码区）")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ForEach(模板列表) { 模板 in
                                    模板卡片视图(
                                        模板: 模板,
                                        已选中: 选中模板ID == 模板.id,
                                        选中回调: {
                                            选中模板ID = 模板.id
                                        },
                                        插入回调: {
                                            插入回调(模板.代码)
                                            关闭回调()
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 20)
            .padding(.vertical, 40)
        }
    }

    // MARK: - 分析逻辑

    /// 执行分析
    private func 执行分析() {
        分析中 = true
        分析结果 = nil
        模板列表 = []
        选中模板ID = nil

        // 模拟短暂延迟（实际分析是同步的，给用户反馈）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let 结果 = 智能分析服务.分析(原始文本: 原始文本)
            分析结果 = 结果
            模板列表 = 智能分析服务.生成模板列表(结果: 结果)
            分析中 = false
        }
    }
}

// MARK: - 分析结果展示视图

/// 分析结果展示
private struct 分析结果视图: View {
    let 结果: 智能分析服务.分析结果

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: 结果.有结果 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(结果.有结果 ? .green : .orange)
                Text("分析结果（\(结果.数据格式)）")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }

            if 结果.有结果 {
                // 会员字段
                if !结果.会员字段.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("会员信息（\(结果.会员字段.count)项）", systemImage: "crown.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        ForEach(结果.会员字段.prefix(5)) { 字段 in
                            HStack(spacing: 6) {
                                Text(智能分析服务.路径展示文本(字段.字段路径))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.primary)
                                Text("= \(字段.当前值)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(类型文本(字段.类型))
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.orange)
                                    .cornerRadius(3)
                            }
                        }
                        if 结果.会员字段.count > 5 {
                            Text("...还有\(结果.会员字段.count - 5)项")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(6)
                }

                // 广告字段
                if !结果.广告字段.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("广告信息（\(结果.广告字段.count)项）", systemImage: "nosign")
                            .font(.caption)
                            .foregroundColor(.red)
                        ForEach(结果.广告字段.prefix(5)) { 字段 in
                            HStack(spacing: 6) {
                                Text(智能分析服务.路径展示文本(字段.字段路径))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.primary)
                                Text("= \(字段.当前值)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(类型文本(字段.类型))
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.red)
                                    .cornerRadius(3)
                            }
                        }
                        if 结果.广告字段.count > 5 {
                            Text("...还有\(结果.广告字段.count - 5)项")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(6)
                }

                // 用户核心信息字段
                if !结果.用户核心字段.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("用户核心信息（\(结果.用户核心字段.count)项）", systemImage: "person.crop.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        ForEach(结果.用户核心字段.prefix(6)) { 字段 in
                            HStack(spacing: 6) {
                                Text(智能分析服务.路径展示文本(字段.字段路径))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.primary)
                                Text("= \(字段.当前值)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(类型文本(字段.类型))
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.blue)
                                    .cornerRadius(3)
                            }
                        }
                        if 结果.用户核心字段.count > 6 {
                            Text("...还有\(结果.用户核心字段.count - 6)项")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(6)
                }
            } else {
                Text("未识别到会员、广告或用户核心信息字段，请检查粘贴的数据格式是否正确")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
        }
        .padding(10)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
    }

    /// 字段类型文本
    private func 类型文本(_ 类型: 智能分析服务.识别字段.字段类型) -> String {
        switch 类型 {
        case .会员状态: return "状态"
        case .会员到期时间: return "到期"
        case .会员等级: return "等级"
        case .广告标记: return "标记"
        case .广告链接: return "链接"
        case .广告图片: return "图片"
        case .广告数组: return "数组"
        case .用户ID: return "ID"
        case .用户名: return "昵称"
        case .手机号: return "手机"
        case .邮箱: return "邮箱"
        case .头像: return "头像"
        case .积分余额: return "积分"
        case .登录Token: return "Token"
        case .性别: return "性别"
        case .生日: return "生日"
        }
    }
}

// MARK: - 模板卡片视图

/// 生成模板的卡片展示
private struct 模板卡片视图: View {
    let 模板: 智能分析服务.生成模板
    let 已选中: Bool
    let 选中回调: () -> Void
    let 插入回调: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // 分类标签
                Text(模板.分类)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(分类颜色(模板.分类))
                    .cornerRadius(4)
                Text(模板.名称)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            Text(模板.说明)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            // 代码预览（前3行）
            let 预览行 = 模板.代码.components(separatedBy: "\n").prefix(3).joined(separator: "\n")
            Text(预览行)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(4)

            // 插入按钮
            Button(action: {
                插入回调()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.doc.fill")
                    Text("插入到代码区")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.purple)
                .cornerRadius(6)
            }
        }
        .padding(10)
        .background(已选中 ? Color.purple.opacity(0.08) : Color(UIColor.systemGray6))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(已选中 ? Color.purple : Color.clear, lineWidth: 1.5)
        )
        .onTapGesture {
            选中回调()
        }
    }

    /// 分类颜色
    private func 分类颜色(_ 分类: String) -> Color {
        switch 分类 {
        case "会员解锁": return .orange
        case "去广告": return .red
        case "用户信息": return .blue
        default: return .gray
        }
    }
}
