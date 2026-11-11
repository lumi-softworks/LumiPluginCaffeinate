import Foundation
import IOKit.pwr_mgt
import Testing
@testable import PluginCaffeinate

typealias CaffeinateMode = CaffeinateManager.SleepMode
typealias CaffeinateDuration = CaffeinateManager.DurationOption
typealias CaffeinateAction = CaffeinateManager.QuickActionType

/// 自定义时长的 UserDefaults key，与 `CaffeinateManager` 内部保持一致。
private let customDurationsKey = "CaffeinateCustomDurations"

@Suite("CaffeinateManager 激活状态机")
@MainActor
struct CaffeinateManagerActivationTests {
    @Test("激活时同时创建系统与显示器断言")
    func activateCreatesBothAssertions() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activate(mode: .systemAndDisplay, duration: 0)

        #expect(manager.isActive)
        #expect(manager.activeAction == .systemAndDisplay)
        #expect(fake.createdAssertions.map(\.kind) == [.system, .display])
        #expect(manager.startTime != nil)
        #expect(manager.duration == 0)
        #expect(manager.selectedDuration == 0)
    }

    @Test("无参 activate 默认使用 systemAndDisplay 模式")
    func activateDefaultsToSystemAndDisplay() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activate()

        #expect(manager.activeAction == .systemAndDisplay)
        #expect(fake.createdAssertions.map(\.kind) == [.system, .display])
    }

    @Test("systemOnly 模式只创建系统断言")
    func systemOnlyCreatesSingleAssertion() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activate(mode: .systemOnly)

        #expect(manager.isActive)
        #expect(manager.activeAction == .systemOnly)
        #expect(fake.createdAssertions.map(\.kind) == [.system])
    }

    @Test("已激活时重复激活被忽略")
    func duplicateActivationIsIgnored() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activate(mode: .systemAndDisplay)
        manager.activate(mode: .systemOnly)

        #expect(fake.createdAssertions.count == 2)
        #expect(manager.activeAction == .systemAndDisplay)
    }

    @Test("带时长的激活会安排计时器")
    func timedActivationSchedulesTimer() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activate(mode: .systemAndDisplay, duration: 60)

        #expect(fake.scheduledDelays == [60])
    }

    @Test("永久激活不安排计时器")
    func indefiniteActivationDoesNotScheduleTimer() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activate(mode: .systemAndDisplay, duration: 0)

        #expect(fake.scheduledDelays.isEmpty)
    }

    @Test("计时器到期后自动停用并释放断言")
    func timerFiresAndDeactivates() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activate(mode: .systemAndDisplay, duration: 60)
        fake.fireScheduledTimer()

        #expect(manager.isActive == false)
        #expect(manager.activeAction == nil)
        #expect(fake.releasedAssertionIDs == [101, 202])
    }

    @Test("deactivate 释放断言并清空状态")
    func deactivateClearsState() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activate(mode: .systemAndDisplay, duration: 30)
        manager.deactivate()

        #expect(manager.isActive == false)
        #expect(manager.activeAction == nil)
        #expect(manager.startTime == nil)
        #expect(manager.duration == 0)
        #expect(fake.releasedAssertionIDs == [101, 202])
        #expect(fake.cancelledTimerCount == 1)
    }

    @Test("未激活时 deactivate 是空操作")
    func deactivateWhenInactiveIsNoop() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.deactivate()

        #expect(fake.releasedAssertionIDs.isEmpty)
        #expect(fake.cancelledTimerCount == 0)
        #expect(manager.isActive == false)
    }

    @Test("toggle 在激活与停用之间切换")
    func toggleSwitchesState() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.toggle()
        #expect(manager.isActive)

        manager.toggle()
        #expect(manager.isActive == false)
    }

    @Test("toggle 重新激活时沿用上次的模式")
    func toggleReusesPreviousMode() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activate(mode: .systemOnly)
        manager.deactivate()
        manager.toggle()

        #expect(manager.isActive)
        #expect(manager.activeAction == .systemOnly)
        #expect(fake.createdAssertions.map(\.kind) == [.system, .system])
    }

    @Test("activateAndTurnOffDisplay 以 systemOnly 模式激活并关闭显示器")
    func activateAndTurnOffDisplay() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activateAndTurnOffDisplay(duration: 30)

        #expect(manager.isActive)
        #expect(manager.activeAction == .systemOnly)
        #expect(manager.selectedDuration == 30)
        #expect(fake.createdAssertions.map(\.kind) == [.system])
        #expect(fake.turnOffDisplayCount == 1)
    }

    @Test("getActiveDuration 未激活时为 0")
    func activeDurationIsZeroWhenInactive() {
        let manager = CaffeinateManager(environment: FakeCaffeinateEnvironment())
        #expect(manager.getActiveDuration() == 0)
    }

    @Test("getActiveDuration 激活后为非负的经过时间")
    func activeDurationCountsUp() {
        let manager = CaffeinateManager(environment: FakeCaffeinateEnvironment())
        manager.activate(mode: .systemAndDisplay)
        let elapsed = manager.getActiveDuration()
        #expect(elapsed >= 0)
    }
}

@Suite("CaffeinateManager 断言失败处理")
@MainActor
struct CaffeinateManagerFailureTests {
    @Test("系统断言创建失败时不进入激活状态")
    func systemAssertionFailureKeepsInactive() {
        let fake = FakeCaffeinateEnvironment()
        fake.systemAssertionResult = CaffeinateAssertionResult(code: kIOReturnError, id: 0)
        let manager = CaffeinateManager(environment: fake)

        manager.activate(mode: .systemAndDisplay)

        #expect(manager.isActive == false)
        #expect(manager.activeAction == nil)
        #expect(manager.startTime == nil)
        #expect(manager.duration == 0)
    }

    @Test("系统断言失败时释放已创建的显示器断言")
    func systemAssertionFailureReleasesDisplayAssertion() {
        let fake = FakeCaffeinateEnvironment()
        fake.systemAssertionResult = CaffeinateAssertionResult(code: kIOReturnError, id: 0)
        let manager = CaffeinateManager(environment: fake)

        manager.activate(mode: .systemAndDisplay)

        #expect(fake.releasedAssertionIDs == [202])
    }

    @Test("显示器断言失败时释放系统断言")
    func displayAssertionFailureReleasesSystemAssertion() {
        let fake = FakeCaffeinateEnvironment()
        fake.displayAssertionResult = CaffeinateAssertionResult(code: kIOReturnError, id: 0)
        let manager = CaffeinateManager(environment: fake)

        manager.activate(mode: .systemAndDisplay)

        #expect(fake.releasedAssertionIDs == [101])
        #expect(manager.isActive == false)
    }

    @Test("断言失败时不安排计时器")
    func failureDoesNotScheduleTimer() {
        let fake = FakeCaffeinateEnvironment()
        fake.systemAssertionResult = CaffeinateAssertionResult(code: kIOReturnError, id: 0)
        let manager = CaffeinateManager(environment: fake)

        manager.activate(mode: .systemAndDisplay, duration: 60)

        #expect(fake.scheduledDelays.isEmpty)
    }

    @Test("activate 返回是否成功激活")
    func activateReportsSuccess() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        #expect(manager.activate(mode: .systemAndDisplay) == true)

        fake.systemAssertionResult = CaffeinateAssertionResult(code: kIOReturnError, id: 0)
        let failing = CaffeinateManager(environment: fake)
        #expect(failing.activate(mode: .systemOnly) == false)
    }

    @Test("断言失败时不关闭显示器，也不改写激活状态")
    func turnOffDisplaySkippedWhenAssertionFails() {
        let fake = FakeCaffeinateEnvironment()
        fake.systemAssertionResult = CaffeinateAssertionResult(code: kIOReturnNotPermitted, id: 0)
        let manager = CaffeinateManager(environment: fake)

        manager.activateAndTurnOffDisplay(duration: 300)

        #expect(fake.turnOffDisplayCount == 0)
        #expect(manager.isActive == false)
        #expect(manager.activeAction == nil)
        #expect(manager.selectedDuration == 0)
    }

    @Test("已有会话时关屏会先释放旧会话再重新激活")
    func turnOffDisplayReplacesRunningSession() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activate(mode: .systemAndDisplay, duration: 600)
        manager.activateAndTurnOffDisplay(duration: 1800)

        // 旧会话的断言已释放；新的会话只持有系统断言
        #expect(fake.releasedAssertionIDs == [101, 202])
        #expect(fake.createdAssertions.map(\.kind) == [.system, .display, .system])
        #expect(fake.turnOffDisplayCount == 1)
        #expect(manager.activeAction == .systemOnly)
        #expect(manager.selectedDuration == 1800)
        #expect(manager.duration == 1800)
    }
}

@Suite("CaffeinateManager 自定义时长")
@MainActor
struct CaffeinateManagerDurationTests {
    @Test("初始化时载入已持久化的自定义时长")
    func loadsPersistedCustomDurations() {
        let fake = FakeCaffeinateEnvironment()
        fake.seedDurations([15, 45], forKey: customDurationsKey)
        let manager = CaffeinateManager(environment: fake)

        #expect(manager.availableDurations.contains(.minutes(15)))
        #expect(manager.availableDurations.contains(.minutes(45)))
    }

    @Test("载入后按时间排序且永久在首位")
    func sortedWithIndefiniteFirst() {
        let fake = FakeCaffeinateEnvironment()
        fake.seedDurations([90], forKey: customDurationsKey)
        let manager = CaffeinateManager(environment: fake)

        let intervals = manager.availableDurations.map(\.timeInterval)
        #expect(intervals == intervals.sorted())
        #expect(manager.availableDurations.first == .indefinite)
    }

    @Test("无持久化记录时只有内置时长")
    func defaultsToCommonDurations() {
        let manager = CaffeinateManager(environment: FakeCaffeinateEnvironment())
        #expect(manager.availableDurations == CaffeinateManager.commonDurations)
    }

    @Test("addCustomDuration 追加并持久化")
    func addCustomDurationPersists() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.addCustomDuration(minutes: 45)

        #expect(manager.availableDurations.contains(.minutes(45)))
        let saved = fake.storedDurations[customDurationsKey]
        #expect(saved == [45])
    }

    @Test("addCustomDuration 不会重复添加相同时长")
    func addCustomDurationIsIdempotent() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.addCustomDuration(minutes: 45)
        manager.addCustomDuration(minutes: 45)

        let matches = manager.availableDurations.filter { $0 == .minutes(45) }
        #expect(matches.count == 1)
    }

    @Test("新增与预设等长的自定义时长不会并存")
    func addCustomDurationMatchingPresetDoesNotDuplicate() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        // 60 分钟与预设「1 小时」是同一时长
        manager.addCustomDuration(minutes: 60)

        let seconds = manager.availableDurations.map(\.timeInterval)
        #expect(Set(seconds).count == seconds.count, "同一时长不应出现两次，否则选择器会渲染出两个同时高亮的按钮")
        #expect(!manager.availableDurations.contains(.minutes(60)))
    }

    @Test("addCustomDuration 之后仍按时间排序")
    func addCustomDurationKeepsSorting() {
        let manager = CaffeinateManager(environment: FakeCaffeinateEnvironment())

        manager.addCustomDuration(minutes: 45)

        let intervals = manager.availableDurations.map(\.timeInterval)
        #expect(intervals == intervals.sorted())
    }

    @Test("removeDuration 不移除内置时长")
    func removeDurationKeepsCommonDurations() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.removeDuration(.minutes(30))

        #expect(manager.availableDurations.contains(.minutes(30)))
        #expect(fake.storedDurations[customDurationsKey] == nil)
    }

    @Test("removeDuration 移除自定义时长并持久化")
    func removeCustomDuration() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.addCustomDuration(minutes: 45)
        manager.removeDuration(.minutes(45))

        #expect(manager.availableDurations.contains(.minutes(45)) == false)
        let saved = fake.storedDurations[customDurationsKey]
        #expect(saved == [])
    }

    @Test("resetDurations 恢复内置时长并清空持久化记录")
    func resetDurations() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.addCustomDuration(minutes: 45)
        manager.resetDurations()

        #expect(manager.availableDurations == CaffeinateManager.commonDurations)
        let saved = fake.storedDurations[customDurationsKey]
        #expect(saved == [])
    }

    @Test("loadAvailableDurations 会重新读取持久化记录")
    func reloadPicksUpPersistedValues() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        fake.seedDurations([20], forKey: customDurationsKey)
        manager.loadAvailableDurations()

        #expect(manager.availableDurations.contains(.minutes(20)))
    }

    @Test("移除当前选中的自定义时长会回退到有效时长")
    func removingSelectedDurationFallsBack() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.addCustomDuration(minutes: 45)
        manager.selectedDuration = 45 * 60
        manager.removeDuration(.minutes(45))

        // 选中值必须仍存在于列表中，否则选择器没有任何按钮高亮
        #expect(manager.availableDurations.contains(where: { $0.timeInterval == manager.selectedDuration }))
        #expect(manager.selectedDuration == CaffeinateManager.commonDurations[0].timeInterval)
    }

    @Test("移除未选中的自定义时长不改变选中值")
    func removingOtherDurationKeepsSelection() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.addCustomDuration(minutes: 45)
        manager.addCustomDuration(minutes: 20)
        manager.selectedDuration = 20 * 60

        manager.removeDuration(.minutes(45))

        #expect(manager.selectedDuration == 20 * 60)
    }

    @Test("重置时长后选中值仍存在于列表中")
    func resetDurationsKeepsSelectionValid() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.addCustomDuration(minutes: 45)
        manager.selectedDuration = 45 * 60
        manager.resetDurations()

        #expect(manager.availableDurations.contains(where: { $0.timeInterval == manager.selectedDuration }))
        #expect(manager.selectedDuration == CaffeinateManager.commonDurations[0].timeInterval)
    }

    @Test("重置时长时若选中项仍存在则保持不变")
    func resetDurationsKeepsExistingSelection() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.addCustomDuration(minutes: 45)
        manager.selectedDuration = CaffeinateManager.commonDurations[2].timeInterval
        manager.resetDurations()

        #expect(manager.selectedDuration == CaffeinateManager.commonDurations[2].timeInterval)
    }
}

@Suite("CaffeinateManager 详细日志", .serialized)
@MainActor
struct CaffeinateManagerVerboseTests {
    @Test("开启详细日志不改变行为")
    func verboseLoggingKeepsBehaviour() {
        let previous = CaffeinateManager.verbose
        CaffeinateManager.verbose = true
        defer { CaffeinateManager.verbose = previous }

        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activate(mode: .systemAndDisplay, duration: 30)
        #expect(manager.isActive)
        #expect(fake.scheduledDelays == [30])

        // 重复激活走「已激活则忽略」分支
        manager.activate(mode: .systemAndDisplay, duration: 30)
        #expect(fake.createdAssertions.count == 2)

        manager.deactivate()
        #expect(manager.isActive == false)
    }
}

@Suite("CaffeinateManager 模式切换")
@MainActor
struct CaffeinateManagerSwitchActionTests {
    @Test("运行时切换到另一模式会先释放旧断言再激活新模式")
    func switchActionReplacesRunningSession() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activate(mode: .systemAndDisplay, duration: 0)
        manager.switchAction(.systemOnly)

        // 旧会话的断言被释放，新的会话只创建系统断言
        #expect(fake.releasedAssertionIDs == [101, 202])
        #expect(fake.createdAssertions.map(\.kind) == [.system, .display, .system])
        #expect(manager.isActive)
        #expect(manager.activeAction == .systemOnly)
    }

    @Test("运行时切换模式会取消旧会话的计时器")
    func switchActionCancelsOldTimer() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activate(mode: .systemAndDisplay, duration: 60)
        manager.switchAction(.systemOnly)

        #expect(fake.cancelledTimerCount == 1)
        #expect(fake.scheduledDelays == [60, 60])
    }

    @Test("未运行时切换模式直接激活，不释放任何断言")
    func switchActionWithoutRunningSession() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.switchAction(.systemAndDisplay)

        #expect(fake.releasedAssertionIDs.isEmpty)
        #expect(fake.createdAssertions.map(\.kind) == [.system, .display])
        #expect(manager.activeAction == .systemAndDisplay)
    }

    @Test("切换到 turnOffDisplay 会关闭显示器")
    func switchActionToTurnOffDisplay() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activate(mode: .systemAndDisplay, duration: 0)
        manager.switchAction(.turnOffDisplay)

        #expect(fake.turnOffDisplayCount == 1)
        #expect(manager.activeAction == .systemOnly)
        #expect(manager.isActive)
    }

    @Test("切换模式沿用当前选择的时长")
    func switchActionKeepsSelectedDuration() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.selectedDuration = 1800
        manager.activate(mode: .systemAndDisplay, duration: 1800)
        manager.switchAction(.systemOnly)

        #expect(manager.selectedDuration == 1800)
        #expect(manager.duration == 1800)
    }
}
