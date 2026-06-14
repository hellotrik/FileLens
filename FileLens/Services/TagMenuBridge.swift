/**
 * 掌握五雷
 *
 * 五雷为五炁会聚之妙用；可驱雷役电、祷雨祈晴、降魔禳灾、炼度幽魂等。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import Foundation
import SwiftData

/// 把 ContentView 的标签菜单回调桥接到 NSViewRepresentable 里的
/// `FileContextMenu`(NSTableView cell 的 NSHostingView 拿不到外层 Environment)。
@MainActor
enum TagMenuBridge {
    static var onAddTag: (([FileNode]) -> Void)?
    static var onClearManualTags: (([FileNode]) -> Void)?
    static var onClearAllTags: (([FileNode]) -> Void)?
    static var onRemoveManualTag: ((FileNode, String) -> Void)?
}
