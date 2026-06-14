/**
 * 花开顷刻
 *
 * 令花草顷刻盛衰、万物加速生长或瞬间凋零；用于枯荣操控。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import Foundation
import SwiftData

/// 把 ffprobe 分类（分辨率 / 时长 / 编码 / 年份）写入 Finder 彩色标签。
enum VideoFinderTagSyncService {
    static func isVideoNode(_ node: FileNode) -> Bool {
        node.kind == "movie" || VideoExtensions.isVideoExtension(node.ext)
    }

    @MainActor
    static func buildApplyJobs(
        nodes: [FileNode],
        enabledKeys: [String]
    ) -> [(url: URL, classifications: [VideoClassification])] {
        var jobs: [(URL, [VideoClassification])] = []
        for node in nodes where node.isPresent && isVideoNode(node) {
            guard let url = FileActions.url(for: node),
                  FileManager.default.fileExists(atPath: url.path) else { continue }
            let meta: VideoMeta
            if !node.videoMetaJSON.isEmpty, let cached = VideoMetaCoding.decode(node.videoMetaJSON) {
                meta = cached
            } else {
                meta = VideoProbeService.probe(at: url)
            }
            let cls = VideoClassifier.classify(meta: meta, enabledKeys: enabledKeys)
            guard !cls.isEmpty else { continue }
            jobs.append((url, cls))
        }
        return jobs
    }

    static func runApply(jobs: [(url: URL, classifications: [VideoClassification])]) -> FinderTagSyncReport {
        var report = FinderTagSyncReport()
        for job in jobs {
            do {
                try FinderTagWriter.mergeTags(into: job.url, classifications: job.classifications)
                report.affected += 1
            } catch {
                report.failures.append((job.url.lastPathComponent, error.localizedDescription))
            }
        }
        return report
    }
}
