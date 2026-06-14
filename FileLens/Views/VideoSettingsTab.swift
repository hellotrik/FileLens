/**
 * 隔垣洞见
 *
 * 隔垣洞见、彻视洞达十方；用于洞察隐匿、观察气运与看破虚妄（天眼通设定）。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import SwiftUI

/// 设置 → Video：全局依赖与管道向导（路径在 Workspace 管道 Tab）。
struct VideoSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @State private var ffprobeOK = VideoProbeService.isAvailable()
    @State private var importStatus: String?
    @State private var showSetup = false

    var body: some View {
        Form {
            Section {
                if !ffprobeOK {
                    Label("Install ffmpeg for ffprobe (brew install ffmpeg)",
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                } else {
                    Label("ffprobe available", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            } footer: {
                Text("video.settings.ffprobe.hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("video.settings.pipeline") {
                Text("video.settings.pipeline.hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("video.settings.setup") {
                    showSetup = true
                }
                Button("Show Activity Log") {
                    NotificationCenter.default.post(name: .toggleActivityLog, object: nil)
                }
            }

            if VideoConfigImporter.legacyConfigExists() {
                Section("video.settings.legacy") {
                    Button("Import from video-tools config.toml") {
                        importLegacy()
                    }
                    if let importStatus {
                        Text(verbatim: importStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showSetup) {
            VideoSetupSheet {
                NotificationCenter.default.post(name: .videoSetupCompleted, object: nil)
            }
        }
    }

    private func importLegacy() {
        do {
            if let msg = try VideoConfigImporter.importToCatalog(context: modelContext, force: true) {
                importStatus = msg
                ffprobeOK = VideoProbeService.isAvailable()
                ActivityLog.shared.append(msg)
                ActivityLog.shared.isExpanded = true
                NotificationCenter.default.post(name: .videoSetupCompleted, object: nil)
            }
        } catch {
            importStatus = error.localizedDescription
        }
    }
}

extension Notification.Name {
    static let toggleActivityLog = Notification.Name("filelens.toggleActivityLog")
    static let videoSetupCompleted = Notification.Name("filelens.videoSetupCompleted")
}
