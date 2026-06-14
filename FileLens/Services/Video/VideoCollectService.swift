/**
 * 变形咒
 *
 * 三天之令，化吾之形。
 * 青龙白虎，侍卫我身。
 * 邪鬼远遁，真炁速生。
 * 急急如律令。
 *
 * @remarks 来源：太上三洞神咒卷之四 · https://zh.wikisource.org/wiki/太上三洞神呪/4 · kairos-dao-header
 */
import Foundation
import CryptoKit

struct VideoMoveOutcome {
    let source: URL
    let finalPath: URL
    let bytes: UInt64
    let crossedVolumes: Bool
}

struct VideoMoveProgress {
    let current: URL
    let processed: Int
    let total: Int
}

enum VideoCollectService {
    static func collect(
        sources: [URL],
        repository: URL,
        onProgress: ((VideoMoveProgress) -> Void)? = nil
    ) -> (ok: [VideoMoveOutcome], errors: [(URL, Error)]) {
        try? FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        var ok: [VideoMoveOutcome] = []
        var errs: [(URL, Error)] = []
        let total = sources.count
        for (i, src) in sources.enumerated() {
            onProgress?(VideoMoveProgress(current: src, processed: i, total: total))
            switch moveOne(source: src, repository: repository) {
            case .success(let o): ok.append(o)
            case .failure(let e): errs.append((src, e))
            }
        }
        onProgress?(VideoMoveProgress(current: repository, processed: total, total: total))
        return (ok, errs)
    }

    static func moveOne(source: URL, repository: URL) -> Result<VideoMoveOutcome, Error> {
        guard let name = source.lastPathComponent as String? else {
            return .failure(NSError(domain: "VideoCollect", code: 1, userInfo: [NSLocalizedDescriptionKey: "无文件名"]))
        }
        let target = pickNonConflictingTarget(in: repository, fileName: name)
        let bytes: UInt64
        do {
            bytes = try FileManager.default.attributesOfItem(atPath: source.path)[.size] as? UInt64 ?? 0
        } catch {
            return .failure(error)
        }
        do {
            try FileManager.default.moveItem(at: source, to: target)
            return .success(VideoMoveOutcome(source: source, finalPath: target, bytes: bytes, crossedVolumes: false))
        } catch let e as NSError where e.domain == NSPOSIXErrorDomain && e.code == 18 {
            return copyVerifyRemove(source: source, target: target, bytes: bytes)
        } catch {
            return copyVerifyRemove(source: source, target: target, bytes: bytes)
        }
    }

    private static func pickNonConflictingTarget(in repo: URL, fileName: String) -> URL {
        var candidate = repo.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        let ns = fileName as NSString
        let stem = ns.deletingPathExtension
        let ext = ns.pathExtension
        for n in 2...999 {
            let base = ext.isEmpty ? "\(stem)_\(n)" : "\(stem)_\(n).\(ext)"
            candidate = repo.appendingPathComponent(base)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return repo.appendingPathComponent("\(stem)_999.\(ext)")
    }

    private static func copyVerifyRemove(source: URL, target: URL, bytes: UInt64) -> Result<VideoMoveOutcome, Error> {
        let partial = target.appendingPathExtension("partial")
        let fm = FileManager.default
        if fm.fileExists(atPath: partial.path) { try? fm.removeItem(at: partial) }
        do {
            try fm.copyItem(at: source, to: partial)
            let srcHash = try sha256(of: source)
            let dstHash = try sha256(of: partial)
            guard srcHash == dstHash else {
                try? fm.removeItem(at: partial)
                return .failure(NSError(domain: "VideoCollect", code: 2, userInfo: [NSLocalizedDescriptionKey: "SHA-256 校验失败"]))
            }
            if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
            try fm.moveItem(at: partial, to: target)
            try fm.removeItem(at: source)
            return .success(VideoMoveOutcome(source: source, finalPath: target, bytes: bytes, crossedVolumes: true))
        } catch {
            try? fm.removeItem(at: partial)
            return .failure(error)
        }
    }

    private static func sha256(of url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
