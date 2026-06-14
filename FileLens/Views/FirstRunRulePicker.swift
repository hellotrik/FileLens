import SwiftUI

struct FirstRunRulePicker: View {
    let folderName: String
    @State private var role: WorkspaceRole = .watch
    @State private var ruleTemplates: [Rule]
    @State private var enabled: Set<UUID>
    @State private var recursive: Bool = false
    let onConfirm: (_ role: WorkspaceRole, _ enabledRuleNames: Set<String>, _ recursive: Bool) -> Void
    let onCancel: () -> Void

    init(folderName: String,
         onConfirm: @escaping (_ role: WorkspaceRole, _ enabledRuleNames: Set<String>, _ recursive: Bool) -> Void,
         onCancel: @escaping () -> Void) {
        self.folderName = folderName
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        let initial = BuiltInRules.all()
        self._ruleTemplates = State(initialValue: initial)
        self._enabled = State(initialValue: Set(initial.map(\.id)))
    }

    private var allSelected: Bool { enabled.count == ruleTemplates.count && !ruleTemplates.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: String(format: NSLocalizedString("picker.title.format",
                    value: "Set up rules for “%@”", comment: ""), folderName))
                    .font(.title3.bold())
                Text("picker.subtitle.unified")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Picker("picker.role", selection: $role) {
                ForEach(WorkspaceRole.allCases) { r in
                    Label(r.label, systemImage: r.systemImage).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: role) { _, newRole in
                let templates = newRole == .library
                    ? BuiltInVideoRules.libraryPack()
                    : BuiltInRules.all()
                ruleTemplates = templates
                enabled = Set(templates.map(\.id))
                if newRole == .library { recursive = true }
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text(role == .library ? "picker.recommendation.library" : "picker.recommendation.watch")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.12))
            )

            List {
                ForEach(ruleTemplates, id: \.id) { r in
                    ruleRow(r)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: false))
            .scrollContentBackground(.hidden)
            .frame(minHeight: 340, maxHeight: 400)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.6),
                            lineWidth: 0.5)
            )

            HStack(spacing: 8) {
                Toggle(isOn: $recursive) {
                    Text("picker.recursive")
                        .font(.callout)
                }
                .toggleStyle(.checkbox)
                Text(role == .library ? "picker.recursive.libraryHint" : "picker.recursive.hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 12) {
                Text(verbatim: String(format: NSLocalizedString("picker.selected.format",
                    value: "%d of %d selected", comment: ""), enabled.count, ruleTemplates.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Button {
                    enabled = allSelected ? [] : Set(ruleTemplates.map(\.id))
                } label: {
                    Text(allSelected ? "picker.deselectAll" : "picker.selectAll")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .pointingHandCursor()
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button {
                    let names = Set(ruleTemplates.filter { enabled.contains($0.id) }.map(\.name))
                    onConfirm(role, names, recursive)
                } label: {
                    Text("picker.confirm")
                        .frame(minWidth: 100)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 540)
    }

    @ViewBuilder
    private func ruleRow(_ r: Rule) -> some View {
        let isOn = Binding<Bool>(
            get: { enabled.contains(r.id) },
            set: { v in
                if v { enabled.insert(r.id) } else { enabled.remove(r.id) }
            }
        )
        let descKey = BuiltInRules.descriptionKey(forBuiltInRuleNamed: r.name)
        let desc = descKey.flatMap { key -> String? in
            let s = NSLocalizedString(key, value: "", comment: "")
            return s.isEmpty ? nil : s
        }

        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: isOn)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: NSLocalizedString(r.name, value: r.name, comment: ""))
                    .font(.body)
                if let desc {
                    Text(verbatim: desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { isOn.wrappedValue.toggle() }
    }
}
