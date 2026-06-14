/**
 * 飞身托迹
 *
 * 遁身天地之间、不可观不可查；用于隐匿、空间跳跃与托迹潜行。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import Foundation

/// ffprobe 抽取的视频元数据快照（对应 video-tools `VideoMeta`）。
struct VideoMeta: Codable, Sendable, Equatable {
    var width: Int?
    var height: Int?
    var durationSecs: Double?
    var codec: String?
    var bitrate: UInt64?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case width, height, codec, bitrate
        case durationSecs = "duration_secs"
        case createdAt = "created_at"
    }

    static let empty = VideoMeta()

    /// 分类用「长边」像素（竖屏取 max(w,h)）。
    var longEdge: Int? {
        guard let h = height else { return width }
        let w = width ?? 0
        return max(h, w)
    }
}

enum VideoMetaCoding {
    static func encode(_ meta: VideoMeta) -> String {
        guard let data = try? JSONEncoder().encode(meta),
              let s = String(data: data, encoding: .utf8) else { return "" }
        return s
    }

    static func decode(_ json: String) -> VideoMeta? {
        guard !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(VideoMeta.self, from: data)
    }

    /// 用于跳过重复 probe：`size-mtime`。
    static func probeKey(size: Int64, modified: Date) -> String {
        "\(size)-\(Int(modified.timeIntervalSince1970))"
    }
}
