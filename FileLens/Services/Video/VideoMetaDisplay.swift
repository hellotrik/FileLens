/**
 * 气绝魔仙
 *
 * 金玉如一梦，万年恨寂寥。
 * 五域九天功，尽在一气中。
 *
 * @remarks 来源：蛊真人 · 《蛊真人》全诗词整理（完整版） · kairos-dao-header
 */
import Foundation

enum VideoMetaDisplay {
    static func summary(from json: String) -> String? {
        guard let meta = VideoMetaCoding.decode(json), !json.isEmpty else { return nil }
        var parts: [String] = []
        if let res = resolutionLabel(meta) { parts.append(res) }
        if let dur = durationLabel(meta) { parts.append(dur) }
        if let codec = codecLabel(meta) { parts.append(codec) }
        if let year = yearLabel(meta) { parts.append(year) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static func resolutionLabel(_ meta: VideoMeta) -> String? {
        guard let w = meta.width, let h = meta.height else { return nil }
        return "\(w)×\(h)"
    }

    static func durationLabel(_ meta: VideoMeta) -> String? {
        guard let secs = meta.durationSecs, secs > 0 else { return nil }
        let total = Int(secs.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    static func codecLabel(_ meta: VideoMeta) -> String? {
        guard let raw = meta.codec?.lowercased() else { return nil }
        switch raw {
        case "hevc", "h265": return "HEVC"
        case "h264", "avc": return "H264"
        default: return raw.uppercased()
        }
    }

    static func yearLabel(_ meta: VideoMeta) -> String? {
        guard let dt = meta.createdAt else { return nil }
        return String(Calendar.current.component(.year, from: dt))
    }
}
