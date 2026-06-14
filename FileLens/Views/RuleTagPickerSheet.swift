/**
 * 墨瑶（其一）
 *
 * 八十八角真阳楼，招灾仙蛊炼不休。
 * 为助情郎登九转，愿以残躯化劫流。
 *
 * @remarks 来源：蛊真人 · 《蛊真人》全诗词整理（完整版） · kairos-dao-header
 */
import SwiftUI

/// 给所选文件批量打上规则标签（pinned，不依赖条件匹配）。
struct RuleTagPickerSheet: View {
    let files: [FileNode]
    let rules: [Rule]
    let onApply: ([Rule]) -> Void
    let onCancel: () -> Void

    @State private var selectedRuleIDs: Set<UUID> = []

    private var fileCount: Int { files.count }
    private var sortedRules: [Rule] {
        rules.sorted { $0.priority < $1.priority }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("tag.rulePicker.title")
                .font(.headline)
            Text(verbatim: String(format:
                NSLocalizedString("tag.rulePicker.subtitle.format",
                    value: "Apply rule tags to %lld selected item(s).",
                    comment: ""),
                Int64(fileCount)))
                .font(.caption)
                .foregroundStyle(.secondary)

            if sortedRules.isEmpty {
                Text("tag.rulePicker.noRules")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(sortedRules) { rule in
                            ruleRow(rule)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                Button("Apply") { onApply(selectedRules) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedRuleIDs.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    @ViewBuilder
    private func ruleRow(_ rule: Rule) -> some View {
        let isOn = selectedRuleIDs.contains(rule.id)
        Button {
            if isOn { selectedRuleIDs.remove(rule.id) }
            else { selectedRuleIDs.insert(rule.id) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? Color.accentColor : .secondary)
                Circle()
                    .fill(Color(hexString: rule.color))
                    .frame(width: 10, height: 10)
                Text(verbatim: TagDisplay.localizedName(rule.name))
                    .foregroundStyle(rule.enabled ? .primary : .secondary)
                Spacer()
                if !rule.enabled {
                    Text("Disabled")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }

    private var selectedRules: [Rule] {
        sortedRules.filter { selectedRuleIDs.contains($0.id) }
    }
}
