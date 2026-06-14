/**
 * 杂篇名句
 *
 * 折剑沉沙，千古兴亡，不尽天河滚荡。
 * 物换心移几春秋，唯天意苍茫。
 * 
 * 座座鹰巢入我手，百足蛊仙奈我何？
 * 
 * 大海啊，你全是水。
 * 骏马啊，你四条腿。
 * 美人啊，你眼含波。
 *
 * @remarks 来源：蛊真人 · 《蛊真人》全诗词整理（完整版） · kairos-dao-header
 */
import Foundation

enum FinderTagWriter {
    static let xattrName = "com.apple.metadata:_kMDItemUserTags"

    enum TagColor: UInt8 {
        case none = 0, gray = 1, green = 2, purple = 3
        case blue = 4, yellow = 5, red = 6, orange = 7
    }

    struct TagEntry: Sendable {
        let label: String
        let color: TagColor
    }

    /// 将 FileLens 规则色 (#RRGGBB) 映射到 Finder 七色标签。
    static func colorFromRuleHex(_ hex: String) -> TagColor {
        let h = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch h {
        case "#a78bfa", "#8b5cf6", "#ec4899": return .purple
        case "#3b82f6", "#2563eb", "#0ea5e9": return .blue
        case "#10b981", "#059669", "#16a34a", "#22c55e": return .green
        case "#ef4444", "#dc2626": return .red
        case "#f59e0b", "#f97316": return .orange
        case "#eab308", "#fbbf24": return .yellow
        case "#6b7280", "#9ca3af", "#a3a3a3": return .gray
        default:
            let n = abs(h.hashValue)
            return TagColor(rawValue: UInt8((n % 7) + 1)) ?? .gray
        }
    }

    static func pickColor(forDimension dimension: String) -> TagColor {
        switch dimension {
        case "分辨率", "Resolution": return .blue
        case "时长", "Duration": return .green
        case "编码", "Codec": return .purple
        case "年份", "Year": return .orange
        default: return .gray
        }
    }

    static func mergeTags(into url: URL, entries: [TagEntry]) throws {
        var merged = Set(readExistingTags(at: url))
        for e in entries {
            merged.insert("\(e.label)\n\(e.color.rawValue)")
        }
        let arr = merged.sorted().map { $0 as NSString }
        let plist = arr as NSArray
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
        try setXattr(path: url.path, name: xattrName, data: data)
    }

    static func mergeTags(into url: URL, classifications: [VideoClassification]) throws {
        let entries = classifications.map {
            TagEntry(label: $0.tagLabel(), color: pickColor(forDimension: $0.dimension))
        }
        try mergeTags(into: url, entries: entries)
    }

    static func readExistingTags(at url: URL) -> [String] {
        guard let data = getXattr(path: url.path, name: xattrName) else { return [] }
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let arr = plist as? [String] else { return [] }
        return arr
    }

    static func hasTags(at url: URL) -> Bool {
        !readExistingTags(at: url).isEmpty
    }

    /// 移除 macOS Finder 彩色标签（`com.apple.metadata:_kMDItemUserTags`）。
    static func clearTags(at url: URL) throws {
        let rc = removexattr(url.path, xattrName, 0)
        if rc == 0 { return }
        if errno == ENOATTR { return }
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [
            NSLocalizedDescriptionKey: "removexattr 失败: \(url.path)"
        ])
    }

    private static func setXattr(path: String, name: String, data: Data) throws {
        let rc = data.withUnsafeBytes { buf in
            setxattr(path, name, buf.baseAddress, data.count, 0, 0)
        }
        if rc != 0 {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [
                NSLocalizedDescriptionKey: "setxattr 失败: \(path)"
            ])
        }
    }

    private static func getXattr(path: String, name: String) -> Data? {
        let len = getxattr(path, name, nil, 0, 0, 0)
        guard len > 0 else { return nil }
        var data = Data(count: len)
        let read = data.withUnsafeMutableBytes { buf in
            getxattr(path, name, buf.baseAddress, len, 0, 0)
        }
        guard read == len else { return nil }
        return data
    }
}
