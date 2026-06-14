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

/// video-tools 四条分类规则对应的 FileLens 内置规则（需 ffprobe 元数据）。
enum BuiltInVideoRules {
    static func all() -> [Rule] {
        [
            rule("4K", "#3B82F6", 200, [c("videoResolution", "is", "4K")]),
            rule("1080p", "#2563EB", 210, [c("videoResolution", "is", "1080p")]),
            rule("720p", "#1D4ED8", 220, [c("videoResolution", "is", "720p")]),
            rule("Short", "#10B981", 230, [c("videoDuration", "is",
                NSLocalizedString("video.cat.short", value: "短片", comment: ""))]),
            rule("Feature", "#059669", 240, [c("videoDuration", "is",
                NSLocalizedString("video.cat.movie", value: "电影", comment: ""))]),
            rule("HEVC", "#8B5CF6", 250, [c("videoCodec", "is", "HEVC")]),
            rule("H264", "#7C3AED", 260, [c("videoCodec", "is", "H264")]),
        ]
    }

    /// 创建「视频库」workspace 时附加的规则（含通用 Videos + 视频维度）。
    static func libraryPack() -> [Rule] {
        var rules: [Rule] = []
        if let videos = BuiltInRules.all().first(where: { r in
            r.conditions.count == 1
                && r.conditions[0].field == "kind"
                && r.conditions[0].op == "is"
                && r.conditions[0].value == "movie"
        }) {
            rules.append(videos)
        }
        rules.append(contentsOf: all())
        return rules
    }

    private static func rule(_ key: String, _ color: String, _ priority: Int, _ conditions: [Condition]) -> Rule {
        let localized = NSLocalizedString(key, value: key, comment: "Video built-in rule")
        let r = Rule(name: localized, color: color, enabled: true, priority: priority,
                     combinator: "any", isBuiltIn: true)
        for cnd in conditions { r.conditions.append(cnd) }
        return r
    }

    private static func c(_ field: String, _ op: String, _ value: String) -> Condition {
        Condition(field: field, op: op, value: value)
    }
}
