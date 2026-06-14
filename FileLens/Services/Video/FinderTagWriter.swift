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

    static func pickColor(forDimension dimension: String) -> TagColor {
        switch dimension {
        case "分辨率", "Resolution": return .blue
        case "时长", "Duration": return .green
        case "编码", "Codec": return .purple
        case "年份", "Year": return .orange
        default: return .gray
        }
    }

    static func mergeTags(into url: URL, classifications: [VideoClassification]) throws {
        var merged = Set(readExistingTags(at: url))
        for c in classifications {
            let label = c.tagLabel()
            let color = pickColor(forDimension: c.dimension)
            merged.insert("\(label)\n\(color.rawValue)")
        }
        let arr = merged.sorted().map { $0 as NSString }
        let plist = arr as NSArray
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
        try setXattr(path: url.path, name: xattrName, data: data)
    }

    static func readExistingTags(at url: URL) -> [String] {
        guard let data = getXattr(path: url.path, name: xattrName) else { return [] }
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let arr = plist as? [String] else { return [] }
        return arr
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
