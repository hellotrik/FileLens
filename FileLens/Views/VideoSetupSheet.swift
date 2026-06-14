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
import SwiftData

/// 一次性向导：选择视频库 + 摄入源，创建对应 Workspace。
struct VideoSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workspace> { !$0.isPendingDeletion })
    private var workspaces: [Workspace]

    @State private var libraryURL: URL?
    @State private var inboxURLs: [URL] = []
    @State private var errorMessage: String?
    @State private var saving = false

    let onFinished: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("video.setup.title")
                .font(.title2.bold())
            Text("video.setup.subtitle")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Form {
                Section("video.setup.library") {
                    HStack {
                        Text(verbatim: libraryURL?.path ?? "—")
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(libraryURL == nil ? .secondary : .primary)
                        Spacer()
                        Button("Choose…") { pickLibrary() }
                    }
                }
                Section("video.setup.inboxes") {
                    if inboxURLs.isEmpty {
                        Text("video.setup.inboxes.empty")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(inboxURLs, id: \.path) { url in
                        Text(verbatim: url.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Button("Add Inbox…") { pickInbox() }
                }
            }
            .formStyle(.grouped)

            if let errorMessage {
                Text(verbatim: errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") { Task { await createWorkspaces() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(libraryURL == nil || saving)
            }
        }
        .padding(24)
        .frame(width: 480)
        .onAppear {
            if libraryURL == nil {
                libraryURL = VideoSettings.expandPath(VideoSettings.defaultRepository)
            }
        }
    }

    private func pickLibrary() {
        guard let url = pickDirectory() else { return }
        libraryURL = url
    }

    private func pickInbox() {
        guard let url = pickDirectory() else { return }
        if !inboxURLs.contains(where: { $0.path == url.path }) {
            inboxURLs.append(url)
        }
    }

    private func pickDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func createWorkspaces() async {
        guard let libraryURL else { return }
        saving = true
        errorMessage = nil
        defer { saving = false }
        do {
            var sort = (workspaces.map(\.sortOrder).max() ?? 0) + 100
            var existing = try modelContext.fetch(FetchDescriptor<Workspace>())
            let pipeline = WorkspacePipelineConfig.default
            let library = try VideoWorkspaceFactory.ensureLibrary(
                at: libraryURL, pipeline: pipeline,
                context: modelContext, existing: existing, sortOrder: sort
            )
            sort += 100
            existing = try modelContext.fetch(FetchDescriptor<Workspace>())
            for url in inboxURLs {
                _ = try VideoWorkspaceFactory.ensureInbox(
                    at: url, linkedLibrary: library,
                    context: modelContext, existing: existing, sortOrder: sort
                )
                sort += 100
                existing = try modelContext.fetch(FetchDescriptor<Workspace>())
            }
            try modelContext.save()
            ActivityLog.shared.append(String(format:
                NSLocalizedString("activity.setup.done.format",
                    value: "Video pipeline ready: %@ + %lld inbox(es).", comment: ""),
                library.effectiveName, Int64(inboxURLs.count)))
            ActivityLog.shared.isExpanded = true
            onFinished()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
