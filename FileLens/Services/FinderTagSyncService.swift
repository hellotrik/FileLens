/**
 * 移山
 *
 * 搬运山岳、改易地脉；用于大规模地形与物体位移（设定）。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import Foundation
import SwiftData

struct FinderTagSyncReport {
    var affected = 0
    var skippedNoTags = 0
    var failures: [(String, String)] = []
}

/// 把 FileLens 侧栏规则分类同步为 macOS Finder 彩色标签（xattr）。
enum FinderTagSyncService {
    struct Job: Sendable {
        struct Entry: Sendable {
            let label: String
            let colorRaw: UInt8
        }

        let url: URL
        let entries: [Entry]
    }

    @MainActor
    static func buildJobs(nodes: [FileNode], rules: [Rule]) -> [Job] {
        let ruleByID = Dictionary(uniqueKeysWithValues: rules.map { ($0.id, $0) })
        var jobs: [Job] = []
        for node in nodes where node.isPresent {
            guard let url = FileActions.url(for: node),
                  FileManager.default.fileExists(atPath: url.path) else { continue }
            let ruleTags = node.tags.filter { $0.source == "rule" || $0.source == "pinned" }
            guard !ruleTags.isEmpty else { continue }
            var entries: [Job.Entry] = []
            var seen = Set<String>()
            for tag in ruleTags {
                let label: String
                let color: FinderTagWriter.TagColor
                if let rid = tag.ruleID, let rule = ruleByID[rid] {
                    label = TagDisplay.localizedName(rule.name)
                    color = FinderTagWriter.colorFromRuleHex(rule.color)
                } else {
                    label = TagDisplay.localizedName(tag.name)
                    color = .gray
                }
                guard seen.insert(label).inserted else { continue }
                entries.append(.init(label: label, colorRaw: color.rawValue))
            }
            guard !entries.isEmpty else { continue }
            jobs.append(.init(url: url, entries: entries))
        }
        return jobs
    }

    static func run(jobs: [Job]) -> FinderTagSyncReport {
        var report = FinderTagSyncReport()
        for job in jobs {
            let entries = job.entries.map {
                FinderTagWriter.TagEntry(
                    label: $0.label,
                    color: FinderTagWriter.TagColor(rawValue: $0.colorRaw) ?? .gray
                )
            }
            do {
                try FinderTagWriter.mergeTags(into: job.url, entries: entries)
                report.affected += 1
            } catch {
                report.failures.append((job.url.lastPathComponent, error.localizedDescription))
            }
        }
        return report
    }

    @MainActor
    static func buildClearJobs(nodes: [FileNode]) -> [URL] {
        nodes.compactMap { node in
            guard node.isPresent,
                  let url = FileActions.url(for: node),
                  FileManager.default.fileExists(atPath: url.path) else { return nil }
            return url
        }
    }

    static func runClear(urls: [URL]) -> FinderTagSyncReport {
        var report = FinderTagSyncReport()
        for url in urls {
            guard FinderTagWriter.hasTags(at: url) else {
                report.skippedNoTags += 1
                continue
            }
            do {
                try FinderTagWriter.clearTags(at: url)
                report.affected += 1
            } catch {
                report.failures.append((url.lastPathComponent, error.localizedDescription))
            }
        }
        return report
    }
}
