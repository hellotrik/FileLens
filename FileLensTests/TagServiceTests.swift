/**
 * 墨瑶（其一）
 *
 * 八十八角真阳楼，招灾仙蛊炼不休。
 * 为助情郎登九转，愿以残躯化劫流。
 *
 * @remarks 来源：蛊真人 · 《蛊真人》全诗词整理（完整版） · kairos-dao-header
 */
import XCTest
import SwiftData
@testable import FileLens

final class TagServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([FileNode.self, FileTag.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
    }

    private func makeFile(name: String = "a.txt") -> FileNode {
        FileNode(
            workspaceID: UUID(),
            relativePath: name,
            name: name,
            ext: "txt",
            size: 100,
            dateAdded: .now,
            dateModified: .now,
            kind: "text"
        )
    }

    func test_normalize_rejects_empty() {
        XCTAssertNil(TagService.normalizeManualTagName("   "))
    }

    func test_addManualTag_deduplicates() throws {
        let file = makeFile()
        context.insert(file)
        XCTAssertEqual(TagService.addManualTag(name: "Important", to: [file], context: context), "Important")
        XCTAssertEqual(TagService.addManualTag(name: "Important", to: [file], context: context), "Important")
        XCTAssertEqual(file.tags.filter { $0.source == "manual" }.count, 1)
    }

    func test_removeManualTags_by_name() throws {
        let file = makeFile()
        context.insert(file)
        _ = TagService.addManualTag(name: "A", to: [file], context: context)
        _ = TagService.addManualTag(name: "B", to: [file], context: context)
        TagService.removeManualTags(from: [file], names: ["A"], context: context)
        XCTAssertEqual(file.tags.map(\.name), ["B"])
    }

    func test_removeAllTags_clears_everything() throws {
        let file = makeFile()
        context.insert(file)
        let ruleTag = FileTag(name: "PDF", source: "rule", ruleID: UUID())
        ruleTag.file = file
        context.insert(ruleTag)
        file.tags = [ruleTag]
        _ = TagService.addManualTag(name: "Star", to: [file], context: context)

        TagService.removeAllTags(from: [file], context: context)
        XCTAssertTrue(file.tags.isEmpty)
        XCTAssertNil(file.rulesEvaluatedAt)
    }

    func test_applyRuleTags_pins_without_conditions() throws {
        let file = makeFile()
        context.insert(file)
        let rule = Rule(name: "Large", color: "#FF0000", enabled: true, priority: 10)
        rule.conditions.append(Condition(field: "size", op: "gt", value: "999999999"))
        context.insert(rule)

        let added = TagService.applyRuleTags([rule], to: [file], context: context)
        XCTAssertEqual(added, 1)
        XCTAssertEqual(file.tags.count, 1)
        XCTAssertEqual(file.tags.first?.source, "pinned")
        XCTAssertEqual(file.tags.first?.ruleID, rule.id)
    }

    func test_clearRuleTags_keeps_manual() throws {
        let file = makeFile()
        context.insert(file)
        let ruleID = UUID()
        let ruleTag = FileTag(name: "PDF", source: "rule", ruleID: ruleID)
        ruleTag.file = file
        context.insert(ruleTag)
        file.tags = [ruleTag]
        _ = TagService.addManualTag(name: "Legacy", to: [file], context: context)

        TagService.clearRuleTags(from: [file], context: context)
        XCTAssertEqual(file.tags.map(\.name), ["Legacy"])
    }

    func test_removeRuleTags_by_name() throws {
        let file = makeFile()
        context.insert(file)
        let ruleTag = FileTag(name: "PDF", source: "rule", ruleID: UUID())
        ruleTag.file = file
        context.insert(ruleTag)
        file.tags = [ruleTag]
        _ = TagService.addManualTag(name: "Legacy", to: [file], context: context)

        TagService.removeRuleTags(from: [file], names: ["PDF"], context: context)
        XCTAssertEqual(file.tags.map(\.name), ["Legacy"])
    }

    func test_computeStatistics_counts_manual_and_uncategorized() throws {
        let a = makeFile(name: "a.txt")
        let b = makeFile(name: "b.txt")
        context.insert(a)
        context.insert(b)

        let ruleTag = FileTag(name: "PDF", source: "rule", ruleID: UUID())
        ruleTag.file = a
        context.insert(ruleTag)
        a.tags = [ruleTag]

        _ = TagService.addManualTag(name: "Star", to: [b], context: context)

        let stats = TagService.computeStatistics(from: [a, b])
        XCTAssertEqual(stats.uncategorized, 1)
        XCTAssertEqual(stats.manualCounts["Star"], 1)
        XCTAssertEqual(stats.ruleCounts.count, 1)
    }
}
