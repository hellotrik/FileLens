/**
 * 搬运术
 *
 * 隔空取物、移形换影；用于搬运物体与改变位置（设定）。
 *
 * @remarks 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
 */
import Foundation

struct PipelineOperation: Identifiable {
    let id = UUID()

    enum Kind {
        case rename(workspaceID: UUID, items: [VideoRenameItem])
        case organize(workspaceID: UUID, fileCount: Int)
    }

    let kind: Kind
}
