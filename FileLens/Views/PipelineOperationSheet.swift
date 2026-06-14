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
import SwiftUI
import SwiftData

/// Plan → Review → Apply 统一操作面板。
struct PipelineOperationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var catalogContext
    @Environment(\.workspaceStoreManager) private var storeManager

    let operation: PipelineOperation
    let onFinished: () -> Void

    @State private var renameItems: [VideoRenameItem] = []
    @State private var organizeCount = 0
    @State private var workspaceID: UUID?
    @State private var applying = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 360)
        .onAppear { loadFromOperation() }
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            if applying { ProgressView().controlSize(.small) }
        }
        .padding()
    }

    private var title: String {
        switch operation.kind {
        case .rename:   return NSLocalizedString("operation.rename.title", value: "Clean Filenames", comment: "")
        case .organize: return NSLocalizedString("operation.organize.title", value: "Organize to Finder", comment: "")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch operation.kind {
        case .rename:
            renameList
        case .organize:
            organizeConfirm
        }
    }

    private var renameList: some View {
        Group {
            if renameItems.isEmpty {
                emptyHint(NSLocalizedString("operation.rename.empty",
                                            value: "No filenames need cleaning.", comment: ""))
            } else {
                List {
                    ForEach($renameItems) { $item in
                        HStack {
                            Toggle("", isOn: $item.selected).labelsHidden()
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: item.oldName).font(.caption).foregroundStyle(.secondary)
                                Text(verbatim: "→ \(item.newName)").font(.callout)
                                if let note = item.note {
                                    Text(verbatim: note).font(.caption2).foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var organizeConfirm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: String(format:
                NSLocalizedString("operation.organize.preview.format",
                    value: "Apply Finder tags / Smart Folders to %lld video file(s)?",
                    comment: ""), Int64(organizeCount)))
                .font(.body)
            Text("operation.organize.hint")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let errorMessage {
                Text(verbatim: errorMessage).font(.caption).foregroundStyle(.red)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func emptyHint(_ text: String) -> some View {
        Text(verbatim: text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            if case .rename = operation.kind {
                Text(verbatim: "\(renameItems.filter(\.selected).count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(applyTitle) { Task { await apply() } }
                .keyboardShortcut(.defaultAction)
                .disabled(applying || !canApply)
        }
        .padding()
    }

    private var applyTitle: String {
        switch operation.kind {
        case .rename:   return NSLocalizedString("operation.apply.rename", value: "Rename", comment: "")
        case .organize: return NSLocalizedString("operation.apply.organize", value: "Organize", comment: "")
        }
    }

    private var canApply: Bool {
        switch operation.kind {
        case .rename:   return renameItems.contains(where: \.selected)
        case .organize: return organizeCount > 0
        }
    }

    private func loadFromOperation() {
        switch operation.kind {
        case .rename(let wsID, let items):
            workspaceID = wsID
            renameItems = items
        case .organize(let wsID, let count):
            workspaceID = wsID
            organizeCount = count
        }
    }

    private func apply() async {
        applying = true
        defer { applying = false }
        switch operation.kind {
        case .rename:
            await applyRename()
        case .organize:
            await applyOrganize()
        }
    }

    private func applyRename() async {
        guard let workspaceID,
              let ws = fetchWorkspace(workspaceID),
              let storeCtx = try? storeManager?.store(for: workspaceID).mainContext else { return }
        do {
            let repo = try VideoPipelineRunner.folderURL(for: ws)
            let nodes = (try? storeCtx.fetch(FetchDescriptor<FileNode>(
                predicate: #Predicate { $0.isPresent }
            ))) ?? []
            let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
            let report = VideoRenameExecutor.apply(
                items: renameItems,
                repository: repo,
                nodesByID: byID
            )
            try? storeCtx.save()
            ActivityLog.shared.append(String(format:
                NSLocalizedString("activity.rename.done.format",
                    value: "Renamed %lld, skipped %lld.", comment: ""),
                Int64(report.renamed), Int64(report.skipped)))
            onFinished()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyOrganize() async {
        guard let workspaceID, let ws = fetchWorkspace(workspaceID) else { return }
        let report = await Task.detached {
            VideoPipelineRunner.organize(library: ws)
        }.value
        ActivityLog.shared.append(report.summary)
        onFinished()
        dismiss()
    }

    private func fetchWorkspace(_ id: UUID) -> Workspace? {
        let d = FetchDescriptor<Workspace>(predicate: #Predicate { $0.id == id })
        return try? catalogContext.fetch(d).first
    }
}
