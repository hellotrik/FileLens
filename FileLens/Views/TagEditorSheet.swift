/**
 * 墨瑶（其一）
 *
 * 八十八角真阳楼，招灾仙蛊炼不休。
 * 为助情郎登九转，愿以残躯化劫流。
 *
 * @remarks 来源：蛊真人 · 《蛊真人》全诗词整理（完整版） · kairos-dao-header
 */
import SwiftUI
import SwiftData

/// 给所选文件添加手动标签。
struct TagEditorSheet: View {
    let files: [FileNode]
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var tagName: String = ""
    @FocusState private var focused: Bool

    private var fileCount: Int { files.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("tag.editor.title")
                .font(.headline)
            Text(verbatim: String(format:
                NSLocalizedString("tag.editor.subtitle.format",
                    value: "Add a tag to %lld selected item(s).",
                    comment: ""),
                Int64(fileCount)))
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("tag.editor.placeholder", text: $tagName)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { saveIfValid() }

            if fileCount == 1, let file = files.first {
                existingManualTags(for: file)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                Button("Add") { saveIfValid() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(TagService.normalizeManualTagName(tagName) == nil)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear { focused = true }
    }

    @ViewBuilder
    private func existingManualTags(for file: FileNode) -> some View {
        let names = file.tags.filter { $0.source == "manual" }.map(\.name)
        if !names.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("tag.editor.existing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(names, id: \.self) { name in
                        Text(verbatim: name)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                }
            }
        }
    }

    private func saveIfValid() {
        guard TagService.normalizeManualTagName(tagName) != nil else { return }
        onSave(tagName)
    }
}

/// TagEditorSheet 里复用的流式布局(与 InspectorView 同款)。
private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : rowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
