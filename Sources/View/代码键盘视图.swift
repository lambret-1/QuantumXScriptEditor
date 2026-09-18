import UIKit

// MARK: - 新手友好代码键盘

/// 自定义代码键盘，替代系统键盘，提供英文26键、符号、关键字、圈X API、常用片段五大页面
/// 面向新手，无需切换系统键盘即可输入常用代码
final class 代码键盘视图: UIInputView {
    /// 插入文本回调（由编辑器注入）
    var 插入文本回调: ((String) -> Void)?
    /// 删除字符回调
    var 删除字符回调: (() -> Void)?
    /// 换行回调
    var 换行回调: (() -> Void)?
    /// 缩进回调（插入Tab）
    var 缩进回调: (() -> Void)?
    /// 切换到系统键盘回调
    var 切换系统键盘回调: (() -> Void)?

    /// 页面标签栏
    private let 标签栏 = UIView()
    /// 页面滚动容器
    private let 页面滚动视图 = UIScrollView()
    /// 页面内容堆栈
    private let 页面堆栈 = UIStackView()
    /// 底部功能行
    private let 底部功能行 = UIView()
    /// 当前选中的标签按钮
    private var 当前标签按钮: 键盘标签按钮?
    /// 英文键盘大写模式
    private var 大写模式 = false
    /// 英文字母按钮列表（用于Shift切换时刷新标题）
    private var 英文字母按钮列表: [键盘按键按钮] = []
    /// 英文键盘Shift按钮引用
    private var 英文shift按钮: UIButton?

    /// 五个页面定义（英文为首页，方便输入字母）
    private let 页面定义: [(名称: String, 符号: String, 按钮列表: [键盘按钮数据])] = [
        (名称: "英文", 符号: "A", 按钮列表: []),
        (名称: "符号", 符号: "≠", 按钮列表: 代码键盘数据.符号按钮),
        (名称: "关键字", 符号: "ƒ", 按钮列表: 代码键盘数据.关键字按钮),
        (名称: "圈X", 符号: "$", 按钮列表: 代码键盘数据.圈X按钮),
        (名称: "片段", 符号: "⎘", 按钮列表: 代码键盘数据.片段按钮)
    ]

    override init(frame: CGRect, inputViewStyle: UIInputView.Style) {
        super.init(frame: frame, inputViewStyle: inputViewStyle)
        设置界面()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    // MARK: - 界面搭建

    private func 设置界面() {
        backgroundColor = .systemGray6 // 浅灰背景，与系统键盘风格一致
        allowsSelfSizing = true

        // 标签栏
        标签栏.backgroundColor = .systemGray5 // 稍深灰底，区分标签栏与按键区
        标签栏.translatesAutoresizingMaskIntoConstraints = false
        addSubview(标签栏)

        // 页面滚动视图
        页面滚动视图.isPagingEnabled = true
        页面滚动视图.showsHorizontalScrollIndicator = false
        页面滚动视图.showsVerticalScrollIndicator = false
        页面滚动视图.bounces = false
        页面滚动视图.delegate = self
        页面滚动视图.translatesAutoresizingMaskIntoConstraints = false
        addSubview(页面滚动视图)

        // 页面堆栈
        页面堆栈.axis = .horizontal
        页面堆栈.alignment = .fill
        页面堆栈.distribution = .fillEqually
        页面堆栈.spacing = 0
        页面堆栈.translatesAutoresizingMaskIntoConstraints = false
        页面滚动视图.addSubview(页面堆栈)

        // 底部功能行
        底部功能行.backgroundColor = .systemGray5
        底部功能行.translatesAutoresizingMaskIntoConstraints = false
        addSubview(底部功能行)

        // 构建标签按钮
        构建标签栏()
        // 构建四个页面
        构建页面()
        // 构建底部功能行
        构建底部功能行()

        // 布局约束
        NSLayoutConstraint.activate([
            标签栏.topAnchor.constraint(equalTo: topAnchor),
            标签栏.leadingAnchor.constraint(equalTo: leadingAnchor),
            标签栏.trailingAnchor.constraint(equalTo: trailingAnchor),
            标签栏.heightAnchor.constraint(equalToConstant: 36), // 标签栏36pt高，紧凑不占空间

            页面滚动视图.topAnchor.constraint(equalTo: 标签栏.bottomAnchor),
            页面滚动视图.leadingAnchor.constraint(equalTo: leadingAnchor),
            页面滚动视图.trailingAnchor.constraint(equalTo: trailingAnchor),
            页面滚动视图.bottomAnchor.constraint(equalTo: 底部功能行.topAnchor),

            页面堆栈.topAnchor.constraint(equalTo: 页面滚动视图.topAnchor),
            页面堆栈.leadingAnchor.constraint(equalTo: 页面滚动视图.leadingAnchor),
            页面堆栈.trailingAnchor.constraint(equalTo: 页面滚动视图.trailingAnchor),
            页面堆栈.bottomAnchor.constraint(equalTo: 页面滚动视图.bottomAnchor),
            页面堆栈.heightAnchor.constraint(equalTo: 页面滚动视图.heightAnchor),

            底部功能行.leadingAnchor.constraint(equalTo: leadingAnchor),
            底部功能行.trailingAnchor.constraint(equalTo: trailingAnchor),
            底部功能行.bottomAnchor.constraint(equalTo: bottomAnchor),
            底部功能行.heightAnchor.constraint(equalToConstant: 44) // 底部功能行44pt高，标准触控高度
        ])
    }

    /// 构建标签栏按钮
    private func 构建标签栏() {
        let 标签堆栈 = UIStackView()
        标签堆栈.axis = .horizontal
        标签堆栈.distribution = .fillEqually
        标签堆栈.alignment = .fill
        标签堆栈.spacing = 0
        标签堆栈.translatesAutoresizingMaskIntoConstraints = false
        标签栏.addSubview(标签堆栈)

        for (索引, 页面) in 页面定义.enumerated() {
            let 按钮 = 键盘标签按钮(type: .system)
            按钮.页面索引 = 索引
            按钮.setTitle(页面.名称, for: .normal)
            按钮.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium) // 13pt中等字号，标签清晰
            按钮.setTitleColor(.secondaryLabel, for: .normal)
            按钮.setTitleColor(.label, for: .selected)
            按钮.addTarget(self, action: #selector(标签按钮点击(_:)), for: .touchUpInside)
            标签堆栈.addArrangedSubview(按钮)
            if 索引 == 0 {
                按钮.isSelected = true
                当前标签按钮 = 按钮
            }
        }

        NSLayoutConstraint.activate([
            标签堆栈.topAnchor.constraint(equalTo: 标签栏.topAnchor),
            标签堆栈.leadingAnchor.constraint(equalTo: 标签栏.leadingAnchor, constant: 8),
            标签堆栈.trailingAnchor.constraint(equalTo: 标签栏.trailingAnchor, constant: -8),
            标签堆栈.bottomAnchor.constraint(equalTo: 标签栏.bottomAnchor)
        ])
    }

    /// 构建五个页面的按钮网格
    private func 构建页面() {
        for 页面 in 页面定义 {
            let 页面容器 = UIView()
            页面容器.translatesAutoresizingMaskIntoConstraints = false
            页面容器.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width).isActive = true

            // 英文页面使用自定义QWERTY布局
            if 页面.名称 == "英文" {
                构建英文页面(容器: 页面容器)
                页面堆栈.addArrangedSubview(页面容器)
                continue
            }

            // 垂直滚动容器（按钮多时可上下滚动）
            let 滚动视图 = UIScrollView()
            滚动视图.showsVerticalScrollIndicator = false
            滚动视图.showsHorizontalScrollIndicator = false
            滚动视图.alwaysBounceVertical = true
            滚动视图.translatesAutoresizingMaskIntoConstraints = false
            页面容器.addSubview(滚动视图)

            // 按钮网格（用UICollectionView更灵活，但UIStackView更简单且iOS14兼容）
            let 网格堆栈 = UIStackView()
            网格堆栈.axis = .vertical
            网格堆栈.spacing = 6 // 行间距6pt，紧凑排列
            网格堆栈.alignment = .fill
            网格堆栈.translatesAutoresizingMaskIntoConstraints = false
            滚动视图.addSubview(网格堆栈)

            // 每行5个按钮
            let 每行按钮数 = 5
            for 行起始 in stride(from: 0, to: 页面.按钮列表.count, by: 每行按钮数) {
                let 行堆栈 = UIStackView()
                行堆栈.axis = .horizontal
                行堆栈.spacing = 6 // 列间距6pt
                行堆栈.distribution = .fillEqually
                行堆栈.alignment = .fill

                let 行结束 = min(行起始 + 每行按钮数, 页面.按钮列表.count)
                for 索引 in 行起始..<行结束 {
                    let 数据 = 页面.按钮列表[索引]
                    let 按钮 = 键盘按键按钮(type: .system)
                    按钮.按钮数据 = 数据
                    按钮.setTitle(数据.显示文本, for: .normal)
                    按钮.titleLabel?.font = .monospacedSystemFont(ofSize: 数据.字体大小, weight: .regular)
                    按钮.setTitleColor(.label, for: .normal)
                    按钮.backgroundColor = .systemBackground // 白色按键，与系统键盘一致
                    按钮.layer.cornerRadius = 6 // 6pt圆角，按键风格
                    按钮.layer.shadowColor = UIColor.black.cgColor
                    按钮.layer.shadowOpacity = 0.15
                    按钮.layer.shadowOffset = CGSize(width: 0, height: 1)
                    按钮.layer.shadowRadius = 1
                    按钮.contentEdgeInsets = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
                    按钮.addTarget(self, action: #selector(按键按钮点击(_:)), for: .touchUpInside)
                    行堆栈.addArrangedSubview(按钮)
                }
                // 不足一行时用占位填充
                if 行结束 - 行起始 < 每行按钮数 {
                    for _ in 0..<(每行按钮数 - (行结束 - 行起始)) {
                        let 占位 = UIView()
                        占位.backgroundColor = .clear
                        行堆栈.addArrangedSubview(占位)
                    }
                }
                网格堆栈.addArrangedSubview(行堆栈)
            }

            // 页面容器宽度已在上方设置

            NSLayoutConstraint.activate([
                滚动视图.topAnchor.constraint(equalTo: 页面容器.topAnchor, constant: 8),
                滚动视图.leadingAnchor.constraint(equalTo: 页面容器.leadingAnchor, constant: 8),
                滚动视图.trailingAnchor.constraint(equalTo: 页面容器.trailingAnchor, constant: -8),
                滚动视图.bottomAnchor.constraint(equalTo: 页面容器.bottomAnchor, constant: -8),

                网格堆栈.topAnchor.constraint(equalTo: 滚动视图.topAnchor),
                网格堆栈.leadingAnchor.constraint(equalTo: 滚动视图.leadingAnchor),
                网格堆栈.trailingAnchor.constraint(equalTo: 滚动视图.trailingAnchor),
                网格堆栈.bottomAnchor.constraint(equalTo: 滚动视图.bottomAnchor),
                网格堆栈.widthAnchor.constraint(equalTo: 滚动视图.widthAnchor)
            ])

            页面堆栈.addArrangedSubview(页面容器)
        }
    }

    // MARK: - 英文26键键盘页面

    /// 构建英文QWERTY键盘页面（3行布局，带Shift大小写切换）
    private func 构建英文页面(容器: UIView) {
        // 主垂直堆栈
        let 主堆栈 = UIStackView()
        主堆栈.axis = .vertical
        主堆栈.spacing = 8 // 行间距8pt，标准键盘行距
        主堆栈.alignment = .fill
        主堆栈.translatesAutoresizingMaskIntoConstraints = false
        容器.addSubview(主堆栈)

        // 第一行：Q W E R T Y U I O P
        let 第一行 = 创建英文行(字母: ["Q","W","E","R","T","Y","U","I","O","P"], 左右边距: 0)
        主堆栈.addArrangedSubview(第一行)

        // 第二行：A S D F G H J K L（左右留边距，模拟真实键盘错位）
        let 第二行 = 创建英文行(字母: ["A","S","D","F","G","H","J","K","L"], 左右边距: 16)
        主堆栈.addArrangedSubview(第二行)

        // 第三行：Shift + Z X C V B N M + 删除
        let 第三行 = UIStackView()
        第三行.axis = .horizontal
        第三行.spacing = 6 // 列间距6pt
        第三行.alignment = .fill
        第三行.distribution = .fill

        // Shift按钮
        let shift按钮 = UIButton(type: .system)
        shift按钮.setTitle("⇧", for: .normal)
        shift按钮.titleLabel?.font = .systemFont(ofSize: 18, weight: .regular) // 18ptShift图标
        shift按钮.setTitleColor(.label, for: .normal)
        shift按钮.backgroundColor = .systemGray5 // Shift键灰色底，与功能键一致
        shift按钮.layer.cornerRadius = 6
        shift按钮.layer.shadowColor = UIColor.black.cgColor
        shift按钮.layer.shadowOpacity = 0.15
        shift按钮.layer.shadowOffset = CGSize(width: 0, height: 1)
        shift按钮.layer.shadowRadius = 1
        shift按钮.addTarget(self, action: #selector(英文shift按钮点击), for: .touchUpInside)
        shift按钮.translatesAutoresizingMaskIntoConstraints = false
        shift按钮.widthAnchor.constraint(equalToConstant: 44).isActive = true // Shift键44pt宽
        英文shift按钮 = shift按钮
        第三行.addArrangedSubview(shift按钮)

        // Z X C V B N M 七个字母
        let 字母行内堆栈 = UIStackView()
        字母行内堆栈.axis = .horizontal
        字母行内堆栈.spacing = 6
        字母行内堆栈.distribution = .fillEqually
        字母行内堆栈.alignment = .fill
        for 字母 in ["Z","X","C","V","B","N","M"] {
            let 按钮 = 创建英文字母按钮(字母: 字母)
            字母行内堆栈.addArrangedSubview(按钮)
        }
        第三行.addArrangedSubview(字母行内堆栈)

        // 删除按钮
        let 删除按钮 = UIButton(type: .system)
        删除按钮.setTitle("⌫", for: .normal)
        删除按钮.titleLabel?.font = .systemFont(ofSize: 18, weight: .regular)
        删除按钮.setTitleColor(.label, for: .normal)
        删除按钮.backgroundColor = .systemGray5
        删除按钮.layer.cornerRadius = 6
        删除按钮.layer.shadowColor = UIColor.black.cgColor
        删除按钮.layer.shadowOpacity = 0.15
        删除按钮.layer.shadowOffset = CGSize(width: 0, height: 1)
        删除按钮.layer.shadowRadius = 1
        删除按钮.addTarget(self, action: #selector(删除按钮点击), for: .touchUpInside)
        删除按钮.translatesAutoresizingMaskIntoConstraints = false
        删除按钮.widthAnchor.constraint(equalToConstant: 44).isActive = true // 删除键44pt宽
        第三行.addArrangedSubview(删除按钮)

        主堆栈.addArrangedSubview(第三行)

        // 布局约束：垂直居中，左右留边距
        NSLayoutConstraint.activate([
            主堆栈.centerYAnchor.constraint(equalTo: 容器.centerYAnchor),
            主堆栈.leadingAnchor.constraint(equalTo: 容器.leadingAnchor, constant: 8), // 左边距8pt
            主堆栈.trailingAnchor.constraint(equalTo: 容器.trailingAnchor, constant: -8), // 右边距8pt
        ])

        // 初始刷新（设置为小写）
        刷新英文页面()
    }

    /// 创建一行英文字母按钮
    private func 创建英文行(字母: [String], 左右边距: CGFloat) -> UIView {
        let 行容器 = UIView()
        行容器.translatesAutoresizingMaskIntoConstraints = false

        let 行堆栈 = UIStackView()
        行堆栈.axis = .horizontal
        行堆栈.spacing = 6 // 列间距6pt
        行堆栈.distribution = .fillEqually
        行堆栈.alignment = .fill
        行堆栈.translatesAutoresizingMaskIntoConstraints = false
        行容器.addSubview(行堆栈)

        for 字母 in 字母 {
            let 按钮 = 创建英文字母按钮(字母: 字母)
            行堆栈.addArrangedSubview(按钮)
        }

        NSLayoutConstraint.activate([
            行堆栈.topAnchor.constraint(equalTo: 行容器.topAnchor),
            行堆栈.bottomAnchor.constraint(equalTo: 行容器.bottomAnchor),
            行堆栈.leadingAnchor.constraint(equalTo: 行容器.leadingAnchor, constant: 左右边距),
            行堆栈.trailingAnchor.constraint(equalTo: 行容器.trailingAnchor, constant: -左右边距),
            行容器.heightAnchor.constraint(equalToConstant: 40) // 字母键40pt高，标准触控高度
        ])

        return 行容器
    }

    /// 创建单个英文字母按钮
    private func 创建英文字母按钮(字母: String) -> 键盘按键按钮 {
        let 按钮 = 键盘按键按钮(type: .system)
        按钮.是否为字母键 = true
        按钮.字母小写 = 字母.lowercased()
        按钮.字母大写 = 字母.uppercased()
        按钮.setTitle(字母.lowercased(), for: .normal)
        按钮.titleLabel?.font = .systemFont(ofSize: 18, weight: .regular) // 18pt字母，清晰易读
        按钮.setTitleColor(.label, for: .normal)
        按钮.backgroundColor = .systemBackground // 白色按键
        按钮.layer.cornerRadius = 6 // 6pt圆角
        按钮.layer.shadowColor = UIColor.black.cgColor
        按钮.layer.shadowOpacity = 0.15
        按钮.layer.shadowOffset = CGSize(width: 0, height: 1)
        按钮.layer.shadowRadius = 1
        按钮.addTarget(self, action: #selector(字母按钮点击(_:)), for: .touchUpInside)
        英文字母按钮列表.append(按钮)
        return 按钮
    }

    /// 刷新英文页面所有字母按钮的大小写显示
    private func 刷新英文页面() {
        for 按钮 in 英文字母按钮列表 {
            let 显示文本 = 大写模式 ? 按钮.字母大写 : 按钮.字母小写
            按钮.setTitle(显示文本, for: .normal)
        }
        // 更新Shift按钮外观
        英文shift按钮?.backgroundColor = 大写模式 ? .systemBlue : .systemGray5
        英文shift按钮?.setTitleColor(大写模式 ? .white : .label, for: .normal)
    }

    /// 英文Shift按钮点击：切换大小写
    @objc private func 英文shift按钮点击() {
        大写模式.toggle()
        刷新英文页面()
    }

    /// 英文字母按钮点击：根据当前大小写模式插入对应字母
    @objc private func 字母按钮点击(_ 按钮: 键盘按键按钮) {
        let 插入文本 = 大写模式 ? 按钮.字母大写 : 按钮.字母小写
        插入文本回调?(插入文本)
        // 输入一个字母后自动切回小写（模拟系统键盘行为）
        if 大写模式 {
            大写模式 = false
            刷新英文页面()
        }
    }

    /// 构建底部功能行（Tab、空格、删除、换行、切换键盘）
    private func 构建底部功能行() {
        let 功能堆栈 = UIStackView()
        功能堆栈.axis = .horizontal
        功能堆栈.spacing = 8 // 功能按钮间距8pt
        功能堆栈.alignment = .fill
        功能堆栈.distribution = .fill
        功能堆栈.translatesAutoresizingMaskIntoConstraints = false
        底部功能行.addSubview(功能堆栈)

        // 缩进按钮
        let 缩进按钮 = 创建功能按钮(标题: "Tab", 符号: "⇥", 字号: 14)
        缩进按钮.addTarget(self, action: #selector(缩进按钮点击), for: .touchUpInside)

        // 空格按钮（弹性宽度）
        let 空格按钮 = 创建功能按钮(标题: "空格", 符号: "", 字号: 14)
        空格按钮.addTarget(self, action: #selector(空格按钮点击), for: .touchUpInside)

        // 删除按钮
        let 删除按钮 = 创建功能按钮(标题: "删除", 符号: "⌫", 字号: 16)
        删除按钮.addTarget(self, action: #selector(删除按钮点击), for: .touchUpInside)

        // 换行按钮
        let 换行按钮 = 创建功能按钮(标题: "换行", 符号: "↵", 字号: 16)
        换行按钮.addTarget(self, action: #selector(换行按钮点击), for: .touchUpInside)

        // 切换系统键盘按钮
        let 切换按钮 = 创建功能按钮(标题: "系统", 符号: "⌨", 字号: 14)
        切换按钮.addTarget(self, action: #selector(切换键盘按钮点击), for: .touchUpInside)

        功能堆栈.addArrangedSubview(缩进按钮)
        功能堆栈.addArrangedSubview(空格按钮)
        功能堆栈.addArrangedSubview(删除按钮)
        功能堆栈.addArrangedSubview(换行按钮)
        功能堆栈.addArrangedSubview(切换按钮)

        // 空格按钮占据弹性空间
        空格按钮.widthAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true // 空格按钮最小80pt宽

        NSLayoutConstraint.activate([
            功能堆栈.topAnchor.constraint(equalTo: 底部功能行.topAnchor, constant: 6),
            功能堆栈.leadingAnchor.constraint(equalTo: 底部功能行.leadingAnchor, constant: 8),
            功能堆栈.trailingAnchor.constraint(equalTo: 底部功能行.trailingAnchor, constant: -8),
            功能堆栈.bottomAnchor.constraint(equalTo: 底部功能行.bottomAnchor, constant: -6)
        ])
    }

    /// 创建功能行按钮
    private func 创建功能按钮(标题: String, 符号: String, 字号: CGFloat) -> UIButton {
        let 按钮 = UIButton(type: .system)
        let 显示文本 = 符号.isEmpty ? 标题 : "\(符号) \(标题)"
        按钮.setTitle(显示文本, for: .normal)
        按钮.titleLabel?.font = .systemFont(ofSize: 字号, weight: .medium)
        按钮.setTitleColor(.label, for: .normal)
        按钮.backgroundColor = .systemBackground
        按钮.layer.cornerRadius = 6
        按钮.layer.shadowColor = UIColor.black.cgColor
        按钮.layer.shadowOpacity = 0.15
        按钮.layer.shadowOffset = CGSize(width: 0, height: 1)
        按钮.layer.shadowRadius = 1
        按钮.translatesAutoresizingMaskIntoConstraints = false
        按钮.widthAnchor.constraint(equalToConstant: 60).isActive = true // 功能按钮固定60pt宽
        return 按钮
    }

    // MARK: - 按钮点击处理

    @objc private func 标签按钮点击(_ 按钮: 键盘标签按钮) {
        当前标签按钮?.isSelected = false
        按钮.isSelected = true
        当前标签按钮 = 按钮
        let 偏移量 = CGPoint(x: CGFloat(按钮.页面索引) * 页面滚动视图.bounds.width, y: 0)
        页面滚动视图.setContentOffset(偏移量, animated: true)
    }

    @objc private func 按键按钮点击(_ 按钮: 键盘按键按钮) {
        guard let 数据 = 按钮.按钮数据 else { return }
        插入文本回调?(数据.插入文本)
    }

    @objc private func 缩进按钮点击() {
        缩进回调?()
    }

    @objc private func 空格按钮点击() {
        插入文本回调?(" ")
    }

    @objc private func 删除按钮点击() {
        删除字符回调?()
    }

    @objc private func 换行按钮点击() {
        换行回调?()
    }

    @objc private func 切换键盘按钮点击() {
        切换系统键盘回调?()
    }
}

// MARK: - UIScrollViewDelegate（页面切换同步标签）

extension 代码键盘视图: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ 滚动视图: UIScrollView) {
        guard 滚动视图 === 页面滚动视图 else { return }
        let 页面索引 = Int(滚动视图.contentOffset.x / 滚动视图.bounds.width)
        // 同步标签选中状态
        if let 标签堆栈 = 标签栏.subviews.first as? UIStackView {
            for (索引, 视图) in 标签堆栈.arrangedSubviews.enumerated() {
                if let 按钮 = 视图 as? 键盘标签按钮 {
                    按钮.isSelected = (索引 == 页面索引)
                    if 索引 == 页面索引 { 当前标签按钮 = 按钮 }
                }
            }
        }
    }
}

// MARK: - 键盘按钮数据模型

/// 键盘按键按钮数据
struct 键盘按钮数据 {
    /// 按钮显示文本
    let 显示文本: String
    /// 实际插入的文本
    let 插入文本: String
    /// 字体大小（长文本用小字号）
    let 字体大小: CGFloat
}

/// 标签按钮（关联页面索引）
final class 键盘标签按钮: UIButton {
    var 页面索引: Int = 0
}

/// 按键按钮（关联按钮数据）
final class 键盘按键按钮: UIButton {
    /// 关联的按钮数据
    var 按钮数据: 键盘按钮数据?
    /// 是否为英文字母键（用于大小写切换）
    var 是否为字母键: Bool = false
    /// 字母小写形式
    var 字母小写: String = ""
    /// 字母大写形式
    var 字母大写: String = ""
}

// MARK: - 键盘数据定义

/// 代码键盘所有页面的按钮数据
enum 代码键盘数据 {
    // MARK: - 符号页

    /// 符号按钮列表
    static let 符号按钮: [键盘按钮数据] = [
        键盘按钮数据(显示文本: "$", 插入文本: "$", 字体大小: 18),
        键盘按钮数据(显示文本: "{", 插入文本: "{}", 字体大小: 18),
        键盘按钮数据(显示文本: "}", 插入文本: "}", 字体大小: 18),
        键盘按钮数据(显示文本: "(", 插入文本: "()", 字体大小: 18),
        键盘按钮数据(显示文本: ")", 插入文本: ")", 字体大小: 18),
        键盘按钮数据(显示文本: "[", 插入文本: "[]", 字体大小: 18),
        键盘按钮数据(显示文本: "]", 插入文本: "]", 字体大小: 18),
        键盘按钮数据(显示文本: "=", 插入文本: " = ", 字体大小: 18),
        键盘按钮数据(显示文本: "==", 插入文本: " == ", 字体大小: 16),
        键盘按钮数据(显示文本: "===", 插入文本: " === ", 字体大小: 14),
        键盘按钮数据(显示文本: "!=", 插入文本: " != ", 字体大小: 16),
        键盘按钮数据(显示文本: "!==", 插入文本: " !== ", 字体大小: 14),
        键盘按钮数据(显示文本: ";", 插入文本: ";", 字体大小: 18),
        键盘按钮数据(显示文本: ":", 插入文本: ": ", 字体大小: 18),
        键盘按钮数据(显示文本: ".", 插入文本: ".", 字体大小: 18),
        键盘按钮数据(显示文本: ",", 插入文本: ", ", 字体大小: 18),
        键盘按钮数据(显示文本: "\"", 插入文本: "\"\"", 字体大小: 18),
        键盘按钮数据(显示文本: "'", 插入文本: "''", 字体大小: 18),
        键盘按钮数据(显示文本: "`", 插入文本: "``", 字体大小: 18),
        键盘按钮数据(显示文本: "/", 插入文本: "/", 字体大小: 18),
        键盘按钮数据(显示文本: "\\", 插入文本: "\\", 字体大小: 18),
        键盘按钮数据(显示文本: "|", 插入文本: "|", 字体大小: 18),
        键盘按钮数据(显示文本: "||", 插入文本: " || ", 字体大小: 16),
        键盘按钮数据(显示文本: "&", 插入文本: "&", 字体大小: 18),
        键盘按钮数据(显示文本: "&&", 插入文本: " && ", 字体大小: 16),
        键盘按钮数据(显示文本: "!", 插入文本: "!", 字体大小: 18),
        键盘按钮数据(显示文本: "?", 插入文本: "?", 字体大小: 18),
        键盘按钮数据(显示文本: "+", 插入文本: " + ", 字体大小: 18),
        键盘按钮数据(显示文本: "-", 插入文本: " - ", 字体大小: 18),
        键盘按钮数据(显示文本: "*", 插入文本: " * ", 字体大小: 18),
        键盘按钮数据(显示文本: "%", 插入文本: " % ", 字体大小: 18),
        键盘按钮数据(显示文本: "<", 插入文本: " < ", 字体大小: 18),
        键盘按钮数据(显示文本: ">", 插入文本: " > ", 字体大小: 18),
        键盘按钮数据(显示文本: "<=", 插入文本: " <= ", 字体大小: 16),
        键盘按钮数据(显示文本: ">=", 插入文本: " >= ", 字体大小: 16),
        键盘按钮数据(显示文本: "=>", 插入文本: " => ", 字体大小: 16),
        键盘按钮数据(显示文本: "^", 插入文本: "^", 字体大小: 18),
        键盘按钮数据(显示文本: "~", 插入文本: "~", 字体大小: 18),
        键盘按钮数据(显示文本: "#", 插入文本: "#", 字体大小: 18),
        键盘按钮数据(显示文本: "@", 插入文本: "@", 字体大小: 18),
        键盘按钮数据(显示文本: "++", 插入文本: "++", 字体大小: 16),
        键盘按钮数据(显示文本: "--", 插入文本: "--", 字体大小: 16),
        键盘按钮数据(显示文本: "+=", 插入文本: " += ", 字体大小: 16),
        键盘按钮数据(显示文本: "-=", 插入文本: " -= ", 字体大小: 16),
        键盘按钮数据(显示文本: "?:", 插入文本: " ? : ", 字体大小: 14),
        键盘按钮数据(显示文本: "//", 插入文本: "// ", 字体大小: 16),
        键盘按钮数据(显示文本: "/*", 插入文本: "/*  */", 字体大小: 14)
    ]

    // MARK: - 关键字页

    /// JS关键字按钮列表
    static let 关键字按钮: [键盘按钮数据] = [
        键盘按钮数据(显示文本: "function", 插入文本: "function ", 字体大小: 14),
        键盘按钮数据(显示文本: "return", 插入文本: "return ", 字体大小: 14),
        键盘按钮数据(显示文本: "if", 插入文本: "if ", 字体大小: 16),
        键盘按钮数据(显示文本: "else", 插入文本: " else ", 字体大小: 14),
        键盘按钮数据(显示文本: "for", 插入文本: "for ", 字体大小: 16),
        键盘按钮数据(显示文本: "while", 插入文本: "while ", 字体大小: 14),
        键盘按钮数据(显示文本: "do", 插入文本: "do ", 字体大小: 16),
        键盘按钮数据(显示文本: "switch", 插入文本: "switch ", 字体大小: 14),
        键盘按钮数据(显示文本: "case", 插入文本: "case ", 字体大小: 16),
        键盘按钮数据(显示文本: "break", 插入文本: "break;", 字体大小: 14),
        键盘按钮数据(显示文本: "continue", 插入文本: "continue;", 字体大小: 12),
        键盘按钮数据(显示文本: "var", 插入文本: "var ", 字体大小: 16),
        键盘按钮数据(显示文本: "let", 插入文本: "let ", 字体大小: 16),
        键盘按钮数据(显示文本: "const", 插入文本: "const ", 字体大小: 14),
        键盘按钮数据(显示文本: "new", 插入文本: "new ", 字体大小: 16),
        键盘按钮数据(显示文本: "typeof", 插入文本: "typeof ", 字体大小: 14),
        键盘按钮数据(显示文本: "in", 插入文本: " in ", 字体大小: 16),
        键盘按钮数据(显示文本: "of", 插入文本: " of ", 字体大小: 16),
        键盘按钮数据(显示文本: "try", 插入文本: "try ", 字体大小: 16),
        键盘按钮数据(显示文本: "catch", 插入文本: " catch ", 字体大小: 14),
        键盘按钮数据(显示文本: "finally", 插入文本: " finally ", 字体大小: 12),
        键盘按钮数据(显示文本: "throw", 插入文本: "throw ", 字体大小: 14),
        键盘按钮数据(显示文本: "this", 插入文本: "this", 字体大小: 16),
        键盘按钮数据(显示文本: "class", 插入文本: "class ", 字体大小: 16),
        键盘按钮数据(显示文本: "extends", 插入文本: " extends ", 字体大小: 12),
        键盘按钮数据(显示文本: "async", 插入文本: "async ", 字体大小: 14),
        键盘按钮数据(显示文本: "await", 插入文本: "await ", 字体大小: 14),
        键盘按钮数据(显示文本: "null", 插入文本: "null", 字体大小: 16),
        键盘按钮数据(显示文本: "undefined", 插入文本: "undefined", 字体大小: 12),
        键盘按钮数据(显示文本: "true", 插入文本: "true", 字体大小: 16),
        键盘按钮数据(显示文本: "false", 插入文本: "false", 字体大小: 16),
        键盘按钮数据(显示文本: "console.log", 插入文本: "console.log();", 字体大小: 12),
        键盘按钮数据(显示文本: "JSON.parse", 插入文本: "JSON.parse()", 字体大小: 12),
        键盘按钮数据(显示文本: "JSON.stringify", 插入文本: "JSON.stringify()", 字体大小: 10),
        键盘按钮数据(显示文本: "setTimeout", 插入文本: "setTimeout(() => {}, 1000);", 字体大小: 10),
        键盘按钮数据(显示文本: "setInterval", 插入文本: "setInterval(() => {}, 1000);", 字体大小: 10),
        键盘按钮数据(显示文本: "Promise", 插入文本: "new Promise((resolve, reject) => {})", 字体大小: 10),
        键盘按钮数据(显示文本: "=>", 插入文本: " => ", 字体大小: 16),
        键盘按钮数据(显示文本: "instanceof", 插入文本: " instanceof ", 字体大小: 12)
    ]

    // MARK: - 圈X页

    /// 圈X API按钮列表
    static let 圈X按钮: [键盘按钮数据] = [
        键盘按钮数据(显示文本: "$done()", 插入文本: "$done();", 字体大小: 14),
        键盘按钮数据(显示文本: "$request", 插入文本: "$request", 字体大小: 14),
        键盘按钮数据(显示文本: "$response", 插入文本: "$response", 字体大小: 14),
        键盘按钮数据(显示文本: "$notify", 插入文本: "$notify()", 字体大小: 14),
        键盘按钮数据(显示文本: "$persistentStore", 插入文本: "$persistentStore", 字体大小: 12),
        键盘按钮数据(显示文本: "$httpClient", 插入文本: "$httpClient", 字体大小: 14),
        键盘按钮数据(显示文本: "$argument", 插入文本: "$argument", 字体大小: 14),
        键盘按钮数据(显示文本: "$env", 插入文本: "$env", 字体大小: 16),
        键盘按钮数据(显示文本: "$loaddie", 插入文本: "$loaddie", 字体大小: 14),
        键盘按钮数据(显示文本: "req.url", 插入文本: "$request.url", 字体大小: 12),
        键盘按钮数据(显示文本: "req.method", 插入文本: "$request.method", 字体大小: 12),
        键盘按钮数据(显示文本: "req.headers", 插入文本: "$request.headers", 字体大小: 12),
        键盘按钮数据(显示文本: "req.body", 插入文本: "$request.body", 字体大小: 12),
        键盘按钮数据(显示文本: "res.status", 插入文本: "$response.status", 字体大小: 12),
        键盘按钮数据(显示文本: "res.headers", 插入文本: "$response.headers", 字体大小: 12),
        键盘按钮数据(显示文本: "res.body", 插入文本: "$response.body", 字体大小: 12),
        键盘按钮数据(显示文本: "store.write", 插入文本: "$persistentStore.write()", 字体大小: 10),
        键盘按钮数据(显示文本: "store.read", 插入文本: "$persistentStore.read()", 字体大小: 10),
        键盘按钮数据(显示文本: "http.get", 插入文本: "$httpClient.get()", 字体大小: 12),
        键盘按钮数据(显示文本: "http.post", 插入文本: "$httpClient.post()", 字体大小: 12),
        键盘按钮数据(显示文本: "http.put", 插入文本: "$httpClient.put()", 字体大小: 12),
        键盘按钮数据(显示文本: "http.delete", 插入文本: "$httpClient.delete()", 字体大小: 10),
        键盘按钮数据(显示文本: "notify标题", 插入文本: "$notify('标题', '副标题', '内容')", 字体大小: 10),
        键盘按钮数据(显示文本: "done空", 插入文本: "$done({})", 字体大小: 14),
        键盘按钮数据(显示文本: "done响应", 插入文本: "$done({response: $response})", 字体大小: 10),
        键盘按钮数据(显示文本: "done请求", 插入文本: "$done({request: $request})", 字体大小: 10),
        键盘按钮数据(显示文本: "body转JSON", 插入文本: "JSON.parse($response.body)", 字体大小: 10),
        键盘按钮数据(显示文本: "body转字符串", 插入文本: "JSON.stringify(obj)", 字体大小: 10),
        键盘按钮数据(显示文本: "修改URL", 插入文本: "$request.url = ''", 字体大小: 12),
        键盘按钮数据(显示文本: "修改请求头", 插入文本: "$request.headers[''] = ''", 字体大小: 10),
        键盘按钮数据(显示文本: "修改响应体", 插入文本: "$response.body = ''", 字体大小: 10),
        键盘按钮数据(显示文本: "修改状态码", 插入文本: "$response.status = 200", 字体大小: 10)
    ]

    // MARK: - 片段页

    /// 常用代码片段按钮列表
    static let 片段按钮: [键盘按钮数据] = [
        键盘按钮数据(显示文本: "if块", 插入文本: "if (条件) {\n    \n}", 字体大小: 14),
        键盘按钮数据(显示文本: "if-else", 插入文本: "if (条件) {\n    \n} else {\n    \n}", 字体大小: 12),
        键盘按钮数据(显示文本: "for循环", 插入文本: "for (var i = 0; i < 数组.length; i++) {\n    \n}", 字体大小: 10),
        键盘按钮数据(显示文本: "for-in", 插入文本: "for (var 键 in 对象) {\n    \n}", 字体大小: 12),
        键盘按钮数据(显示文本: "while循环", 插入文本: "while (条件) {\n    \n}", 字体大小: 12),
        键盘按钮数据(显示文本: "函数", 插入文本: "function 函数名(参数) {\n    return 结果;\n}", 字体大小: 12),
        键盘按钮数据(显示文本: "箭头函数", 插入文本: "(参数) => {\n    return 结果;\n}", 字体大小: 12),
        键盘按钮数据(显示文本: "try-catch", 插入文本: "try {\n    \n} catch (错误) {\n    console.log(错误);\n}", 字体大小: 10),
        键盘按钮数据(显示文本: "switch", 插入文本: "switch (表达式) {\n    case 值:\n        break;\n    default:\n}", 字体大小: 10),
        键盘按钮数据(显示文本: "http.get", 插入文本: "$httpClient.get({\n    url: '',\n    headers: {}\n}, function(错误, 响应, 数据) {\n    $done();\n});", 字体大小: 10),
        键盘按钮数据(显示文本: "http.post", 插入文本: "$httpClient.post({\n    url: '',\n    headers: {},\n    body: ''\n}, function(错误, 响应, 数据) {\n    $done();\n});", 字体大小: 10),
        键盘按钮数据(显示文本: "通知", 插入文本: "$notify('标题', '副标题', '内容');", 字体大小: 12),
        键盘按钮数据(显示文本: "存储写入", 插入文本: "$persistentStore.write(数据, '键名');", 字体大小: 10),
        键盘按钮数据(显示文本: "存储读取", 插入文本: "var 值 = $persistentStore.read('键名');", 字体大小: 10),
        键盘按钮数据(显示文本: "请求类型头", 插入文本: "var 类型 = typeof $response === 'object' ? 'response' : 'request';", 字体大小: 10),
        键盘按钮数据(显示文本: "脚本头注释", 插入文本: "/*\n脚本名称：\n功能说明：\n作者：\n版本：1.0\n*/", 字体大小: 10),
        键盘按钮数据(显示文本: "单行注释", 插入文本: "// ", 字体大小: 14),
        键盘按钮数据(显示文本: "修改URL模板", 插入文本: "if ($request.url.indexOf('关键词') != -1) {\n    $request.url = $request.url.replace('旧', '新');\n}\n$done({request: $request});", 字体大小: 10),
        键盘按钮数据(显示文本: "修改响应模板", 插入文本: "var 数据 = JSON.parse($response.body);\n数据.字段 = '新值';\n$response.body = JSON.stringify(数据);\n$done({response: $response});", 字体大小: 10),
        键盘按钮数据(显示文本: "拦截请求模板", 插入文本: "if ($request.url.indexOf('关键词') != -1) {\n    $done({response: {status: 200, body: '{}'}});\n} else {\n    $done({request: $request});\n}", 字体大小: 10),
        键盘按钮数据(显示文本: "超时保护", 插入文本: "var 计时器 = setTimeout(function() {\n    $done();\n}, 5000);", 字体大小: 10),
        键盘按钮数据(显示文本: "环境判断", 插入文本: "if (typeof $request !== 'undefined') {\n    // 请求类型\n} else if (typeof $response !== 'undefined') {\n    // 响应类型\n}", 字体大小: 10),
        键盘按钮数据(显示文本: "参数读取", 插入文本: "var 参数 = $argument || '默认值';", 字体大小: 12),
        键盘按钮数据(显示文本: "URL解析", 插入文本: "var url = new URL($request.url);\nvar 参数 = url.searchParams.get('参数名');", 字体大小: 10),
        键盘按钮数据(显示文本: "Base64编码", 插入文本: "var 编码 = $text.base64String('内容');", 字体大小: 10)
    ]
}
