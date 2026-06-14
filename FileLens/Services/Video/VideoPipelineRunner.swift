/**
 * 熏香咒
 *
 * 天辅无私，乾象通微。
 * 无幽无冥，无感不知。
 * 佩带符图，神兵任呼。
 * 我道上皇，位登仙都。
 * 急急如律令。
 *
 * @remarks 来源：太上三洞神咒卷之六 · https://zh.wikisource.org/wiki/太上三洞神呪/6 · kairos-dao-header
 */
import Foundation
import SwiftData

/// 编排 video-tools 全流程：扫描源 → 归集 →（由 FileIndexer 探针）→ 整理 → 改名。
@MainActor
enum VideoPipelineRunner {
    struct ScanCollectResult {
        var found: Int
        var collected: Int
        var failed: Int
        var log: [String]
    }

    // MARK: - Workspace 管道

    static func folderURL(for workspace: Workspace) throws -> URL {
        let (url, _) = try BookmarkStore.resolve(bookmark: workspace.bookmarkData)
        return url
    }

    static func planCollect(inbox: Workspace) async -> [CollectPlanItem] {
        do {
            let source = try folderURL(for: inbox)
            var items: [CollectPlanItem] = []
            VideoScanWalker.walkVideos(in: [source]) { _ in } onHit: { url in
                items.append(CollectPlanItem(url: url, fileName: url.lastPathComponent))
            }
            return items
        } catch {
            return []
        }
    }

    static func executeCollect(
        sources: [URL],
        library: Workspace,
        onProgress: ((String) -> Void)? = nil
    ) async -> ScanCollectResult {
        var log: [String] = []
        do {
            let repo = try folderURL(for: library)
            guard !sources.isEmpty else {
                return ScanCollectResult(found: 0, collected: 0, failed: 0, log: ["无选中文件"])
            }
            onProgress?("归集 \(sources.count) 个文件…")
            let (ok, errs) = await Task.detached(priority: .userInitiated) {
                VideoCollectService.collect(sources: sources, repository: repo) { _ in }
            }.value
            log.append("归集成功 \(ok.count)，失败 \(errs.count)")
            return ScanCollectResult(found: sources.count, collected: ok.count, failed: errs.count, log: log)
        } catch {
            return ScanCollectResult(found: 0, collected: 0, failed: 1, log: [error.localizedDescription])
        }
    }

    static func previewOrganizeCount(library: Workspace) -> Int {
        do {
            let repo = try folderURL(for: library)
            var count = 0
            guard let enumerator = FileManager.default.enumerator(
                at: repo,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return 0 }
            while let url = enumerator.nextObject() as? URL {
                if VideoExtensions.isVideo(path: url) { count += 1 }
            }
            return count
        } catch {
            return 0
        }
    }

    static func organize(library: Workspace, onProgress: ((String) -> Void)? = nil) -> VideoOrganizeReport {
        do {
            let repo = try folderURL(for: library)
            let cfg = library.pipeline
            let method = VideoOrganizeMethod.from(stored: cfg.organizeMethod)
            let keys = cfg.enabledRuleKeys
            var targets: [(URL, [VideoClassification])] = []
            guard let enumerator = FileManager.default.enumerator(
                at: repo,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                return VideoOrganizeReport(summary: "无法遍历仓库")
            }
            while let url = enumerator.nextObject() as? URL {
                guard VideoExtensions.isVideo(path: url) else { continue }
                let meta = VideoProbeService.probe(at: url)
                let cls = VideoClassifier.classify(meta: meta, enabledKeys: keys)
                if !cls.isEmpty { targets.append((url, cls)) }
            }
            onProgress?("整理 \(targets.count) 个文件…")
            return VideoOrganizeService.organize(method: method, repository: repo, targets: targets)
        } catch {
            return VideoOrganizeReport(summary: error.localizedDescription)
        }
    }

    static func probeMoviesInStore(
        storeCtx: ModelContext,
        workspaceFolder: URL,
        onProgress: ((Int, Int) -> Void)? = nil
    ) throws {
        let descriptor = FetchDescriptor<FileNode>(
            predicate: #Predicate<FileNode> { f in
                f.isPresent && f.kind == "movie"
            }
        )
        let nodes = try storeCtx.fetch(descriptor)
        let total = nodes.count
        for (i, node) in nodes.enumerated() {
            let url = workspaceFolder.appendingPathComponent(node.relativePath)
            if FileManager.default.fileExists(atPath: url.path) {
                VideoProbeService.applyProbe(to: node, url: url)
            }
            if i.isMultiple(of: 20) { onProgress?(i + 1, total) }
        }
        try storeCtx.save()
    }
}
