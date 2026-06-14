/**
 * 气绝魔仙
 *
 * 金玉如一梦，万年恨寂寥。
 * 五域九天功，尽在一气中。
 *
 * @remarks 来源：蛊真人 · 《蛊真人》全诗词整理（完整版） · kairos-dao-header
 */
import Darwin
import Foundation

/// 探针任务快照 — 在离开 MainActor 前从 `FileNode` 提取，供后台 ffprobe 使用。
struct VideoProbeJob: Sendable {
    let nodeID: UUID
    let url: URL
    let size: Int64
    let dateModified: Date
    let existingProbeKey: String
    let existingMetaJSON: String
}

struct VideoProbeResult: Sendable {
    let nodeID: UUID
    let metaJSON: String
    let probeKey: String
}

struct VideoProbeBatchResult: Sendable {
    let results: [VideoProbeResult]
    let probedCount: Int
    let skippedCount: Int
    let timedOutCount: Int
}

enum VideoProbeService {
    /// 并行 ffprobe 上限；网络盘上串行 1000+ 文件会看起来像「索引卡死」。
    static let defaultProbeConcurrency = 4
    /// 单文件 ffprobe 上限；网络盘或损坏文件否则会一直卡住。
    static let defaultProbeTimeout: TimeInterval = 45

    /// GUI 启动的 macOS app 通常不带 shell 的 PATH（没有 `/opt/homebrew/bin`），
    /// 不能 rely on `/usr/bin/which` 或 `/usr/bin/env ffprobe`。
    private static let ffprobeCandidates = [
        "/opt/homebrew/bin/ffprobe",
        "/usr/local/bin/ffprobe",
        "/opt/local/bin/ffprobe",
        "/usr/bin/ffprobe",
    ]

    static func ffprobeURL() -> URL? {
        let fm = FileManager.default
        for path in ffprobeCandidates where fm.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    static func isAvailable() -> Bool {
        ffprobeURL() != nil
    }

    /// 探测单个视频；失败返回仅含 mtime 的兜底或空 meta。
    static func probe(at url: URL, timeout: TimeInterval = defaultProbeTimeout) -> VideoMeta {
        probeWithStatus(at: url, timeout: timeout).meta
    }

    static func probeWithStatus(
        at url: URL,
        timeout: TimeInterval = defaultProbeTimeout
    ) -> (meta: VideoMeta, timedOut: Bool) {
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            return (filesystemFallback(url: url), false)
        }
        guard let ffprobe = ffprobeURL() else {
            return (filesystemFallback(url: url), false)
        }
        let proc = Process()
        proc.executableURL = ffprobe
        proc.arguments = [
            "-v", "quiet", "-print_format", "json",
            "-show_format", "-show_streams", url.path
        ]
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            guard waitForProcess(proc, timeout: timeout) else {
                return (filesystemFallback(url: url), true)
            }
            guard proc.terminationStatus == 0 else {
                return (filesystemFallback(url: url), false)
            }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            let meta = parseFFProbeJSON(data) ?? filesystemFallback(url: url)
            return (meta, false)
        } catch {
            return (filesystemFallback(url: url), false)
        }
    }

    private static func waitForProcess(_ proc: Process, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while proc.isRunning {
            if Date() >= deadline {
                proc.terminate()
                usleep(500_000)
                if proc.isRunning {
                    kill(proc.processIdentifier, SIGKILL)
                    usleep(100_000)
                }
                return false
            }
            usleep(50_000)
        }
        return true
    }

    static func needsProbe(job: VideoProbeJob) -> Bool {
        let key = VideoMetaCoding.probeKey(size: job.size, modified: job.dateModified)
        if job.existingProbeKey != key { return true }
        if job.existingMetaJSON.isEmpty { return true }
        guard let meta = VideoMetaCoding.decode(job.existingMetaJSON) else { return true }
        // 仅有 mtime 兜底、没有分辨率/时长/编码的缓存视为未完成探针。
        return !metaHasProbeData(meta)
    }

    static func metaHasProbeData(_ meta: VideoMeta) -> Bool {
        meta.width != nil || meta.height != nil || meta.codec != nil || meta.durationSecs != nil
    }

    static func runProbes(
        jobs: [VideoProbeJob],
        maxConcurrent: Int = defaultProbeConcurrency,
        progress: FinderTagProgressHandler? = nil
    ) -> VideoProbeBatchResult {
        let pending = jobs.filter { needsProbe(job: $0) }
        let skippedCount = jobs.count - pending.count
        guard !pending.isEmpty else {
            progress?(0, 0, nil)
            return VideoProbeBatchResult(results: [], probedCount: 0, skippedCount: skippedCount, timedOutCount: 0)
        }

        var results: [VideoProbeResult] = []
        results.reserveCapacity(pending.count)
        var timedOutCount = 0
        let lock = NSLock()
        var done = 0
        let total = pending.count
        let workers = max(1, min(maxConcurrent, total))
        let group = DispatchGroup()
        let semaphore = DispatchSemaphore(value: workers)

        for job in pending {
            group.enter()
            DispatchQueue.global(qos: .utility).async {
                defer {
                    semaphore.signal()
                    group.leave()
                }
                semaphore.wait()
                let key = VideoMetaCoding.probeKey(size: job.size, modified: job.dateModified)
                let status = probeWithStatus(at: job.url)
                let result = VideoProbeResult(
                    nodeID: job.nodeID,
                    metaJSON: VideoMetaCoding.encode(status.meta),
                    probeKey: key
                )
                lock.lock()
                results.append(result)
                if status.timedOut { timedOutCount += 1 }
                done += 1
                let snapshot = done
                let detail = job.url.lastPathComponent
                lock.unlock()
                progress?(snapshot, total, detail)
            }
        }
        group.wait()
        return VideoProbeBatchResult(
            results: results,
            probedCount: pending.count,
            skippedCount: skippedCount,
            timedOutCount: timedOutCount
        )
    }

    /// 仅写回探针结果；调用方须在持有该 `FileNode` 的 `ModelContext` 所在 actor 上执行。
    static func applyProbeResult(to node: FileNode, metaJSON: String, probeKey: String) {
        node.videoMetaJSON = metaJSON
        node.videoProbeKey = probeKey
    }

    /// 同步探针（须在 MainActor / store context 上调用，不可从 detached 任务跨域访问 node）。
    static func applyProbe(to node: FileNode, url: URL) {
        let key = VideoMetaCoding.probeKey(size: node.size, modified: node.dateModified)
        if node.videoProbeKey == key, !node.videoMetaJSON.isEmpty { return }
        let meta = probe(at: url)
        applyProbeResult(to: node, metaJSON: VideoMetaCoding.encode(meta), probeKey: key)
    }

    static func job(from node: FileNode, url: URL) -> VideoProbeJob {
        VideoProbeJob(
            nodeID: node.id,
            url: url,
            size: node.size,
            dateModified: node.dateModified,
            existingProbeKey: node.videoProbeKey,
            existingMetaJSON: node.videoMetaJSON
        )
    }

    static func runProbe(job: VideoProbeJob) -> VideoProbeResult? {
        runProbes(jobs: [job]).results.first
    }

    // MARK: - JSON parse

    private struct FFProbeRoot: Decodable {
        var streams: [FFStream]?
        var format: FFFormat?
    }

    private struct FFStream: Decodable {
        var codec_type: String?
        var codec_name: String?
        var width: Int?
        var height: Int?
    }

    private struct FFFormat: Decodable {
        var duration: String?
        var bit_rate: String?
        var tags: [String: String]?
    }

    private static func parseFFProbeJSON(_ data: Data) -> VideoMeta? {
        guard let root = try? JSONDecoder().decode(FFProbeRoot.self, from: data) else { return nil }
        let vStream = root.streams?.first { $0.codec_type == "video" }
        var meta = VideoMeta()
        meta.width = vStream?.width
        meta.height = vStream?.height
        meta.codec = vStream?.codec_name
        if let d = root.format?.duration, let secs = Double(d) {
            meta.durationSecs = secs
        }
        if let b = root.format?.bit_rate, let rate = UInt64(b) {
            meta.bitrate = rate
        }
        if let raw = root.format?.tags?["creation_time"] {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let dt = f.date(from: raw) {
                meta.createdAt = dt
            } else {
                f.formatOptions = [.withInternetDateTime]
                meta.createdAt = f.date(from: raw)
            }
        }
        return meta
    }

    private static func filesystemFallback(url: URL) -> VideoMeta {
        var meta = VideoMeta()
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let mtime = attrs[.modificationDate] as? Date {
            meta.createdAt = mtime
        }
        return meta
    }
}
