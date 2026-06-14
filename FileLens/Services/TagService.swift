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

/// 手动标签与 sidebar 计数。`FileTag.source == "manual"` 的规则在
/// `FileIndexer.applyRulesInline` 里会被保留,不会被规则重算覆盖。
enum TagService {
    /// Inspector / sidebar 里区分于规则色的手动标签色。
    static let manualTagColorHex = "#6366F1"

    struct Statistics {
        var ruleCounts: [String: Int] = [:]
        var manualCounts: [String: Int] = [:]
        var uncategorized: Int = 0
    }

    // MARK: - Manual tag CRUD

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
                case "rule":
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
