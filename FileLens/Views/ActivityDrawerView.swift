/**
 * 净天地咒
 *
 * 天地开朗，四方为裳。
 * 玄水荡涤，辟除不祥。
 * 双童把门，七灵守房。
 * 灵精谨炼，万炁混刚。
 * 内外贞利，福禄延长。
 * 急急如律令。
 *
 * @remarks 来源：太上三洞神咒 卷08 · https://zh.wikisource.org/wiki/太上三洞神呪/8 · kairos-dao-header
 */
import SwiftUI

/// 底部可折叠 Activity 面板。
struct ActivityDrawerView: View {
    @ObservedObject private var log = ActivityLog.shared

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    log.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: log.isExpanded ? "chevron.down" : "chevron.up")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Activity")
                        .font(.caption.weight(.semibold))
                    if let last = log.entries.last {
                        Text(verbatim: last.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    if !log.entries.isEmpty {
                        Text(verbatim: "\(log.entries.count)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    Button("Clear") { log.clear() }
                        .font(.caption2)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if log.isProgressActive, let title = log.progressTitle {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(
                        value: log.progressTotal > 0
                            ? Double(log.progressDone) / Double(log.progressTotal)
                            : nil
                    ) {
                        Text(verbatim: title)
                            .font(.caption)
                    } currentValueLabel: {
                        Text(verbatim: "\(log.progressDone) / \(log.progressTotal)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .progressViewStyle(.linear)
                    if let detail = log.progressDetail {
                        Text(verbatim: detail)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }

            if log.isExpanded {
                Divider()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(log.entries.reversed()) { entry in
                            HStack(alignment: .top, spacing: 6) {
                                Text(verbatim: timeString(entry.time))
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 58, alignment: .leading)
                                Text(verbatim: entry.message)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                }
                .frame(maxHeight: 140)
            }
        }
        .background(.bar)
    }

    private func timeString(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .medium)
    }
}

/// 工具栏进度条。单独订阅 ActivityLog,避免 ffprobe 进度刷新整页 ContentView。
struct ActivityToolbarProgressView: View {
    @ObservedObject private var log = ActivityLog.shared

    var body: some View {
        if log.isProgressActive {
            ProgressView(
                value: log.progressTotal > 0
                    ? Double(log.progressDone) / Double(log.progressTotal)
                    : nil
            )
            .controlSize(.small)
            .frame(width: 64)
            .help(log.progressTitle ?? "")
        }
    }
}
