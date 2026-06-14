/**
 * 花开顷刻
 *
 * 令花草顷刻盛衰、万物加速生长或瞬间凋零；用于枯荣操控。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import Foundation

/// 视频分类维度（对应 video-tools `Classification`）。
struct VideoClassification: Hashable {
    let dimension: String
    let category: String

    /// Finder 标签：`分辨率·4K`
    func tagLabel() -> String {
        "\(dimension)·\(category)"
    }
}

enum VideoClassifier {
    static func classify(meta: VideoMeta, enabledKeys: [String]) -> [VideoClassification] {
        var out: [VideoClassification] = []
        for key in enabledKeys {
            if let c = classifyOne(key: key, meta: meta) {
                out.append(c)
            }
        }
        return out
    }

    static func classifyOne(key: String, meta: VideoMeta) -> VideoClassification? {
        switch key {
        case "resolution": return classifyResolution(meta)
        case "duration": return classifyDuration(meta)
        case "codec": return classifyCodec(meta)
        case "year": return classifyYear(meta)
        default: return nil
        }
    }

    private static func classifyResolution(_ meta: VideoMeta) -> VideoClassification? {
        guard let edge = meta.longEdge else { return nil }
        let cat: String
        switch edge {
        case 2160...: cat = "4K"
        case 1440..<2160: cat = "2K"
        case 1080..<1440: cat = "1080p"
        case 720..<1080: cat = "720p"
        default: cat = "SD"
        }
        return VideoClassification(dimension: NSLocalizedString("video.dim.resolution", value: "分辨率", comment: ""), category: cat)
    }

    private static func classifyDuration(_ meta: VideoMeta) -> VideoClassification? {
        guard let secs = meta.durationSecs else { return nil }
        let cat: String
        if secs < 600 {
            cat = NSLocalizedString("video.cat.short", value: "短片", comment: "")
        } else if secs <= 3600 {
            cat = NSLocalizedString("video.cat.medium", value: "中片", comment: "")
        } else {
            cat = NSLocalizedString("video.cat.movie", value: "电影", comment: "")
        }
        return VideoClassification(dimension: NSLocalizedString("video.dim.duration", value: "时长", comment: ""), category: cat)
    }

    private static func classifyCodec(_ meta: VideoMeta) -> VideoClassification? {
        guard let raw = meta.codec?.lowercased() else { return nil }
        let pretty: String
        switch raw {
        case "hevc", "h265": pretty = "HEVC"
        case "h264", "avc": pretty = "H264"
        case "av1": pretty = "AV1"
        case "vp9": pretty = "VP9"
        case "mpeg4": pretty = "MPEG4"
        default: pretty = raw.uppercased()
        }
        return VideoClassification(dimension: NSLocalizedString("video.dim.codec", value: "编码", comment: ""), category: pretty)
    }

    private static func classifyYear(_ meta: VideoMeta) -> VideoClassification? {
        guard let dt = meta.createdAt else { return nil }
        let year = Calendar.current.component(.year, from: dt)
        return VideoClassification(dimension: NSLocalizedString("video.dim.year", value: "年份", comment: ""), category: String(year))
    }
}
