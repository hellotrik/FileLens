/**
 * 隔垣洞见
 *
 * 隔垣洞见、彻视洞达十方；用于洞察隐匿、观察气运与看破虚妄（天眼通设定）。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import Foundation
import Combine

extension Notification.Name {
    /// `object` 为 `Bool`：进度条是否占用 UI（start/end 时发，update 不发）。
    static let activityProgressActiveChanged = Notification.Name("filelens.activityProgressActiveChanged")
}

/// 主窗口底部 Activity 日志（替代 Video Tools 日志 Tab）。
@MainActor
final class ActivityLog: ObservableObject {
    static let shared = ActivityLog()

    /// 进度数值刷新间隔。ffprobe 每文件回调一次，不节流会把 ContentView 绑死。
    private static let progressThrottle: Duration = .milliseconds(150)

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
    private var pendingProgress: (done: Int, total: Int?, title: String?, detail: String?)?
    private var progressFlushTask: Task<Void, Never>?

    private init() {}

    func startProgress(title: String, total: Int) {
        cancelProgressFlush()
        progressTitle = title
        progressTotal = max(total, 1)
        progressDone = 0
        progressDetail = nil
        isProgressActive = true
        isExpanded = true
        postProgressActive(true)
    }

    func updateProgress(done: Int, total: Int? = nil, title: String? = nil, detail: String? = nil) {
        pendingProgress = (done, total, title, detail)
        guard progressFlushTask == nil else { return }
        progressFlushTask = Task { @MainActor in
            try? await Task.sleep(for: Self.progressThrottle)
            guard !Task.isCancelled else { return }
            flushPendingProgress()
        }
    }

    func endProgress() {
        cancelProgressFlush()
        if let pending = pendingProgress {
            applyProgress(pending)
            pendingProgress = nil
        }
        isProgressActive = false
        progressTitle = nil
        progressDetail = nil
        progressDone = 0
        progressTotal = 0
        postProgressActive(false)
    }

    private func cancelProgressFlush() {
        progressFlushTask?.cancel()
        progressFlushTask = nil
    }

    private func flushPendingProgress() {
        progressFlushTask = nil
        guard let pending = pendingProgress else { return }
        pendingProgress = nil
        applyProgress(pending)
    }

    private func applyProgress(_ pending: (done: Int, total: Int?, title: String?, detail: String?)) {
        progressDone = pending.done
        if let total = pending.total { progressTotal = max(total, 1) }
        if let title = pending.title { progressTitle = title }
        if let detail = pending.detail { progressDetail = detail }
    }

    private func postProgressActive(_ active: Bool) {
        NotificationCenter.default.post(
            name: .activityProgressActiveChanged,
            object: active
        )
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
