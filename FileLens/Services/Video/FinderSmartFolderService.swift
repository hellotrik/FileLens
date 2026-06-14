/**
 * 钉头七箭
 *
 * 钉头七箭类诅咒术，可异地取命；用于远距咒杀与因果打击（设定）。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import Foundation

struct SmartFolderReport {
    var created = 0
    var failures: [(String, String)] = []
}

enum FinderSmartFolderService {
    static func savedSearchesDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Saved Searches", isDirectory: true)
    }

    static func create(name: String, rawQuery: String, scopes: [URL]) throws -> URL {
        let dir = savedSearchesDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let safe = sanitizeName(name)
        let target = dir.appendingPathComponent("\(safe).savedSearch")
        let scopeStrings = scopes.map { $0.path }
        let plist: [String: Any] = [
            "RawQuery": rawQuery,
            "RawQueryDict": [
                "RawQuery": rawQuery,
                "SearchScopes": scopeStrings,
                "FinderFilesOnly": true
            ],
            "SearchCriteria": [
                "FXScopeArrayOfPaths": scopeStrings,
                "FXCriteriaSlices": [] as [Any]
            ],
            "ShowAttributes": [] as [Any],
            "CompatibleVersion": 1
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: target)
        return target
    }

    static func createBuiltinMetadataFolders(scopes: [URL]) -> SmartFolderReport {
        var report = SmartFolderReport()
        for (name, query) in builtinQueries() {
            do {
                _ = try create(name: name, rawQuery: query, scopes: scopes)
                report.created += 1
            } catch {
                report.failures.append((name, error.localizedDescription))
            }
        }
        return report
    }

    static func createTagFolders(tags: Set<String>, repo: URL) -> SmartFolderReport {
        var report = SmartFolderReport()
        let scopes = [repo]
        for tag in tags {
            let escaped = tag.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let query = "kMDItemUserTags == \"\(escaped)\""
            do {
                _ = try create(name: tag, rawQuery: query, scopes: scopes)
                report.created += 1
            } catch {
                report.failures.append((tag, error.localizedDescription))
            }
        }
        return report
    }

    private static func sanitizeName(_ name: String) -> String {
        String(name.map { c in
            switch c {
            case "/", "\\", ":", "\n", "\r", "\t": return "_"
            default: return c
            }
        })
    }

    private static func builtinQueries() -> [(String, String)] {
        [
            ("视频·4K", "kMDItemPixelHeight >= 2160 && kMDItemContentTypeTree == \"public.movie\""),
            ("视频·1080p", "kMDItemPixelHeight >= 1080 && kMDItemPixelHeight < 2160 && kMDItemContentTypeTree == \"public.movie\""),
            ("视频·720p", "kMDItemPixelHeight >= 720 && kMDItemPixelHeight < 1080 && kMDItemContentTypeTree == \"public.movie\""),
            ("视频·短片(<10min)", "kMDItemDurationSeconds < 600 && kMDItemContentTypeTree == \"public.movie\""),
            ("视频·中片(10-60min)", "kMDItemDurationSeconds >= 600 && kMDItemDurationSeconds <= 3600 && kMDItemContentTypeTree == \"public.movie\""),
            ("视频·电影(>60min)", "kMDItemDurationSeconds > 3600 && kMDItemContentTypeTree == \"public.movie\""),
            ("视频·HEVC", "kMDItemCodecs == \"hvc1\"c || kMDItemCodecs == \"hev1\"c")
        ]
    }
}
