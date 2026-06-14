/**
 * 隔山打牛
 *
 * 隔山隔物、隔障隔阵；用于绕过正面阻挡，从侧后或间接路径达成目的。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import Foundation
import SwiftData

/// 大列表分批上屏 + tags lazy 加载。首屏先出 file 行,tags 列随后分批填充。
@MainActor
@Observable
final class FileListLoader {
    static let tagsBatchSize = 300

    private(set) var files: [FileSnapshot] = []
    private(set) var tagsByFileID: [UUID: [String]] = [:]
    private(set) var isLoading = false

    func reset() {
        files = []
        tagsByFileID = [:]
        isLoading = false
    }

    func load(
        workspace: Workspace,
        selection: SidebarSelection?,
        search: String,
        storeCtx: ModelContext,
        memo: FilesMemo
    ) async {
        if let cached = memo.get(workspace: workspace, selection: selection, search: search) {
            files = cached.files
            tagsByFileID = cached.tagsByFileID
            isLoading = false
            return
        }

        files = []
        tagsByFileID = [:]
        isLoading = true
        defer { isLoading = false }

        let ruleID = FileListQuery.ruleID(for: selection, rules: workspace.rules)

        if !search.isEmpty {
            let nodes = FileListQuery.fetchAll(
                storeCtx: storeCtx,
                selection: selection,
                ruleID: ruleID
            )
            let built = FileListQuery.snapshots(from: nodes, search: search)
            files = built
            await loadTags(storeCtx: storeCtx, fileIDs: built.map(\.id))
            memo.set(
                workspace: workspace,
                selection: selection,
                search: search,
                entry: FilesMemo.CacheEntry(files: built, tagsByFileID: tagsByFileID)
            )
            return
        }

        let descriptor = FileListQuery.makeDescriptor(selection: selection, ruleID: ruleID)
        var offset = 0
        var allSnapshots: [FileSnapshot] = []
        var tagsLoadedThrough = 0

        while !Task.isCancelled {
            let nodes = FileListQuery.fetchPage(
                storeCtx: storeCtx,
                descriptor: descriptor,
                offset: offset,
                limit: FileListQuery.defaultPageSize
            )
            if nodes.isEmpty { break }

            let batch = FileListQuery.snapshots(from: nodes, search: "")
            allSnapshots.append(contentsOf: batch)
            files = allSnapshots

            await loadTags(
                storeCtx: storeCtx,
                fileIDs: allSnapshots.map(\.id),
                from: tagsLoadedThrough
            )
            tagsLoadedThrough = allSnapshots.count

            offset += nodes.count
            if nodes.count < FileListQuery.defaultPageSize { break }
            await Task.yield()
        }

        guard !Task.isCancelled else { return }

        await loadTags(
            storeCtx: storeCtx,
            fileIDs: allSnapshots.map(\.id),
            from: tagsLoadedThrough
        )

        memo.set(
            workspace: workspace,
            selection: selection,
            search: search,
            entry: FilesMemo.CacheEntry(files: allSnapshots, tagsByFileID: tagsByFileID)
        )
    }

    private func loadTags(storeCtx: ModelContext, fileIDs: [UUID], from start: Int = 0) async {
        guard start < fileIDs.count else { return }
        var merged = tagsByFileID
        var index = start
        while index < fileIDs.count {
            if Task.isCancelled { return }
            let end = min(index + Self.tagsBatchSize, fileIDs.count)
            let chunk = Array(fileIDs[index..<end])
            let batch = FileListQuery.tagsForFileIDs(storeCtx: storeCtx, ids: chunk)
            merged.merge(batch) { _, new in new }
            tagsByFileID = merged
            index = end
            await Task.yield()
        }
    }
}

/// `FileListLoader` 的 memo 容器。class 引用类型,改内部字段通过 loader 触发 UI。
///
/// 按 workspace 分桶,每个 workspace 内是 multi-key cache(workspace selection
/// + 各 tag selection)。版本戳是该 workspace 的 fileCount,scan 完成写回时
/// 仅清空那一个 workspace 的桶,跨 workspace 切回不重 fetch。
final class FilesMemo {
    struct CacheEntry {
        let files: [FileSnapshot]
        let tagsByFileID: [UUID: [String]]
    }

    private struct Bucket {
        var versionKey: String
        var entries: [String: CacheEntry]
    }
    private var byWorkspace: [UUID: Bucket] = [:]

    func get(workspace ws: Workspace, selection: SidebarSelection?, search: String) -> CacheEntry? {
        let v = Self.versionKey(ws: ws)
        guard let bucket = byWorkspace[ws.id], bucket.versionKey == v else {
            byWorkspace[ws.id] = Bucket(versionKey: v, entries: [:])
            return nil
        }
        let k = Self.selectionKey(selection: selection, search: search)
        return bucket.entries[k]
    }

    func set(workspace ws: Workspace, selection: SidebarSelection?, search: String, entry: CacheEntry) {
        let v = Self.versionKey(ws: ws)
        var bucket = byWorkspace[ws.id] ?? Bucket(versionKey: v, entries: [:])
        if bucket.versionKey != v {
            bucket = Bucket(versionKey: v, entries: [:])
        }
        let k = Self.selectionKey(selection: selection, search: search)
        bucket.entries[k] = entry
        byWorkspace[ws.id] = bucket
    }

    private static func versionKey(ws: Workspace) -> String {
        "\(ws.fileCount)|\(ws.scanGeneration)"
    }

    private static func selectionKey(selection: SidebarSelection?, search: String) -> String {
        let sel: String
        switch selection {
        case .none:                       sel = "_"
        case .workspace(let id):          sel = "ws:\(id)"
        case .tag(_, let name):           sel = "t:\(name)"
        case .manualTag(_, let name):     sel = "m:\(name)"
        case .uncategorized(let id):      sel = "u:\(id)"
        }
        return "\(sel)|\(search)"
    }

    func invalidate() {
        byWorkspace.removeAll(keepingCapacity: false)
    }
}
