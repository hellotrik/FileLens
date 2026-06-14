/**
 * 移山
 *
 * 搬运山岳、改易地脉；用于大规模地形与物体位移（设定）。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import Foundation

/// Workspace 在 FileLens 中的角色：浏览 / 视频摄入 / 视频库。
enum WorkspaceRole: String, CaseIterable, Identifiable, Codable {
    case watch = "watch"
    case inbox = "inbox"
    case library = "library"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .watch:   return NSLocalizedString("workspace.role.watch", value: "文件夹", comment: "")
        case .inbox:   return NSLocalizedString("workspace.role.inbox", value: "摄入源", comment: "")
        case .library: return NSLocalizedString("workspace.role.library", value: "视频库", comment: "")
        }
    }

    var sidebarSectionTitle: String {
        switch self {
        case .watch:   return NSLocalizedString("workspace.section.folders", value: "Folders", comment: "")
        case .inbox:   return NSLocalizedString("workspace.section.inboxes", value: "Inboxes", comment: "")
        case .library: return NSLocalizedString("workspace.section.libraries", value: "Libraries", comment: "")
        }
    }

    var systemImage: String {
        switch self {
        case .watch:   return "folder"
        case .inbox:   return "tray.and.arrow.down"
        case .library: return "film.stack"
        }
    }
}

/// 管道配置（编码进 `Workspace.pipelineJSON`）。
struct WorkspacePipelineConfig: Codable, Equatable {
    var organizeMethod: String = VideoSettings.defaultOrganizeMethod
    var enabledRuleKeys: [String] = VideoSettings.defaultRuleKeys
    var renameOptions: VideoRenameOptions = .default
    /// library / watch 是否在索引后 ffprobe。
    var probeVideos: Bool = true

    static let `default` = WorkspacePipelineConfig()
}

enum WorkspacePipelineCodec {
    static func decode(_ json: String) -> WorkspacePipelineConfig {
        guard !json.isEmpty,
              let data = json.data(using: .utf8),
              let cfg = try? JSONDecoder().decode(WorkspacePipelineConfig.self, from: data)
        else { return .default }
        if cfg.organizeMethod == "symlinks" {
            var fixed = cfg
            fixed.organizeMethod = VideoSettings.defaultOrganizeMethod
            return fixed
        }
        return cfg
    }

    static func encode(_ cfg: WorkspacePipelineConfig) -> String {
        guard let data = try? JSONEncoder().encode(cfg),
              let s = String(data: data, encoding: .utf8) else { return "" }
        return s
    }
}

extension Workspace {
    var role: WorkspaceRole {
        get { WorkspaceRole(rawValue: roleRaw) ?? .watch }
        set { roleRaw = newValue.rawValue }
    }

    var pipeline: WorkspacePipelineConfig {
        get { WorkspacePipelineCodec.decode(pipelineJSON) }
        set { pipelineJSON = WorkspacePipelineCodec.encode(newValue) }
    }

    var linkedLibraryUUID: UUID? {
        get {
            guard !linkedLibraryID.isEmpty else { return nil }
            return UUID(uuidString: linkedLibraryID)
        }
        set { linkedLibraryID = newValue?.uuidString ?? "" }
    }
}
