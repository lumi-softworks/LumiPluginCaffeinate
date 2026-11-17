import Testing
@testable import PluginCaffeinate

/// 断言释放与关屏失败必须如实上报（#650）。
///
/// Manager 原先无视 `IOPMAssertionRelease` 的返回码就翻转 `isActive`，
/// `pmset` 启动失败也被吞掉，工具层因此总是返回 ✅ 成功文案——Agent 会在
/// 「系统仍被阻止休眠 / 屏幕仍然亮着」的错误前提下继续行动。修复后：
///
/// - 任一断言释放失败 → `deactivate()` 返回 `false` 且会话保持活跃；
/// - `pmset` 启动失败 → `didLastDisplayTurnOffSucceed` 记录失败；
/// - 工具层据此返回显式失败文案，只有后条件真正成立才报成功。
@Suite("断言释放与关屏失败的如实报告（#650）")
@MainActor
struct CaffeinateReleaseFailureTests {

    @Test("释放失败时 deactivate 不得翻转状态，必须返回 false")
    func deactivateKeepsStateWhenReleaseFails() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        #expect(manager.activate(mode: .systemAndDisplay, duration: 0))
        #expect(manager.isActive)

        fake.releaseResult = 1
        #expect(
            manager.deactivate() == false,
            "断言仍在系统里生效时，deactivate 必须报告失败"
        )
        #expect(manager.isActive, "释放失败的会话必须保持活跃，否则状态与系统不符")
        #expect(manager.activeAction != nil)
        #expect(manager.startTime != nil)
        #expect(fake.releasedAssertionIDs.count == 2, "系统与显示器断言都应尝试释放")
    }

    @Test("释放恢复后再次 deactivate 才允许成功")
    func deactivateSucceedsAfterReleaseRecovers() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        #expect(manager.activate(mode: .systemAndDisplay, duration: 0))
        fake.releaseResult = 1
        #expect(manager.deactivate() == false)
        #expect(manager.isActive)

        fake.releaseResult = 0
        #expect(manager.deactivate())
        #expect(manager.isActive == false)
        #expect(manager.activeAction == nil)
    }

    @Test("关屏命令失败必须记录在 didLastDisplayTurnOffSucceed")
    func displayTurnOffFailureIsRecorded() {
        let fake = FakeCaffeinateEnvironment()
        fake.turnOffDisplayResult = false
        let manager = CaffeinateManager(environment: fake)

        manager.activateAndTurnOffDisplay(duration: 0)

        #expect(manager.isActive, "断言创建成功，防休眠会话仍然有效")
        #expect(fake.turnOffDisplayCount == 1)
        #expect(
            manager.didLastDisplayTurnOffSucceed == false,
            "pmset 启动失败必须可见，工具层不得宣称屏幕已关闭"
        )
    }

    @Test("关屏成功记录 true，deactivate 后复位为 nil")
    func displayTurnOffSuccessIsRecordedAndReset() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activateAndTurnOffDisplay(duration: 0)
        #expect(manager.didLastDisplayTurnOffSucceed == true)

        #expect(manager.deactivate())
        #expect(manager.didLastDisplayTurnOffSucceed == nil)

        // 重新激活（非关屏路径）也应复位标记。
        #expect(manager.activate(mode: .systemOnly, duration: 0))
        #expect(manager.didLastDisplayTurnOffSucceed == nil)
    }

    @Test("释放失败时 deactivate 工具必须返回失败文案")
    func deactivateToolReportsReleaseFailure() async throws {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)
        #expect(manager.activate(mode: .systemOnly, duration: 0))

        fake.releaseResult = 1
        let tool = CaffeinateDeactivateTool(manager: manager)
        let output = try await tool.execute(arguments: [:])

        #expect(output.contains("Failed"), "释放失败不得返回成功文案")
        #expect(!output.contains("restored to normal"))
    }

    @Test("释放成功时 deactivate 工具返回成功文案")
    func deactivateToolReportsSuccessAfterRelease() async throws {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)
        #expect(manager.activate(mode: .systemOnly, duration: 0))

        let tool = CaffeinateDeactivateTool(manager: manager)
        let output = try await tool.execute(arguments: [:])

        #expect(output.contains("Deactivated"))
        #expect(manager.isActive == false)
    }

    @Test("关屏命令失败时工具必须返回部分失败文案")
    func turnOffDisplayToolReportsLaunchFailure() async throws {
        let fake = FakeCaffeinateEnvironment()
        fake.turnOffDisplayResult = false
        let manager = CaffeinateManager(environment: fake)

        let tool = CaffeinateTurnOffDisplayTool(manager: manager)
        let output = try await tool.execute(arguments: [:])

        #expect(output.contains("failed"), "关屏命令失败不得宣称屏幕已关闭")
        #expect(manager.isActive, "断言已建立，防休眠仍然有效")
    }

    @Test("关屏命令成功时工具保留成功文案")
    func turnOffDisplayToolReportsSuccess() async throws {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        let tool = CaffeinateTurnOffDisplayTool(manager: manager)
        let output = try await tool.execute(arguments: [:])

        #expect(output.contains("Display Off"))
        #expect(manager.didLastDisplayTurnOffSucceed == true)
    }
}
