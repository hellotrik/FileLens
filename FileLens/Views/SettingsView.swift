/**
 * 飞砂走石
 *
 * 飞砂走石、风势狂暴；用于制造战场扰动与范围打击（设定）。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import SwiftUI
import AppKit
import KeyboardShortcuts

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .system: return "appearance.system"
        case .light:  return "appearance.light"
        case .dark:   return "appearance.dark"
        }
    }

    func apply() {
        switch self {
        case .system: NSApp.appearance = nil
        case .light:  NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:   NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

enum LanguagePreference: String, CaseIterable, Identifiable {
    case system = "system"
    case en = "en"
    case zhHans = "zh-Hans"

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .system: return "language.system"
        case .en:     return "language.en"
        case .zhHans: return "language.zhHans"
        }
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
            PreferencesSettingsView()
                .tabItem { Label("settings.preferences", systemImage: "slider.horizontal.3") }
            ShortcutsSettingsView()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            VideoSettingsTab()
                .tabItem { Label("Video", systemImage: "film") }
            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Preferences (索引 + 工作区默认)

private struct PreferencesSettingsView: View {
    @AppStorage("filelens.autoExpandInspector") private var autoExpandInspector: Bool = false
    @AppStorage("filelens.ignoreHidden") private var ignoreHidden: Bool = true
    @AppStorage("filelens.ignoreFolders") private var ignoreFolders: String =
        ".git, node_modules, .build, Pods, DerivedData, .next, .cache"
    @AppStorage("filelens.newArrivalsDays") private var newArrivalsDays: Int = 7
    @AppStorage("filelens.staleDays") private var staleDays: Int = 30

    var body: some View {
        Form {
            // 行为
            Section {
                Toggle("Auto-expand inspector when selecting a file", isOn: $autoExpandInspector)
            }

            // 索引(隐藏文件开关)
            Section {
                Toggle("settings.ignoreHidden", isOn: $ignoreHidden)
            } header: {
                Text("settings.section.indexing")
            }

            // 排除规则:用 TextEditor 而不是 TextField。Form.grouped 对带
            // `axis: .vertical` 的 TextField 一律做 LabeledContent,labelsHidden /
            // 空 title + prompt 都救不回来,placeholder 仍会被当成左侧 label 渲染。
            // TextEditor 不走 Form 的 TextField 特化路径,默认就是全宽内容。
            Section {
                TextEditor(text: $ignoreFolders)
                    .font(.callout.monospaced())
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 84, maxHeight: 140)
                    .padding(6)
                    .background(Color(nsColor: .textBackgroundColor),
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
                    )
            } header: {
                Text("settings.exclude.label")
                    .textCase(nil)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
            } footer: {
                Text("settings.exclude.hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 新建文件夹默认值。数字栏既支持 Stepper,也支持手动键入;
            // .controlSize(.small) 让 Stepper 上下箭头不再喧宾夺主。
            Section {
                LabeledContent("settings.newArrivalsDays.label") {
                    daysField(value: $newArrivalsDays, range: 1...90)
                }
                LabeledContent("settings.staleDays.label") {
                    daysField(value: $staleDays, range: 7...365)
                }
                Text("settings.thresholds.hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("settings.section.workspaceDefaults")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    /// "数字输入框 + 上下箭头 + 单位" 的复合输入。TextField 拿主导地位,
    /// Stepper 只做微调;onChange 把超出区间的手动输入夹回合法范围。
    @ViewBuilder
    private func daysField(value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 6) {
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 56)
                .onSubmit {
                    value.wrappedValue = min(max(value.wrappedValue, range.lowerBound),
                                             range.upperBound)
                }
            Stepper("", value: value, in: range)
                .labelsHidden()
                .controlSize(.small)
            Text("settings.days.unit")
                .foregroundStyle(.secondary)
        }
    }
}

private struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder(for: .openWindow) {
                Text("shortcut.openWindow.label")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct GeneralSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("filelens.appearance") private var appearanceRaw: String = AppearancePreference.system.rawValue
    @AppStorage("filelens.language") private var languageRaw: String = LanguagePreference.system.rawValue
    @State private var showingLanguageRestartAlert = false

    var body: some View {
        Form {
            // 外观和语言
            Section {
                Picker("Appearance", selection: $appearanceRaw) {
                    ForEach(AppearancePreference.allCases) { p in
                        Text(p.titleKey).tag(p.rawValue)
                    }
                }
                .onChange(of: appearanceRaw) { _, new in
                    (AppearancePreference(rawValue: new) ?? .system).apply()
                }
                Picker("Language", selection: $languageRaw) {
                    ForEach(LanguagePreference.allCases) { p in
                        Text(p.titleKey).tag(p.rawValue)
                    }
                }
                .onChange(of: languageRaw) { _, new in
                    if new == LanguagePreference.system.rawValue {
                        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                    } else {
                        UserDefaults.standard.set([new], forKey: "AppleLanguages")
                    }
                    showingLanguageRestartAlert = true
                }
            }

            // 配置导入导出
            Section {
                HStack {
                    Button("settings.exportConfig") {
                        do {
                            if let url = try ConfigIO.exportConfigToFile(container: modelContext.container) {
                                ToastCenter.shared.success(String(format:
                                    NSLocalizedString("config.exported.format",
                                        value: "Exported to %@",
                                        comment: ""), url.lastPathComponent))
                            }
                        } catch {
                            NSAlert(error: error).runModal()
                        }
                    }
                    .pointingHandCursor()
                    Button("settings.importConfig") {
                        do {
                            if let cfg = try ConfigIO.importConfigFromFile() {
                                let n = try ConfigIO.applyImport(cfg, container: modelContext.container)
                                if n > 0 {
                                    ToastCenter.shared.success(String(format:
                                        NSLocalizedString("settings.importConfig.result.format",
                                            value: "Imported %d new folder(s)",
                                            comment: ""), n))
                                } else {
                                    ToastCenter.shared.info(
                                        NSLocalizedString("config.imported.none",
                                            value: "Nothing to import (folders already exist)",
                                            comment: ""))
                                }
                            }
                        } catch {
                            NSAlert(error: error).runModal()
                        }
                    }
                    .pointingHandCursor()
                    Spacer()
                }
            } header: {
                Text("settings.section.config")
            }

            // 欢迎页
            Section {
                HStack {
                    Text("welcome.replay.label")
                    Spacer()
                    Button("welcome.replay.button") {
                        NotificationCenter.default.post(name: .showWelcome, object: nil)
                    }
                    .pointingHandCursor()
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .alert("language.restart.title", isPresented: $showingLanguageRestartAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Restart Now") { restartApp() }
        } message: {
            Text("language.restart.message")
        }
    }

    private func restartApp() {
        guard let url = Bundle.main.bundleURL as URL? else { return }
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", url.path]
        try? task.run()
        NSApp.terminate(nil)
    }
}

// MARK: - About

private struct AboutSettingsView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    var body: some View {
        VStack(spacing: 12) {
            if let img = NSImage(named: "AppIcon") {
                Image(nsImage: img)
                    .resizable().scaledToFit()
                    .frame(width: 96, height: 96)
            } else {
                Image(systemName: "app.fill")
                    .resizable().scaledToFit()
                    .frame(width: 96, height: 96)
                    .foregroundStyle(.tint)
            }
            Text("FileLens").font(.title2.bold())
            Text(verbatim: "v\(version) (\(build))")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Text("about.tagline")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }
}
