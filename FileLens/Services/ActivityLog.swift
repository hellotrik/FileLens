/**
 * 隔垣洞见
 *
 * 隔垣洞见、彻视洞达十方；用于洞察隐匿、观察气运与看破虚妄（天眼通设定）。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import Foundation
import Combine

/// 主窗口底部 Activity 日志（替代 Video Tools 日志 Tab）。
@MainActor
final class ActivityLog: ObservableObject {
    static let shared = ActivityLog()

    struct Entry: Identifiable, Equatable {
        let id = UUID()
        let time: Date
        let message: String
    }

    @Published private(set) var entries: [Entry] = []
    @Published var isExpanded = false
    @Published private(set) var progressDone: Int = 0
    @Published private(set) var progressTotal: Int = 0
    @Published private(set) var progressTitle: String?
    @Published private(set) var progressDetail: String?
    @Published private(set) var isProgressActive: Bool = false

    private let maxEntries = 200

    private init() {}

    func startProgress(title: String, total: Int) {
        progressTitle = title
        progressTotal = max(total, 1)
        progressDone = 0
        isProgressActive = true
        isExpanded = true
    }

    func updateProgress(done: Int, total: Int? = nil, title: String? = nil, detail: String? = nil) {
        progressDone = done
        if let total { progressTotal = max(total, 1) }
        if let title { progressTitle = title }
        if let detail { progressDetail = detail }
    }

    func endProgress() {
        isProgressActive = false
        progressTitle = nil
        progressDetail = nil
        progressDone = 0
        progressTotal = 0
    }

    func append(_ message: String) {
        let entry = Entry(time: .now, message: message)
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }

    func toggleExpanded() {
        isExpanded.toggle()
    }
}
