/**
 * 移山
 *
 * 搬运山岳、改易地脉；用于大规模地形与物体位移（设定）。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import Foundation

/// 按 workspace 角色拆分侧栏规则：文件夹 vs 视频库不混在同一棵树里。
enum RuleRoleFilter {
    static func rules(for role: WorkspaceRole, from rules: [Rule]) -> [Rule] {
        switch role {
        case .library:
            return rules.filter(isLibraryRule)
        case .watch, .inbox:
            return rules.filter(isFolderRule)
        }
    }

    /// 视频库：Videos + ffprobe 四维（4K / HEVC / …）。
    static func isLibraryRule(_ rule: Rule) -> Bool {
        if isVideoMetadataRule(rule) { return true }
        return rule.conditions.count == 1
            && rule.conditions[0].field == "kind"
            && rule.conditions[0].op == "is"
            && rule.conditions[0].value == "movie"
    }

    /// 文件夹：通用分类（图片 / PDF / …），不含 video* 条件规则。
    static func isFolderRule(_ rule: Rule) -> Bool {
        !isVideoMetadataRule(rule)
    }

    static func isVideoMetadataRule(_ rule: Rule) -> Bool {
        rule.conditions.contains { $0.field.hasPrefix("video") }
    }
}
