/**
 * 武庸
 *
 * 永生飘缈非我求，长生无为老愧羞。
 * 界壁消散乱世起，宿命一去竞自由。
 * 鹰击长空鲸霸海，不试怎知龙与蚯？
 * 凡夫俗子岂识我，非到末路不甘休！
 *
 * @remarks 来源：蛊真人 · 《蛊真人》全诗词整理（完整版） · kairos-dao-header
 */
import Foundation

enum VideoRenameCleaner {
    static func cleanFilename(_ filename: String, options: VideoRenameOptions) -> String {
        let (stem, ext) = splitStemAndExt(filename)
        var newStem = cleanStem(stem, options: options)
        if newStem.isEmpty { newStem = stem.trimmingCharacters(in: .whitespaces) }
        let newExt = options.lowercaseExt ? ext.lowercased() : ext
        return newExt.isEmpty ? newStem : "\(newStem).\(newExt)"
    }

    static func splitStemAndExt(_ filename: String) -> (String, String) {
        let trimmed = filename.trimmingCharacters(in: .whitespaces)
        guard let idx = trimmed.lastIndex(of: "."),
              idx != trimmed.startIndex,
              trimmed.index(after: idx) < trimmed.endIndex else {
            return (trimmed, "")
        }
        return (String(trimmed[..<idx]), String(trimmed[trimmed.index(after: idx)...]))
    }

    static func cleanStem(_ stem: String, options: VideoRenameOptions) -> String {
        var s = stem
        if options.stripSquare { s = stripPaired(s, open: "[", close: "]") }
        if options.stripCJKBrace { s = stripPaired(s, open: "【", close: "】") }
        if options.stripCurly { s = stripPaired(s, open: "{", close: "}") }
        if options.underscoreCopySuffix { s = appendCopySuffixes(from: s) }
        if options.stripRound { s = stripPaired(s, open: "(", close: ")") }
        if options.collapseSeparators {
            let gap: Character = options.underscoreBetweenWords ? "_" : " "
            s = collapseSeparators(s, gap: gap)
            if options.underscoreBetweenWords {
                s = squeezeGap(s, gap: "_")
                s = restoreSpaceBeforeLongDigitParen(s)
            }
        } else {
            s = s.trimmingCharacters(in: .whitespaces)
        }
        if !options.underscoreBetweenWords {
            s = s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        return s
    }

    private static func stripPaired(_ input: String, open: String, close: String) -> String {
        var out = ""
        var depth = 0
        var i = input.startIndex
        while i < input.endIndex {
            if input[i...].hasPrefix(open) {
                depth += 1
                i = input.index(i, offsetBy: open.count)
                continue
            }
            if input[i...].hasPrefix(close), depth > 0 {
                depth -= 1
                i = input.index(i, offsetBy: close.count)
                continue
            }
            if depth == 0 { out.append(input[i]) }
            i = input.index(after: i)
        }
        return out
    }

    private static func collapseSeparators(_ input: String, gap: Character) -> String {
        var out = ""
        var lastGap = true
        for ch in input {
            let isSep = ch == "_" || ch == "." || ch == "+" || ch.isWhitespace
            if isSep {
                if !lastGap { out.append(gap); lastGap = true }
            } else {
                out.append(ch)
                lastGap = false
            }
        }
        var t = String(out.trimmingCharacters(in: .whitespaces))
        if gap == "_" {
            t = t.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        }
        return t
    }

    private static func squeezeGap(_ input: String, gap: Character) -> String {
        var out = ""
        var last = true
        for ch in input {
            if ch == gap {
                if !last { out.append(gap); last = true }
            } else {
                out.append(ch)
                last = false
            }
        }
        return out.trimmingCharacters(in: CharacterSet(charactersIn: String(gap)))
    }

    private static func restoreSpaceBeforeLongDigitParen(_ input: String) -> String {
        // `word_(720)` → `word (720)`
        let pattern = #"_(?=\(\d{3,}\))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        let range = NSRange(input.startIndex..., in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: " ")
    }

    private static func appendCopySuffixes(from s: String) -> String {
        var nums: [String] = []
        var cur = s
        while true {
            let t = cur.trimmingCharacters(in: .whitespaces)
            guard let (prefix, num) = takeTrailingParenCopy(t) else { break }
            nums.append(num)
            cur = prefix
        }
        nums.reverse()
        let tail = nums.map { "_\($0)" }.joined()
        return cur.trimmingCharacters(in: .whitespaces) + tail
    }

    private static func takeTrailingParenCopy(_ s: String) -> (String, String)? {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.hasSuffix(")"), let open = t.lastIndex(of: "(") else { return nil }
        let innerStart = t.index(after: open)
        guard innerStart < t.index(before: t.endIndex) else { return nil }
        let inner = String(t[innerStart..<t.index(before: t.endIndex)])
        guard !inner.isEmpty, inner.count <= 2, inner.allSatisfy(\.isNumber) else { return nil }
        let prefix = String(t[..<open]).trimmingCharacters(in: .whitespaces)
        return (prefix, inner)
    }
}

struct VideoRenameItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var fileID: UUID
    var relativePath: String
    var oldName: String
    var newName: String
    var selected: Bool
    var note: String?
}

enum VideoRenamePlanner {
    static func plan(nodes: [FileNode], options: VideoRenameOptions) -> [VideoRenameItem] {
        var byParent: [String: [(FileNode, String)]] = [:]
        for node in nodes where node.isPresent {
            let newName = VideoRenameCleaner.cleanFilename(node.name, options: options)
            if newName == node.name { continue }
            let parent = (node.relativePath as NSString).deletingLastPathComponent
            byParent[parent, default: []].append((node, newName))
        }
        var out: [VideoRenameItem] = []
        for (_, group) in byParent {
            var groupSorted = group.sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
            var taken = Set<String>()
            var nameCounts: [String: Int] = [:]
            for (node, candidate) in groupSorted {
                nameCounts[candidate, default: 0] += 1
                let conflict = nameCounts[candidate, default: 0] > 1
                var finalName = candidate
                if conflict || taken.contains(finalName) {
                    finalName = ensureUnique(candidate: candidate, taken: taken)
                }
                taken.insert(finalName)
                out.append(VideoRenameItem(
                    fileID: node.id,
                    relativePath: node.relativePath,
                    oldName: node.name,
                    newName: finalName,
                    selected: !conflict,
                    note: conflict ? NSLocalizedString("video.rename.conflict", value: "与同目录冲突，已加后缀", comment: "") : nil
                ))
            }
        }
        return out.sorted { $0.relativePath.localizedCaseInsensitiveCompare($1.relativePath) == .orderedAscending }
    }

    private static func ensureUnique(candidate: String, taken: Set<String>) -> String {
        let (stem, ext) = VideoRenameCleaner.splitStemAndExt(candidate)
        for n in 1..<Int.max {
            let next = ext.isEmpty ? "\(stem)-\(n)" : "\(stem)-\(n).\(ext)"
            if !taken.contains(next) { return next }
        }
        return candidate
    }
}

struct VideoRenameReport {
    var renamed = 0
    var skipped = 0
    var failures: [(UUID, String)] = []
}

enum VideoRenameExecutor {
    static func apply(
        items: [VideoRenameItem],
        repository: URL,
        nodesByID: [UUID: FileNode],
        onProgress: ((Int, Int) -> Void)? = nil
    ) -> VideoRenameReport {
        var report = VideoRenameReport()
        let selected = items.filter(\.selected)
        let total = selected.count
        for (i, item) in selected.enumerated() {
            onProgress?(i + 1, total)
            guard let node = nodesByID[item.fileID] else {
                report.skipped += 1
                continue
            }
            let oldURL = repository.appendingPathComponent(node.relativePath)
            let parent = oldURL.deletingLastPathComponent()
            let newURL = parent.appendingPathComponent(item.newName)
            do {
                try FileManager.default.moveItem(at: oldURL, to: newURL)
                let newRel = (repository.path as NSString).length > 0
                    ? newURL.path.replacingOccurrences(of: repository.path + "/", with: "")
                    : item.newName
                node.relativePath = newRel
                node.name = item.newName
                if !item.newName.isEmpty {
                    node.ext = (item.newName as NSString).pathExtension.lowercased()
                }
                node.videoProbeKey = ""
                report.renamed += 1
            } catch {
                report.failures.append((item.fileID, error.localizedDescription))
            }
        }
        return report
    }
}
