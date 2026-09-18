import SwiftUI
import UIKit

// MARK: - 带行号代码编辑器（SwiftUI封装）

/// 带行号、语法高亮、代码补全的代码编辑器
/// 底层使用UITextView保证iOS14兼容性与输入体验
struct 带行号代码编辑器: UIViewRepresentable {
    /// 绑定的脚本内容文本
    @Binding var 文本: String
    /// 编辑器字体大小
    var 字体大小: CGFloat

    func makeUIView(context: Context) -> 代码编辑器容器视图 {
        let 容器 = 代码编辑器容器视图(字体大小: 字体大小)
        容器.文本视图.delegate = context.coordinator
        容器.文本视图.text = 文本
        容器.行号视图.文本视图 = 容器.文本视图
        // 设置补全选中回调
        context.coordinator.补全选中回调 = { [weak 容器] 项 in
            guard let 容器 = 容器 else { return }
            context.coordinator.插入补全项(项, 在: 容器.文本视图)
        }
        容器.补全辅助视图.选中回调 = context.coordinator.补全选中回调
        // 初始高亮
        容器.文本视图.attributedText = context.coordinator.高亮服务.高亮(文本: 文本)
        return 容器
    }

    func updateUIView(_ 容器: 代码编辑器容器视图, context: Context) {
        容器.文本视图.font = UIFont.monospacedSystemFont(ofSize: 字体大小, weight: .regular)
        if 容器.文本视图.text != 文本 {
            let 选中范围 = 容器.文本视图.selectedRange
            容器.文本视图.text = 文本
            容器.文本视图.attributedText = context.coordinator.高亮服务.高亮(文本: 文本)
            容器.文本视图.selectedRange = 选中范围
        }
        容器.行号视图.setNeedsDisplay()
    }

    func makeCoordinator() -> 编辑器协调器 {
        编辑器协调器(父视图: self)
    }
}

// MARK: - 编辑器协调器

/// 编辑器协调器，处理UITextViewDelegate回调
final class 编辑器协调器: NSObject, UITextViewDelegate {
    /// 父视图引用
    var 父视图: 带行号代码编辑器
    /// 语法高亮服务
    let 高亮服务 = 语法高亮服务()
    /// 补全项选中回调（由容器注入）
    var 补全选中回调: ((代码补全项) -> Void)?

    init(父视图: 带行号代码编辑器) {
        self.父视图 = 父视图
    }

    /// 文本变化时更新绑定、重新高亮、刷新行号、更新补全候选
    func textViewDidChange(_ 文本视图: UITextView) {
        let 选中范围 = 文本视图.selectedRange
        文本视图.attributedText = 高亮服务.高亮(文本: 文本视图.text)
        文本视图.selectedRange = 选中范围
        父视图.文本 = 文本视图.text
        // 刷新行号
        if let 容器 = 文本视图.superview as? 代码编辑器容器视图 {
            容器.行号视图.setNeedsDisplay()
            更新补全候选(文本视图, 容器: 容器)
        }
    }

    /// 滚动时刷新行号显示
    func scrollViewDidScroll(_ 滚动视图: UIScrollView) {
        guard let 文本视图 = 滚动视图 as? UITextView,
              let 容器 = 文本视图.superview as? 代码编辑器容器视图 else { return }
        容器.行号视图.setNeedsDisplay()
    }

    /// 根据当前光标位置的单词过滤补全候选
    private func 更新补全候选(_ 文本视图: UITextView, 容器: 代码编辑器容器视图) {
        let 单词 = 当前单词(在: 文本视图)
        let 候选 = 代码补全服务.过滤候选项(前缀: 单词)
        容器.补全辅助视图.更新候选(候选)
    }

    /// 获取光标前的当前单词（到空白或换行截止）
    private func 当前单词(在 文本视图: UITextView) -> String {
        let 位置 = 文本视图.selectedRange.location
        guard 位置 > 0 else { return "" }
        let 文本 = 文本视图.text as NSString
        var 开始 = 位置
        while 开始 > 0 {
            let 字符 = 文本.character(at: 开始 - 1)
            // 空格(32)、换行(10)、制表符(9)、等号(61)、分号(59)、逗号(44)作为单词分隔
            if 字符 == 32 || 字符 == 10 || 字符 == 9 || 字符 == 61 || 字符 == 59 || 字符 == 44 {
                break
            }
            开始 -= 1
        }
        return 文本.substring(with: NSRange(location: 开始, length: 位置 - 开始))
    }

    /// 在光标处插入补全项，替换当前单词
    func 插入补全项(_ 项: 代码补全项, 在 文本视图: UITextView) {
        let 位置 = 文本视图.selectedRange.location
        let 文本 = 文本视图.text as NSString
        var 开始 = 位置
        while 开始 > 0 {
            let 字符 = 文本.character(at: 开始 - 1)
            if 字符 == 32 || 字符 == 10 || 字符 == 9 || 字符 == 61 || 字符 == 59 || 字符 == 44 { break }
            开始 -= 1
        }
        let 替换范围 = NSRange(location: 开始, length: 位置 - 开始)
        let 新文本 = 文本.replacingCharacters(in: 替换范围, with: 项.插入代码)
        文本视图.text = 新文本
        文本视图.selectedRange = NSRange(location: 开始 + 项.插入代码.count, length: 0)
        textViewDidChange(文本视图)
    }
}

// MARK: - 编辑器容器视图

/// 编辑器容器，包含文本视图、行号视图、补全辅助视图
final class 代码编辑器容器视图: UIView {
    /// 代码编辑文本视图
    let 文本视图: UITextView
    /// 行号显示视图
    let 行号视图: 行号视图
    /// 键盘上方补全辅助视图
    let 补全辅助视图: 补全辅助视图

    init(字体大小: CGFloat) {
        文本视图 = UITextView()
        行号视图 = 行号视图()
        补全辅助视图 = 补全辅助视图()
        super.init(frame: .zero)
        设置子视图(字体大小: 字体大小)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    private func 设置子视图(字体大小: CGFloat) {
        backgroundColor = .systemBackground

        // 配置文本视图
        文本视图.translatesAutoresizingMaskIntoConstraints = false
        文本视图.font = UIFont.monospacedSystemFont(ofSize: 字体大小, weight: .regular)
        文本视图.backgroundColor = .systemBackground
        文本视图.autocorrectionType = .no
        文本视图.autocapitalizationType = .none
        文本视图.smartQuotesType = .no
        文本视图.smartDashesType = .no
        文本视图.smartInsertDeleteType = .no
        文本视图.textContainerInset = UIEdgeInsets(
            top: 8,
            left: 应用常量.行号区域宽度 + 8, // 左侧留出号区域+间距，避免文字被行号遮挡
            bottom: 8,
            right: 8
        )
        文本视图.inputAccessoryView = 补全辅助视图

        // 配置行号视图
        行号视图.translatesAutoresizingMaskIntoConstraints = false
        行号视图.backgroundColor = .systemGray6.withAlphaComponent(0.5) // 半透明灰底，区分行号区与代码区

        addSubview(文本视图)
        addSubview(行号视图)

        // 自动布局约束
        NSLayoutConstraint.activate([
            文本视图.topAnchor.constraint(equalTo: topAnchor),
            文本视图.leadingAnchor.constraint(equalTo: leadingAnchor),
            文本视图.trailingAnchor.constraint(equalTo: trailingAnchor),
            文本视图.bottomAnchor.constraint(equalTo: bottomAnchor),

            行号视图.topAnchor.constraint(equalTo: topAnchor),
            行号视图.leadingAnchor.constraint(equalTo: leadingAnchor),
            行号视图.widthAnchor.constraint(equalToConstant: 应用常量.行号区域宽度), // 行号区域固定宽度
            行号视图.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

// MARK: - 行号视图

/// 行号绘制视图，根据文本视图的可见范围绘制行号
final class 行号视图: UIView {
    /// 关联的文本视图，用于获取布局信息
    weak var 文本视图: UITextView?

    override func draw(_ 矩形: CGRect) {
        super.draw(矩形)
        guard let 文本视图 = 文本视图 else { return }

        let 布局管理器 = 文本视图.layoutManager
        let 文本容器 = 文本视图.textContainer
        let 全文 = 文本视图.text ?? ""

        // 计算可见字形范围（考虑内容偏移）
        let 可见区域 = CGRect(
            x: 0,
            y: 文本视图.contentOffset.y,
            width: 文本视图.bounds.width,
            height: 文本视图.bounds.height
        )
        let 字形范围 = 布局管理器.glyphRange(forBoundingRect: 可见区域, in: 文本容器)

        // 计算可见区域第一行的行号
        var 起始行号 = 1
        if 字形范围.location > 0,
           let 前缀范围 = Range(NSRange(location: 0, length: 字形范围.location), in: 全文) {
            起始行号 = 全文[前缀范围].components(separatedBy: .newlines).count
        }

        // 绘制属性
        let 字体 = 文本视图.font ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        let 文字属性: [NSAttributedString.Key: Any] = [
            .font: 字体,
            .foregroundColor: 语法颜色.行号文本
        ]

        var 当前行号 = 起始行号
        // 遍历可见行片段，逐行绘制行号
        布局管理器.enumerateLineFragments(forGlyphRange: 字形范围) { 行矩形, _, _, _, _ in
            let y = 行矩形.origin.y - 文本视图.contentOffset.y + 文本视图.textContainerInset.top
            let 行号文本 = "\(当前行号)" as NSString
            let 文本尺寸 = 行号文本.size(withAttributes: 文字属性)
            let 绘制矩形 = CGRect(
                x: self.bounds.width - 文本尺寸.width - 6, // 右对齐，距右边6pt
                y: y + (行矩形.height - 文本尺寸.height) / 2, // 垂直居中
                width: 文本尺寸.width,
                height: 文本尺寸.height
            )
            行号文本.draw(in: 绘制矩形, withAttributes: 文字属性)
            当前行号 += 1
        }
    }
}

// MARK: - 补全辅助视图

/// 键盘上方的代码补全候选条，横向滚动展示候选
final class 补全辅助视图: UIView {
    /// 选中补全项的回调
    var 选中回调: ((代码补全项) -> Void)?
    /// 当前候选列表
    private var 候选列表: [代码补全项] = []
    /// 横向滚动容器
    private let 滚动视图 = UIScrollView()
    /// 候选按钮堆栈
    private let 堆栈视图 = UIStackView()
    /// 是否有候选（控制视图高度）
    private var 有候选 = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        设置界面()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    /// 固有内容尺寸，无候选时高度为0实现隐藏
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 有候选 ? 44 : 0) // 有候选时44pt高，适配键盘上方区域
    }

    private func 设置界面() {
        backgroundColor = .systemBackground

        // 顶部分隔线
        let 分隔线 = UIView()
        分隔线.backgroundColor = .separator
        分隔线.translatesAutoresizingMaskIntoConstraints = false
        addSubview(分隔线)

        // 滚动视图
        滚动视图.showsHorizontalScrollIndicator = false
        滚动视图.showsVerticalScrollIndicator = false
        滚动视图.translatesAutoresizingMaskIntoConstraints = false
        addSubview(滚动视图)

        // 堆栈视图
        堆栈视图.axis = .horizontal
        堆栈视图.spacing = 8 // 候选按钮间距8pt，紧凑排列
        堆栈视图.alignment = .center
        堆栈视图.translatesAutoresizingMaskIntoConstraints = false
        滚动视图.addSubview(堆栈视图)

        NSLayoutConstraint.activate([
            分隔线.topAnchor.constraint(equalTo: topAnchor),
            分隔线.leadingAnchor.constraint(equalTo: leadingAnchor),
            分隔线.trailingAnchor.constraint(equalTo: trailingAnchor),
            分隔线.heightAnchor.constraint(equalToConstant: 0.5), // 0.5pt细分割线，iOS标准分隔线厚度

            滚动视图.topAnchor.constraint(equalTo: 分隔线.bottomAnchor),
            滚动视图.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12), // 左边距12pt
            滚动视图.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12), // 右边距12pt
            滚动视图.bottomAnchor.constraint(equalTo: bottomAnchor),

            堆栈视图.topAnchor.constraint(equalTo: 滚动视图.topAnchor),
            堆栈视图.leadingAnchor.constraint(equalTo: 滚动视图.leadingAnchor),
            堆栈视图.trailingAnchor.constraint(equalTo: 滚动视图.trailingAnchor),
            堆栈视图.bottomAnchor.constraint(equalTo: 滚动视图.bottomAnchor),
            堆栈视图.heightAnchor.constraint(equalTo: 滚动视图.heightAnchor)
        ])
    }

    /// 更新候选列表并重建按钮
    func 更新候选(_ 列表: [代码补全项]) {
        候选列表 = 列表
        有候选 = !列表.isEmpty

        // 清除旧按钮
        堆栈视图.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (索引, 项) in 列表.enumerated() {
            let 按钮 = 补全按钮(type: .system)
            按钮.补全项 = 项
            按钮.tag = 索引
            按钮.setTitle(项.触发词, for: .normal)
            按钮.titleLabel?.font = .monospacedSystemFont(ofSize: 13, weight: .regular) // 13pt等宽字体，代码风格统一
            按钮.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12) // 按钮内边距，确保点击区域足够
            按钮.backgroundColor = .systemGray6
            按钮.layer.cornerRadius = 6 // 6pt圆角，候选按钮风格
            按钮.addTarget(self, action: #selector(候选按钮点击(_:)), for: .touchUpInside)
            堆栈视图.addArrangedSubview(按钮)
        }

        invalidateIntrinsicContentSize()
    }

    @objc private func 候选按钮点击(_ 按钮: 补全按钮) {
        guard let 项 = 按钮.补全项 else { return }
        选中回调?(项)
    }
}

// MARK: - 补全按钮（关联补全项数据）

/// 关联了补全项数据的UIButton子类
final class 补全按钮: UIButton {
    /// 关联的补全项
    var 补全项: 代码补全项?
}
