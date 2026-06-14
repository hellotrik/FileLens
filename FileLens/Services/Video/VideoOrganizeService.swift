/**
 * 花开顷刻
 *
 * 令花草顷刻盛衰、万物加速生长或瞬间凋零；用于枯荣操控。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import Foundation

struct VideoOrganizeReport {
    var summary: String
    var failures: [(URL, String)] = []
}

enum VideoOrganizeService {
    static func organize(
        method: VideoOrganizeMethod,
        repository: URL,
        targets: [(URL, [VideoClassification])]
    ) -> VideoOrganizeReport {
        switch method {
        case .tagsAndSmartFolder:
            return applyTagsAndSmartFolders(repository: repository, targets: targets)
        case .smartFolderOnly:
            let r = FinderSmartFolderService.createBuiltinMetadataFolders(scopes: [repository])
            return VideoOrganizeReport(
                summary: "生成 \(r.created) 个智能文件夹，失败 \(r.failures.count) 个"
            )
        }
    }

    private static func applyTagsAndSmartFolders(
        repository: URL,
        targets: [(URL, [VideoClassification])]
    ) -> VideoOrganizeReport {
        var tagged = 0
        var failures: [(URL, String)] = []
        var allTags = Set<String>()
        for (url, cls) in targets {
            do {
                try FinderTagWriter.mergeTags(into: url, classifications: cls)
                tagged += 1
                for c in cls { allTags.insert(c.tagLabel()) }
            } catch {
                failures.append((url, error.localizedDescription))
            }
        }
        let sf = FinderSmartFolderService.createTagFolders(tags: allTags, repo: repository)
        return VideoOrganizeReport(
            summary: "已打标签 \(tagged) 个文件，生成 \(sf.created) 个 Smart Folder，失败 \(failures.count + sf.failures.count) 个",
            failures: failures
        )
    }
}
