import Foundation
import SwiftUI

/// 脚本本地文件存储服务，负责JS脚本的持久化读写
/// 存储位置：App文档目录下的 QuantumXScripts 文件夹
@MainActor
final class 脚本存储: ObservableObject {
    /// 已加载的脚本列表
    @Published var 脚本列表: [脚本模型] = []
    /// 脚本存储文件夹URL
    let 存储文件夹URL: URL

    /// 初始化存储服务，自动创建目录并加载已有脚本
    init() {
        let 文档目录 = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        存储文件夹URL = 文档目录.appendingPathComponent("QuantumXScripts", isDirectory: true)
        创建存储目录()
        加载全部脚本()
    }

    /// 创建脚本存储目录，若已存在则不做处理
    private func 创建存储目录() {
        guard !FileManager.default.fileExists(atPath: 存储文件夹URL.path) else { return }
        do {
            try FileManager.default.createDirectory(at: 存储文件夹URL, withIntermediateDirectories: true)
        } catch {
            debugPrint("创建脚本存储目录失败：\(error.localizedDescription)")
        }
    }

    /// 从本地磁盘加载全部.js脚本文件到内存
    func 加载全部脚本() {
        do {
            let 文件列表 = try FileManager.default.contentsOfDirectory(at: 存储文件夹URL, includingPropertiesForKeys: nil)
            var 临时列表: [脚本模型] = []
            for 文件URL in 文件列表 where 文件URL.pathExtension == "js" {
                do {
                    let 内容 = try String(contentsOf: 文件URL, encoding: .utf8)
                    let 名称 = 文件URL.deletingPathExtension().lastPathComponent
                    let 脚本 = 脚本模型(名称: 名称, 内容: 内容)
                    临时列表.append(脚本)
                } catch {
                    debugPrint("读取脚本失败 \(文件URL.lastPathComponent)：\(error.localizedDescription)")
                }
            }
            临时列表.sort { $0.修改时间 > $1.修改时间 }
            脚本列表 = 临时列表
        } catch {
            debugPrint("扫描脚本目录失败：\(error.localizedDescription)")
            脚本列表 = []
        }
    }

    /// 保存脚本到本地磁盘
    /// - Parameter 脚本: 待保存的脚本模型
    /// - Throws: 应用错误.文件读写失败
    func 保存脚本(_ 脚本: 脚本模型) throws {
        guard !脚本.名称.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw 应用错误.脚本名称为空
        }
        let 文件URL = 存储文件夹URL.appendingPathComponent("\(脚本.名称).js")
        do {
            try 脚本.内容.write(to: 文件URL, atomically: true, encoding: .utf8)
            加载全部脚本()
        } catch {
            throw 应用错误.文件读写失败(error.localizedDescription)
        }
    }

    /// 删除脚本文件
    /// - Parameter 脚本: 待删除的脚本模型
    /// - Throws: 应用错误.文件读写失败
    func 删除脚本(_ 脚本: 脚本模型) throws {
        let 文件URL = 存储文件夹URL.appendingPathComponent("\(脚本.名称).js")
        do {
            try FileManager.default.removeItem(at: 文件URL)
            加载全部脚本()
        } catch {
            throw 应用错误.文件读写失败(error.localizedDescription)
        }
    }

    /// 重命名脚本
    /// - Parameters:
    ///   - 脚本: 原脚本
    ///   - 新名称: 新名称（不含扩展名）
    func 重命名脚本(_ 脚本: 脚本模型, 新名称: String) throws {
        guard !新名称.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw 应用错误.脚本名称为空
        }
        let 旧文件URL = 存储文件夹URL.appendingPathComponent("\(脚本.名称).js")
        let 新文件URL = 存储文件夹URL.appendingPathComponent("\(新名称).js")
        do {
            try FileManager.default.moveItem(at: 旧文件URL, to: 新文件URL)
            加载全部脚本()
        } catch {
            throw 应用错误.文件读写失败(error.localizedDescription)
        }
    }

    /// 获取脚本对应的本地文件URL
    /// - Parameter 脚本: 脚本模型
    /// - Returns: .js文件的本地URL
    func 获取脚本文件URL(_ 脚本: 脚本模型) -> URL {
        存储文件夹URL.appendingPathComponent("\(脚本.名称).js")
    }
}
