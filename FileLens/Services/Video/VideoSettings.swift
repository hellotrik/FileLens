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

/// 视频模块默认值（路径与管道配置已迁入 Workspace）。
enum VideoSettings {
    static let defaultSources: [String] = ["~/Movies/Inbox"]
    static let defaultRepository: String = "~/Movies/Library"
    static let defaultOrganizeMethod = "tags_and_smartfolder"
    static let defaultRuleKeys = ["resolution", "duration", "codec", "year"]

    static func expandPath(_ raw: String) -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("~/") {
            return URL(fileURLWithPath: NSHomeDirectory() + String(trimmed.dropFirst(1)))
        }
        return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
    }
}

struct VideoRenameOptions: Codable, Equatable {
    var stripSquare: Bool = true
    var stripRound: Bool = true
    var stripCJKBrace: Bool = true
    var stripCurly: Bool = true
    var collapseSeparators: Bool = true
    var underscoreBetweenWords: Bool = true
    var underscoreCopySuffix: Bool = true
    var lowercaseExt: Bool = true

    static let `default` = VideoRenameOptions()
}

enum VideoOrganizeMethod: String, CaseIterable, Identifiable {
    case tagsAndSmartFolder = "tags_and_smartfolder"
    case smartFolderOnly = "smartfolder_only"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tagsAndSmartFolder: return NSLocalizedString("video.organize.tags", value: "Finder 标签 + 智能文件夹", comment: "")
        case .smartFolderOnly: return NSLocalizedString("video.organize.smart", value: "仅智能文件夹", comment: "")
        }
    }

    static func from(stored: String) -> VideoOrganizeMethod {
        if stored == "symlinks" { return .tagsAndSmartFolder }
        return VideoOrganizeMethod(rawValue: stored) ?? .tagsAndSmartFolder
    }
}
