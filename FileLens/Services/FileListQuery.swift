/**
 * 挟山超海
 *
 * 负山跨海、挟昆仑越四海；用于极端负重与超距搬运（设定）。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import Foundation
import SwiftData

/// 侧栏分类 / 搜索下的文件列表查询（主线程 ModelContext,与 memo 配合）。
enum FileListQuery {
    struct ListFetchResult {
        let files: [FileSnapshot]
        let tagsByFileID: [UUID: [String]]
    }

    static func ruleID(for selection: SidebarSelection?, rules: [Rule]) -> UUID? {
        guard case .tag(_, let name) = selection else { return nil }
        return rules.first(where: { $0.name == name })?.id
    }

    @MainActor
    static func fetchSync(
        storeCtx: ModelContext,
        selection: SidebarSelection?,
        ruleID: UUID?,
        search: String
    ) -> ListFetchResult {
        let nodes = fetchNodes(storeCtx: storeCtx, selection: selection, ruleID: ruleID)
        return build(from: nodes, search: search)
    }

    private static func fetchNodes(
        storeCtx: ModelContext,
        selection: SidebarSelection?,
        ruleID: UUID?
    ) -> [FileNode] {
        let sortByDateAddedDesc = [SortDescriptor(\FileNode.dateAdded, order: .reverse)]
        switch selection {
        case .tag:
            guard let ruleID else { return [] }
            let descriptor = FetchDescriptor<FileNode>(
                predicate: #Predicate<FileNode> { f in
                    f.isPresent && f.tags.contains { $0.ruleID == ruleID }
                },
                sortBy: sortByDateAddedDesc
            )
            return (try? storeCtx.fetch(descriptor)) ?? []
        case .manualTag(_, let name):
            let descriptor = FetchDescriptor<FileNode>(
                predicate: #Predicate<FileNode> { f in
                    f.isPresent && f.tags.contains { $0.source == "manual" && $0.name == name }
                },
                sortBy: sortByDateAddedDesc
            )
            return (try? storeCtx.fetch(descriptor)) ?? []
        case .uncategorized:
            let descriptor = FetchDescriptor<FileNode>(
                predicate: #Predicate<FileNode> { f in
                    f.isPresent && f.tags.isEmpty
                },
                sortBy: sortByDateAddedDesc
            )
            return (try? storeCtx.fetch(descriptor)) ?? []
        default:
            let descriptor = FetchDescriptor<FileNode>(
                predicate: #Predicate<FileNode> { $0.isPresent },
                sortBy: sortByDateAddedDesc
            )
            return (try? storeCtx.fetch(descriptor)) ?? []
        }
    }

    /// 同一次 node 列表构造 snapshot + tags map,仅覆盖当前侧栏分类,不扫全库 FileTag。
    private static func build(from nodes: [FileNode], search: String) -> ListFetchResult {
        let filtered: [FileNode] = search.isEmpty
            ? nodes
            : nodes.filter { $0.name.localizedCaseInsensitiveContains(search) }
        var files: [FileSnapshot] = []
        var tagsByFileID: [UUID: [String]] = [:]
        files.reserveCapacity(filtered.count)
        tagsByFileID.reserveCapacity(filtered.count)
        for node in filtered {
            files.append(FileSnapshot(node))
            let names = node.tags.map(\.name)
            if !names.isEmpty {
                tagsByFileID[node.id] = names
            }
        }
        return ListFetchResult(files: files, tagsByFileID: tagsByFileID)
    }
}
