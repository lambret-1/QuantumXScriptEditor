import Foundation
import UIKit

// MARK: - 全局应用常量
enum 应用常量 {
    /// 编辑器基础字体大小（pt），调整此值可改变代码显示清晰度
    static let 编辑器基础字体大小: CGFloat = 14
    /// 行号区域宽度（pt），加宽可显示更多行号位数
    static let 行号区域宽度: CGFloat = 48
    /// 编辑器左右内边距（pt），防止文字贴边影响阅读
    static let 编辑器水平内边距: CGFloat = 8
    /// 工具栏内边距（pt），控制工具栏按钮与边缘间距
    static let 工具栏内边距: CGFloat = 16
    /// 静态检查最大扫描行数，超过此行数仅做基础检查避免卡顿
    static let 静态检查最大行数 = 2000
    /// JS沙箱执行超时时间（秒），超时自动终止防止死循环卡死
    static let 沙箱超时秒数: TimeInterval = 8
    /// 测试输出框最小高度（pt），保证输出区域有足够可视空间
    static let 测试输出最小高度: CGFloat = 180
    /// 请求头编辑框高度（pt），控制Header输入区域大小
    static let 请求头编辑高度: CGFloat = 90
    /// 代码补全弹窗最大高度（pt），限制候选列表不超出屏幕
    static let 补全弹窗最大高度: CGFloat = 240
    /// 圆角半径（pt），统一卡片和按钮圆角风格
    static let 统一圆角: CGFloat = 12
    /// 卡片内边距（pt），统一内容卡片的内边距
    static let 卡片内边距: CGFloat = 16
}

// MARK: - 语法高亮颜色令牌
enum 语法颜色 {
    /// 普通文本颜色，跟随系统明暗模式
    static let 普通文本: UIColor = .label
    /// 注释颜色（绿色），区分代码与说明文字
    static let 注释: UIColor = .systemGreen
    /// 字符串颜色（橙色），高亮引号包裹的文本
    static let 字符串: UIColor = .systemOrange
    /// JS关键字颜色（蓝色），高亮语言保留字
    static let JS关键字: UIColor = .systemBlue
    /// 圈X内置对象颜色（红色），醒目提示平台API
    static let 圈X对象: UIColor = .systemRed
    /// 行号文本颜色（次级），弱化行号避免干扰代码
    static let 行号文本: UIColor = .secondaryLabel
}

// MARK: - 语法关键字集合
enum 语法关键字 {
    /// JavaScript语言保留关键字
    static let JS关键字列表 = ["const", "let", "var", "function", "return", "if", "else", "for", "while", "try", "catch", "finally", "new", "class", "extends", "async", "await", "throw", "typeof", "instanceof"]
    /// 圈X平台内置全局对象
    static let 圈X对象列表 = ["$request", "$response", "$notify", "$persistentStore", "$httpClient", "$done", "$delay", "$task"]
}

// MARK: - 应用错误类型
enum 应用错误: LocalizedError {
    /// 文件读写失败
    case 文件读写失败(String)
    /// 脚本名称为空
    case 脚本名称为空
    /// URL格式无效
    case URL格式无效(String)
    /// JS执行异常
    case JS执行异常(String)
    /// 网络请求失败
    case 网络请求失败(String)

    var errorDescription: String? {
        switch self {
        case .文件读写失败(let 详情):
            return "文件读写失败：\(详情)"
        case .脚本名称为空:
            return "脚本名称不能为空"
        case .URL格式无效(let 地址):
            return "URL格式无效：\(地址)"
        case .JS执行异常(let 详情):
            return "JS执行异常：\(详情)"
        case .网络请求失败(let 详情):
            return "网络请求失败：\(详情)"
        }
    }
}
