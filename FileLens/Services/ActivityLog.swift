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

    private let maxEntries = 200

    private init() {}

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
