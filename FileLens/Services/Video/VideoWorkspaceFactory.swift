/**
 * 移山
 *
 * 搬运山岳、改易地脉；用于大规模地形与物体位移（设定）。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import Foundation
import SwiftData

/// 创建 / 查找视频库与摄入源 workspace。
enum VideoWorkspaceFactory {
    static func normalizedPath(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    static func findWorkspace(matchingPath path: String, in workspaces: [Workspace]) -> Workspace? {
        let target = normalizedPath(path)
        return workspaces.first { normalizedPath($0.folderPath) == target }
    }

    @discardableResult
    static func ensureLibrary(
        at url: URL,
        pipeline: WorkspacePipelineConfig,
        context: ModelContext,
        existing: [Workspace],
        sortOrder: Int
    ) throws -> Workspace {
        if let ws = findWorkspace(matchingPath: url.path, in: existing) {
            ws.role = .library
            ws.pipeline = pipeline
            ws.recursive = true
            attachVideoRulesIfNeeded(to: ws, context: context)
            return ws
        }
        let bookmark = try BookmarkStore.makeBookmark(for: url)
        let ws = Workspace(
            name: url.lastPathComponent,
            folderPath: url.path,
            bookmarkData: bookmark,
            sortOrder: sortOrder,
            recursive: true,
            displayName: NSLocalizedString("Video Library", value: "Video Library", comment: ""),
            roleRaw: WorkspaceRole.library.rawValue
        )
        ws.pipeline = pipeline
        context.insert(ws)
        for rule in BuiltInVideoRules.libraryPack() {
            rule.workspace = ws
            context.insert(rule)
            for c in rule.conditions { context.insert(c) }
        }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return ws
    }

    @discardableResult
    static func ensureInbox(
        at url: URL,
        linkedLibrary: Workspace?,
        context: ModelContext,
        existing: [Workspace],
        sortOrder: Int
    ) throws -> Workspace {
        if let ws = findWorkspace(matchingPath: url.path, in: existing) {
            ws.role = .inbox
            ws.recursive = true
            if let linkedLibrary { ws.linkedLibraryUUID = linkedLibrary.id }
            return ws
        }
        let bookmark = try BookmarkStore.makeBookmark(for: url)
        let ws = Workspace(
            name: url.lastPathComponent,
            folderPath: url.path,
            bookmarkData: bookmark,
            sortOrder: sortOrder,
            recursive: true,
            displayName: url.lastPathComponent,
            roleRaw: WorkspaceRole.inbox.rawValue
        )
        ws.linkedLibraryUUID = linkedLibrary?.id
        context.insert(ws)
        return ws
    }

    static func attachVideoRulesIfNeeded(to ws: Workspace, context: ModelContext) {
        let hasVideoRules = ws.rules.contains {
            $0.conditions.contains { $0.field == "videoResolution" }
        }
        guard !hasVideoRules else { return }
        for rule in BuiltInVideoRules.libraryPack() {
            guard !ws.rules.contains(where: { $0.name == rule.name && $0.isBuiltIn }) else { continue }
            let r = Rule(name: rule.name, color: rule.color, enabled: rule.enabled,
                           priority: rule.priority, combinator: rule.combinator, isBuiltIn: true)
            for c in rule.conditions {
                r.conditions.append(Condition(field: c.field, op: c.op, value: c.value))
            }
            r.workspace = ws
            context.insert(r)
            for c in r.conditions { context.insert(c) }
        }
    }

    static func pipelineFromLegacy(_ parsed: VideoConfigImporter.ParsedConfig) -> WorkspacePipelineConfig {
        WorkspacePipelineConfig(
            organizeMethod: parsed.organizeMethod ?? VideoSettings.defaultOrganizeMethod,
            enabledRuleKeys: parsed.enabledRuleKeys.isEmpty ? VideoSettings.defaultRuleKeys : parsed.enabledRuleKeys,
            renameOptions: parsed.rename ?? .default,
            probeVideos: true
        )
    }
}
