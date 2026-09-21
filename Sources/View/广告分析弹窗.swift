import SwiftUI

/// 广告分析弹窗，显示识别到的广告字段并提供一键生成广告屏蔽脚本
struct 广告分析弹窗: View {
    /// 测试视图模型
    @ObservedObject var 测试视图模型: 脚本测试视图模型
    /// 编辑器视图模型（用于将生成的脚本写回编辑器）
    @ObservedObject var 编辑器视图模型: 脚本编辑器视图模型
    /// 关闭回调
    var 关闭: () -> Void

    var body: some View {
        ZStack {
            // 半透明背景遮罩
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { 关闭() }

            // 弹窗内容
            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Image(systemName: "shield.slash")
                        .foregroundColor(.orange)
                    Text("广告分析结果")
                        .font(.headline)
                    Spacer()
                    Button(action: { 关闭() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // 内容区域
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // 错误/提示信息（始终显示在顶部，如果有的话）
                        if !测试视图模型.广告分析错误.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.orange)
                                Text(测试视图模型.广告分析错误)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }

                        if let 结果 = 测试视图模型.广告分析结果 {
                            // 响应体类型标签
                            HStack(spacing: 6) {
                                Image(systemName: 结果.是否JSON ? "curlybraces" : "text.alignleft")
                                    .font(.caption)
                                    .foregroundColor(结果.是否JSON ? .blue : .purple)
                                Text(结果.是否JSON ? "JSON格式（修改字段值）" : "文本/HTML格式（正则替换）")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }

                            // 判断是否有可生成的内容
                            let 有可生成内容 = 结果.是否JSON ? !结果.广告字段.isEmpty : !结果.文本广告关键词.isEmpty

                            // 一键生成广告屏蔽脚本按钮（置顶）
                            Button(action: {
                                生成并写入脚本()
                            }) {
                                HStack {
                                    Image(systemName: "wand.and.stars")
                                        .foregroundColor(.white)
                                    Text(有可生成内容 ? "一键生成广告屏蔽脚本" : "无广告内容可生成")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(有可生成内容 ? Color.orange : Color.gray)
                                .cornerRadius(8)
                            }
                            .disabled(!有可生成内容)

                            // JSON格式：显示广告字段列表
                            if 结果.是否JSON && !结果.广告字段.isEmpty {
                                Text("共识别到 \(结果.广告字段.count) 个广告相关字段")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)

                                ForEach(结果.广告字段) { 字段 in
                                    广告字段行(字段: 字段)
                                }
                            }
                            // 非JSON格式：显示文本广告关键词
                            else if !结果.是否JSON && !结果.文本广告关键词.isEmpty {
                                Text("共识别到 \(结果.文本广告关键词.count) 个广告关键词（将用于正则替换）")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)

                                // 关键词标签云
                                换行布局(项目: 结果.文本广告关键词) { 关键词 in
                                    Text(关键词)
                                        .font(.caption)
                                        .foregroundColor(.purple)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.purple.opacity(0.1))
                                        .cornerRadius(4)
                                }

                                Text("提示：自动生成基础替换模板，复杂广告格式请根据实际响应体调整正则")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            // 空态提示
                            else {
                                VStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                    Text("未识别到广告内容")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("可尝试：1.点击「获取响应体」获取真实数据 2.在「模拟响应体」中输入数据 3.检查响应体格式")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .frame(maxHeight: UIScreen.main.bounds.height * 0.6) // 最大高度为屏幕60%，避免超出屏幕
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 24)
        }
    }

    /// 生成广告屏蔽脚本并写入编辑器
    private func 生成并写入脚本() {
        let 脚本代码 = 测试视图模型.生成广告屏蔽脚本()
        guard !脚本代码.isEmpty else { return }

        // 写入编辑器
        编辑器视图模型.脚本.内容 = 脚本代码
        编辑器视图模型.保存脚本()

        // 关闭弹窗
        关闭()
    }
}

/// 单个广告字段行
private struct 广告字段行: View {
    let 字段: 智能分析服务.识别字段

    var body: some View {
        HStack(spacing: 10) {
            // 类型图标
            Image(systemName: 类型图标)
                .foregroundColor(.orange)
                .frame(width: 24) // 24pt图标宽度，对齐

            VStack(alignment: .leading, spacing: 2) {
                // 字段路径
                Text(字段.字段路径)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                // 字段类型和当前值
                HStack {
                    Text(类型文本)
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                    Text("当前值: \(字段.当前值)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
    }

    /// 类型图标
    private var 类型图标: String {
        switch 字段.类型 {
        case .广告标记: return "flag"
        case .广告链接: return "link"
        case .广告图片: return "photo"
        case .广告数组: return "square.grid.2x2"
        default: return "circle"
        }
    }

    /// 类型文本
    private var 类型文本: String {
        switch 字段.类型 {
        case .广告标记: return "广告标记"
        case .广告链接: return "广告链接"
        case .广告图片: return "广告图片"
        case .广告数组: return "广告数组"
        default: return "广告相关"
        }
    }
}

/// 简单的换行布局视图（用于展示关键词标签云）
struct 换行布局<数据: RandomAccessCollection, 内容: View>: View where 数据.Element: Hashable {
    let 项目: 数据
    let 内容: (数据.Element) -> 内容

    var body: some View {
        // 使用LazyVGrid实现自适应换行布局
        let 列 = [GridItem(.adaptive(minimum: 80), spacing: 6)]
        LazyVGrid(columns: 列, alignment: .leading, spacing: 6) {
            ForEach(Array(项目), id: \.self) { 项 in
                内容(项)
            }
        }
    }
}
