/**
 * 墨瑶（其一）
 *
 * 八十八角真阳楼，招灾仙蛊炼不休。
 * 为助情郎登九转，愿以残躯化劫流。
 *
 * @remarks 来源：蛊真人 · 《蛊真人》全诗词整理（完整版） · kairos-dao-header
 */
import Foundation
import SwiftData

/// 规则标签与 sidebar 计数。`FileTag.source == "pinned"` 为用户批量指定的
/// 规则标签,在 `FileIndexer.applyRulesInline` 里保留;`source == "manual"`
/// 为旧版手动标签,同样保留。
enum TagService {
    /// 旧版手动标签色（仅兼容已有数据）。
    static let manualTagColorHex = "#6366F1"

    struct Statistics {
        var ruleCounts: [String: Int] = [:]
        var manualCounts: [String: Int] = [:]
        var uncategorized: Int = 0
    }

    // MARK: - Rule tag (pinned)

    /// 批量给文件打上规则标签；不跑条件，标记为 `pinned`，重算规则时保留。
    @discardableResult
    static func applyRuleTags(_ rules: [Rule], to files: [FileNode], context: ModelContext) -> Int {
        guard !rules.isEmpty, !files.isEmpty else { return 0 }
        var added = 0
        for file in files {
            for rule in rules {
                if file.tags.contains(where: {
                    $0.ruleID == rule.id && ($0.source == "pinned" || $0.source == "rule")
                }) { continue }
                let tag = FileTag(name: rule.name, source: "pinned", ruleID: rule.id)
                tag.file = file
                context.insert(tag)
                file.tags.append(tag)
                added += 1
            }
        }
        return added
    }

    /// 移除所选文件上的自动规则标签与 pinned 标签；保留 legacy manual。
    static func clearRuleTags(from files: [FileNode], context: ModelContext) {
        guard !files.isEmpty else { return }
        for file in files {
            let toRemove = file.tags.filter { $0.source == "rule" || $0.source == "pinned" }
            for tag in toRemove {
                context.delete(tag)
                file.tags.removeAll { $0.id == tag.id }
            }
        }
    }

    static func removePinnedTags(from files: [FileNode], names: Set<String>, context: ModelContext) {
        guard !files.isEmpty, !names.isEmpty else { return }
        for file in files {
            let toRemove = file.tags.filter { $0.source == "pinned" && names.contains($0.name) }
            for tag in toRemove {
                context.delete(tag)
                file.tags.removeAll { $0.id == tag.id }
            }
        }
    }

    static func fileHasRuleTag(_ file: FileNode) -> Bool {
        file.tags.contains { $0.source == "rule" || $0.source == "pinned" }
    }

    // MARK: - Legacy manual tag CRUD

    static func normalizeManualTagName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 64 else { return nil }
        return trimmed
    }

    /// 给一批文件添加同名手动标签;已存在则跳过。
    @discardableResult
    static func addManualTag(name rawName: String, to files: [FileNode], context: ModelContext) -> String? {
        guard let name = normalizeManualTagName(rawName), !files.isEmpty else { return nil }
        for file in files {
            if file.tags.contains(where: { $0.source == "manual" && $0.name == name }) { continue }
            let tag = FileTag(name: name, source: "manual", ruleID: nil)
            tag.file = file
            context.insert(tag)
            file.tags.append(tag)
        }
        return name
    }

    /// 移除手动标签。`names == nil` 表示清掉所选文件上的全部手动标签。
    static func removeManualTags(from files: [FileNode], names: Set<String>? = nil, context: ModelContext) {
        guard !files.isEmpty else { return }
        for file in files {
            let toRemove = file.tags.filter { tag in
                guard tag.source == "manual" else { return false }
                if let names { return names.contains(tag.name) }
                return true
            }
            for tag in toRemove {
                context.delete(tag)
                file.tags.removeAll { $0.id == tag.id }
            }
        }
    }

    /// 清掉所选文件上的全部标签(手动 + 规则)。
    static func removeAllTags(from files: [FileNode], context: ModelContext) {
        guard !files.isEmpty else { return }
        for file in files {
            for tag in file.tags {
                context.delete(tag)
            }
            file.tags.removeAll()
            file.rulesEvaluatedAt = nil
        }
    }

    // MARK: - Workspace counts (sidebar badges)

    static func computeStatistics(from nodes: [FileNode]) -> Statistics {
        var stats = Statistics()
        for node in nodes where node.isPresent {
            var hasRule = false
            for tag in node.tags {
                switch tag.source {
                case "rule", "pinned":
                    if let rid = tag.ruleID {
                        hasRule = true
                        stats.ruleCounts[rid.uuidString, default: 0] += 1
                    }
                case "manual":
                    stats.manualCounts[tag.name, default: 0] += 1
                default:
                    break
                }
            }
            if !hasRule { stats.uncategorized += 1 }
        }
        return stats
    }

    static func applyStatistics(_ stats: Statistics, presentCount: Int, to workspace: Workspace) {
        workspace.fileCount = presentCount
        workspace.uncategorizedCount = stats.uncategorized
        if let data = try? JSONEncoder().encode(stats.ruleCounts),
           let json = String(data: data, encoding: .utf8) {
            workspace.ruleCountsJSON = json
        }
        if let data = try? JSONEncoder().encode(stats.manualCounts),
           let json = String(data: data, encoding: .utf8) {
            workspace.manualTagCountsJSON = json
        } else {
            workspace.manualTagCountsJSON = ""
        }
    }

    static func refreshWorkspaceCounts(
        workspace: Workspace,
        storeCtx: ModelContext,
        catalogCtx: ModelContext
    ) throws {
        let nodes = try storeCtx.fetch(FetchDescriptor<FileNode>(
            predicate: #Predicate<FileNode> { $0.isPresent }
        ))
        let stats = computeStatistics(from: nodes)
        applyStatistics(stats, presentCount: nodes.count, to: workspace)
        workspace.scanGeneration &+= 1
        try catalogCtx.save()
    }

    static func decodeManualCounts(_ json: String) -> [String: Int] {
        guard !json.isEmpty,
              let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        return dict
    }
}
