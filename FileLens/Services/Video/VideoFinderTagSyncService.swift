/**
 * 花开顷刻
 *
 * 令花草顷刻盛衰、万物加速生长或瞬间凋零；用于枯荣操控。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import Foundation
import SwiftData

typealias FinderTagProgressHandler = @Sendable (Int, Int, String?) -> Void

/// 把 ffprobe 分类（分辨率 / 时长 / 编码 / 年份）写入 Finder 彩色标签。
enum VideoFinderTagSyncService {
    struct ApplyInput: Sendable {
        let url: URL
        let cachedMetaJSON: String
    }

    struct ApplyJob: Sendable {
        let url: URL
        let classifications: [VideoClassification]
    }

    struct BuildResult: Sendable {
        let jobs: [ApplyJob]
        let probeTimeouts: Int
    }

    static func isVideoNode(_ node: FileNode) -> Bool {
        node.kind == "movie" || VideoExtensions.isVideoExtension(node.ext)
    }

    @MainActor
    static func makeInputs(from nodes: [FileNode]) -> [ApplyInput] {
        nodes.compactMap { node in
            guard node.isPresent, isVideoNode(node),
                  let url = FileActions.url(for: node),
                  FileManager.default.fileExists(atPath: url.path) else { return nil }
            return ApplyInput(url: url, cachedMetaJSON: node.videoMetaJSON)
        }
    }

    static func buildJobs(
        inputs: [ApplyInput],
        enabledKeys: [String],
        progress: FinderTagProgressHandler? = nil
    ) -> BuildResult {
        let total = inputs.count
        var jobs: [ApplyJob] = []
        jobs.reserveCapacity(total)
        var probeTimeouts = 0
        for (index, input) in inputs.enumerated() {
            let detail = input.url.lastPathComponent
            let meta: VideoMeta
            if !input.cachedMetaJSON.isEmpty, let cached = VideoMetaCoding.decode(input.cachedMetaJSON) {
                meta = cached
            } else {
                let result = VideoProbeService.probeWithStatus(at: input.url)
                meta = result.meta
                if result.timedOut { probeTimeouts += 1 }
            }
            let cls = VideoClassifier.classify(meta: meta, enabledKeys: enabledKeys)
            if !cls.isEmpty {
                jobs.append(ApplyJob(url: input.url, classifications: cls))
            }
            progress?(index + 1, total, detail)
        }
        if total == 0 { progress?(0, 0, nil) }
        return BuildResult(jobs: jobs, probeTimeouts: probeTimeouts)
    }

    static func runApply(
        jobs: [ApplyJob],
        progress: FinderTagProgressHandler? = nil
    ) -> FinderTagSyncReport {
        var report = FinderTagSyncReport()
        let total = jobs.count
        for (index, job) in jobs.enumerated() {
            do {
                try FinderTagWriter.mergeTags(into: job.url, classifications: job.classifications)
                report.affected += 1
            } catch {
                report.failures.append((job.url.lastPathComponent, error.localizedDescription))
            }
            progress?(index + 1, total, job.url.lastPathComponent)
        }
        if total == 0 { progress?(0, 0, nil) }
        return report
    }
}
