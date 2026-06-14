/**
 * 搬运术
 *
 * 隔空取物、移形换影；用于搬运物体与改变位置（设定）。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import Foundation
import SwiftData

/// 从 video-tools `~/.config/video-tui/config.toml` 导入为 Workspace。
enum VideoConfigImporter {
    static var legacyConfigURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".config/video-tui/config.toml")
    }

    private static let importedKey = "filelens.videoConfigWorkspaces.imported"

    struct ParsedConfig {
        var sources: [String] = []
        var repository: String?
        var enabledRuleKeys: [String] = []
        var organizeMethod: String?
        var rename: VideoRenameOptions?
        var hasContent: Bool {
            repository != nil || !sources.isEmpty || organizeMethod != nil
                || !enabledRuleKeys.isEmpty || rename != nil
        }
    }

    static func legacyConfigExists() -> Bool {
        FileManager.default.fileExists(atPath: legacyConfigURL.path)
    }

    static func parseLegacyFile() -> ParsedConfig? {
        guard let raw = try? String(contentsOf: legacyConfigURL, encoding: .utf8) else { return nil }
        let parsed = parse(raw)
        return parsed.hasContent ? parsed : nil
    }

    /// 解析 legacy 配置并创建/更新 library + inbox workspace。
    @discardableResult
    static func importToCatalog(context: ModelContext, force: Bool = false) throws -> String? {
        if !force, UserDefaults.standard.bool(forKey: importedKey) { return nil }
        guard let parsed = parseLegacyFile() else { return nil }

        let summary = try apply(parsed, context: context)
        UserDefaults.standard.set(true, forKey: importedKey)
        return summary
    }

    @discardableResult
    static func apply(_ parsed: ParsedConfig, context: ModelContext) throws -> String {
        var workspaces = try context.fetch(FetchDescriptor<Workspace>())
        var sort = (workspaces.map(\.sortOrder).max() ?? 0) + 100
        let pipeline = VideoWorkspaceFactory.pipelineFromLegacy(parsed)
        var library: Workspace?

        if let repo = parsed.repository {
            let url = VideoSettings.expandPath(repo)
            library = try VideoWorkspaceFactory.ensureLibrary(
                at: url, pipeline: pipeline, context: context,
                existing: workspaces, sortOrder: sort
            )
            sort += 100
            workspaces = try context.fetch(FetchDescriptor<Workspace>())
        }

        var inboxCount = 0
        for source in parsed.sources {
            let url = VideoSettings.expandPath(source)
            _ = try VideoWorkspaceFactory.ensureInbox(
                at: url, linkedLibrary: library, context: context,
                existing: workspaces, sortOrder: sort
            )
            sort += 100
            inboxCount += 1
            workspaces = try context.fetch(FetchDescriptor<Workspace>())
        }

        try context.save()

        var lines = [NSLocalizedString("video.import.done", value: "Video workspaces configured.", comment: "")]
        if library != nil {
            lines.append(String(format: NSLocalizedString("video.import.library.format",
                value: "Library: %@", comment: ""), library!.folderPath))
        }
        if inboxCount > 0 {
            lines.append(String(format: NSLocalizedString("video.import.inboxes.format",
                value: "%lld inbox(es)", comment: ""), Int64(inboxCount)))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - TOML parser

    private static func parse(_ raw: String) -> ParsedConfig {
        var out = ParsedConfig()
        var section = ""
        var rename = VideoRenameOptions.default
        var renameTouched = false

        for line in raw.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                section = String(trimmed.dropFirst().dropLast()).lowercased()
                continue
            }
            guard let eq = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[..<eq]).trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(trimmed[trimmed.index(after: eq)...])
                .trimmingCharacters(in: .whitespaces)

            switch section {
            case "paths":
                if key == "repository" { out.repository = parseString(value) }
                else if key == "sources" { out.sources = parseStringArray(value) }
            case "rules":
                if key == "enabled" { out.enabledRuleKeys = parseStringArray(value) }
            case "organize":
                if key == "default_method" { out.organizeMethod = parseString(value) }
            case "rename":
                if let b = parseBool(value) {
                    renameTouched = true
                    switch key {
                    case "strip_square": rename.stripSquare = b
                    case "strip_round": rename.stripRound = b
                    case "strip_cjk_brace": rename.stripCJKBrace = b
                    case "strip_curly": rename.stripCurly = b
                    case "collapse_separators": rename.collapseSeparators = b
                    case "underscore_between_words": rename.underscoreBetweenWords = b
                    case "underscore_copy_suffix": rename.underscoreCopySuffix = b
                    case "lowercase_ext": rename.lowercaseExt = b
                    default: break
                    }
                }
            default: break
            }
        }
        if renameTouched { out.rename = rename }
        return out
    }

    private static func parseString(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("\""), s.hasSuffix("\""), s.count >= 2 {
            return String(s.dropFirst().dropLast())
        }
        return s.isEmpty ? nil : s
    }

    private static func parseStringArray(_ raw: String) -> [String] {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard s.hasPrefix("["), s.hasSuffix("]") else { return [] }
        let inner = s.dropFirst().dropLast()
        return inner.split(separator: ",").compactMap { part in
            parseString(String(part))
        }
    }

    private static func parseBool(_ raw: String) -> Bool? {
        switch raw.trimmingCharacters(in: .whitespaces).lowercased() {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }
}
