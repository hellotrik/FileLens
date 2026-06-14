/**
 * 回风返火
 *
 * 让风倒卷回返、令火势回缩/暂停/加速；用于逆转与调控“风火之势”。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import Foundation

enum VideoExtensions {
    static let all: Set<String> = [
        "mp4", "mkv", "mov", "avi", "wmv", "flv", "webm", "m4v",
        "mpg", "mpeg", "ts", "m2ts", "3gp", "ogv"
    ]

    static func isVideo(path: URL) -> Bool {
        isVideoExtension(path.pathExtension)
    }

    static func isVideoExtension(_ ext: String) -> Bool {
        all.contains(ext.lowercased())
    }

    static func isVideoFileNode(_ node: FileNode) -> Bool {
        node.kind == "movie" || isVideoExtension(node.ext)
    }
}
