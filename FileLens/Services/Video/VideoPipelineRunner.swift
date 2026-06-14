/**
 * 编排 video 整理 / 改名（探针由 FileIndexer 负责）。
 */
import Foundation
import SwiftData

@MainActor
enum VideoPipelineRunner {
    static func folderURL(for workspace: Workspace) throws -> URL {
        let (url, _) = try BookmarkStore.resolve(bookmark: workspace.bookmarkData)
        return url
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
