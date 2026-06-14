/**
 * 导出元阳
 *
 * 导出敌人元阳（阳气/生机）；用于削弱对手与夺取元气。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import SwiftUI

// MARK: - Focused-value plumbing

private struct AddFolderActionKey: FocusedValueKey {
    typealias Value = () -> Void
}
private struct NewRuleActionKey: FocusedValueKey {
    typealias Value = () -> Void
}
private struct ActiveWorkspaceNameKey: FocusedValueKey {
    typealias Value = String
}
private struct VideoToolsActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var addFolderAction: (() -> Void)? {
        get { self[AddFolderActionKey.self] }
        set { self[AddFolderActionKey.self] = newValue }
    }
    var newRuleAction: (() -> Void)? {
        get { self[NewRuleActionKey.self] }
        set { self[NewRuleActionKey.self] = newValue }
    }
    /// Name of the workspace currently shown in the active window. nil means
    /// no workspace is selected — workspace-scoped commands (e.g. New Rule)
    /// should disable.
    var activeWorkspaceName: String? {
        get { self[ActiveWorkspaceNameKey.self] }
        set { self[ActiveWorkspaceNameKey.self] = newValue }
    }
    var videoToolsAction: (() -> Void)? {
        get { self[VideoToolsActionKey.self] }
        set { self[VideoToolsActionKey.self] = newValue }
    }
}

// MARK: - Menu commands

struct FileLensCommands: Commands {
    @FocusedValue(\.addFolderAction) private var addFolder
    @FocusedValue(\.newRuleAction) private var newRule
    @FocusedValue(\.videoToolsAction) private var videoTools
    @FocusedValue(\.activeWorkspaceName) private var workspaceName
    /// Mirrored in SidebarView so the two stay in sync — UserDefaults is
    /// the single source of truth.
    @AppStorage("filelens.showEmptyRules") private var showEmptyRules: Bool = true

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button {
                addFolder?()
            } label: {
                Text("Add Folder…")
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .disabled(addFolder == nil)

            // New Rule's label includes the workspace it'll be created in,
            // so users can see at a glance where ⌘N will land. Disabled
            // when no workspace is active, since rules can't exist
            // detached from a workspace.
            Button {
                newRule?()
            } label: {
                if let name = workspaceName {
                    Text(verbatim: String(format:
                        NSLocalizedString("menu.newRuleIn.format",
                            value: "New Rule in “%@”…",
                            comment: ""), name))
                } else {
                    Text("New Rule…")
                }
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(newRule == nil || workspaceName == nil)

            Button {
                videoTools?()
            } label: {
                Text("Activity Log")
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            .disabled(videoTools == nil)
        }

        // 在 View 菜单 sidebar 项之后插一个 "Show Empty Rules" 开关。
        // 必须包在 Section 里 —— 否则它会跟系统的 "Enter Full Screen"
        // (后者带 image 在 leading 列)挤在同一 NSMenu state-column 段
        // 里,checkmark 列宽和 image 列宽不一致,文本起始位置就对不齐。
        // Section 等价于强制插一个 NSMenuItem.separator,让我们的开关
        // 单独成段,自己的 state-column 自己算对齐,跟系统项互不干扰。
        CommandGroup(after: .sidebar) {
            Section {
                Toggle(isOn: $showEmptyRules) {
                    Text("Show Empty Rules")
                }
            }
        }
    }
}
