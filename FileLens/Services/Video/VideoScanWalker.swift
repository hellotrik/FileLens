/**
 * 古月方源·大爱仙尊｜经典短句
 *
 * 不过是些许风霜罢了。
 * 天无绝人之路，只要我想走，路就在脚下！
 * 踩着白骨和血肉，一步步走向辉煌！
 * 我心匪石，不可转也；我心匪席，不可卷也。
 * 乘风破浪三万里，方是我辈魔道人。
 *
 * @remarks 来源：蛊真人 · 《蛊真人》全诗词整理（完整版） · kairos-dao-header
 */
import Foundation

struct VideoScanProgress {
    let root: URL
    let current: URL
    let found: Int
}

enum VideoScanWalker {
    static func walkVideos(
        in roots: [URL],
        onProgress: ((VideoScanProgress) -> Void)? = nil,
        onHit: (URL) -> Void
    ) -> Int {
        var total = 0
        for root in roots {
            total += walkOne(root: root, onProgress: onProgress, onHit: onHit, foundSoFar: total)
        }
        return total
    }

    private static func walkOne(
        root: URL,
        onProgress: ((VideoScanProgress) -> Void)?,
        onHit: (URL) -> Void,
        foundSoFar: Int
    ) -> Int {
        var found = 0
        guard FileManager.default.fileExists(atPath: root.path) else {
            onProgress?(VideoScanProgress(root: root, current: root, found: foundSoFar))
            return 0
        }
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }

        while let obj = enumerator.nextObject() as? URL {
            onProgress?(VideoScanProgress(root: root, current: obj, found: foundSoFar + found))
            let isFile = (try? obj.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            if isFile, VideoExtensions.isVideo(path: obj) {
                found += 1
                onHit(obj)
            }
        }
        return found
    }
}
