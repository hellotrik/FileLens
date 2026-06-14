/**
 * 挟山超海
 *
 * 负山跨海、挟昆仑越四海；用于极端负重与超距搬运（设定）。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import Foundation
import SwiftData

/// 侧栏分类 / 搜索下的文件列表查询（主线程 ModelContext,与 memo / loader 配合）。
enum FileListQuery {
    static let defaultPageSize = 400

    static func ruleID(for selection: SidebarSelection?, rules: [Rule]) -> UUID? {
        guard case .tag(_, let name) = selection else { return nil }
        return rules.first(where: { $0.name == name })?.id
    }

    static func makeDescriptor(
        selection: SidebarSelection?,
        ruleID: UUID?
    ) -> FetchDescriptor<FileNode> {
        let sortByDateAddedDesc = [SortDescriptor(\FileNode.dateAdded, order: .reverse)]
        switch selection {
        case .tag:
            guard let ruleID else {
                return FetchDescriptor<FileNode>(
                    predicate: #Predicate<FileNode> { _ in false }
                )
            }
            let rid = ruleID
            return FetchDescriptor<FileNode>(
                predicate: #Predicate<FileNode> { f in
                    f.isPresent && f.tags.contains { $0.ruleID == rid }
                },
                sortBy: sortByDateAddedDesc
            )
        case .manualTag(_, let name):
            return FetchDescriptor<FileNode>(
                predicate: #Predicate<FileNode> { f in
                    f.isPresent && f.tags.contains { $0.source == "manual" && $0.name == name }
                },
                sortBy: sortByDateAddedDesc
            )
        case .uncategorized:
            return FetchDescriptor<FileNode>(
                predicate: #Predicate<FileNode> { f in
                    f.isPresent && f.tags.isEmpty
                },
                sortBy: sortByDateAddedDesc
            )
        default:
            return FetchDescriptor<FileNode>(
                predicate: #Predicate<FileNode> { $0.isPresent },
                sortBy: sortByDateAddedDesc
            )
        }
    }

    @MainActor
    static func fetchPage(
        storeCtx: ModelContext,
        descriptor: FetchDescriptor<FileNode>,
        offset: Int,
        limit: Int
    ) -> [FileNode] {
        var page = descriptor
        page.fetchOffset = offset
        page.fetchLimit = limit
        return (try? storeCtx.fetch(page)) ?? []
    }

    @MainActor
    static func fetchAll(
        storeCtx: ModelContext,
        selection: SidebarSelection?,
        ruleID: UUID?
    ) -> [FileNode] {
        let descriptor = makeDescriptor(selection: selection, ruleID: ruleID)
        return (try? storeCtx.fetch(descriptor)) ?? []
    }

    /// 只建 FileSnapshot,不读 tags 关系 —— tags 由 loader 分批 lazy 加载。
    static func snapshots(from nodes: [FileNode], search: String) -> [FileSnapshot] {
        let filtered: [FileNode] = search.isEmpty
            ? nodes
            : nodes.filter { $0.name.localizedCaseInsensitiveContains(search) }
        var files: [FileSnapshot] = []
        files.reserveCapacity(filtered.count)
        for node in filtered {
            files.append(FileSnapshot(node))
        }
        return files
    }

    /// 按 file id 批量读 tags,仅 fault 指定节点。
    @MainActor
    static func tagsForFileIDs(
        storeCtx: ModelContext,
        ids: [UUID]
    ) -> [UUID: [String]] {
        guard !ids.isEmpty else { return [:] }
        var result: [UUID: [String]] = [:]
        result.reserveCapacity(ids.count)
        for chunk in ids.chunked(into: 200) {
            let chunkIDs = chunk
            let descriptor = FetchDescriptor<FileNode>(
                predicate: #Predicate<FileNode> { node in
                    chunkIDs.contains(node.id)
                }
            )
            let nodes = (try? storeCtx.fetch(descriptor)) ?? []
            for node in nodes {
                let names = node.tags.map(\.name)
                if !names.isEmpty {
                    result[node.id] = names
                }
            }
        }
        return result
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return isEmpty ? [] : [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
