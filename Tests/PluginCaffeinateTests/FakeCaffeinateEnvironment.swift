import Foundation
import IOKit.pwr_mgt
@testable import PluginCaffeinate

/// 可控的 `CaffeinateEnvironment` 实现。
///
/// 记录电源断言、关屏、计时与持久化的调用，并允许测试注入成功 / 失败结果，
/// 从而在不触碰真实电源断言与 `pmset` 的前提下覆盖 `CaffeinateManager` 的分支。
@MainActor
final class FakeCaffeinateEnvironment: CaffeinateEnvironment {
    struct AssertionCall: Equatable {
        let kind: CaffeinateAssertionKind
        let reason: String
    }

    /// 创建过的电源断言调用记录。
    private(set) var createdAssertions: [AssertionCall] = []

    /// 被释放的断言 ID。
    private(set) var releasedAssertionIDs: [UInt32] = []

    /// 关闭显示器的次数。
    private(set) var turnOffDisplayCount = 0

    /// 安排计时器时的延迟。
    private(set) var scheduledDelays: [TimeInterval] = []

    /// 取消计时器的次数。
    private(set) var cancelledTimerCount = 0

    /// 持久化的自定义时长（分钟）。
    private(set) var storedDurations: [String: [Int]] = [:]

    /// 尚未触发的计时回调。
    private(set) var pendingTimerHandler: (@MainActor () -> Void)?

    /// 系统断言的返回结果。
    var systemAssertionResult = CaffeinateAssertionResult(code: kIOReturnSuccess, id: 101)

    /// 显示器断言的返回结果。
    var displayAssertionResult = CaffeinateAssertionResult(code: kIOReturnSuccess, id: 202)

    func createAssertion(
        kind: CaffeinateAssertionKind,
        reason: String
    ) -> CaffeinateAssertionResult {
        createdAssertions.append(AssertionCall(kind: kind, reason: reason))
        return kind == .system ? systemAssertionResult : displayAssertionResult
    }

    func releaseAssertion(id: UInt32) {
        releasedAssertionIDs.append(id)
    }

    func turnOffDisplay() {
        turnOffDisplayCount += 1
    }

    func scheduleTimer(after delay: TimeInterval, handler: @escaping @MainActor () -> Void) {
        scheduledDelays.append(delay)
        pendingTimerHandler = handler
    }

    func cancelScheduledTimer() {
        cancelledTimerCount += 1
        pendingTimerHandler = nil
    }

    func savedCustomDurations(forKey key: String) -> [Int]? {
        storedDurations[key]
    }

    func saveCustomDurations(_ minutes: [Int], forKey key: String) {
        storedDurations[key] = minutes
    }

    /// 模拟计时器到期。
    func fireScheduledTimer() {
        let handler = pendingTimerHandler
        pendingTimerHandler = nil
        handler?()
    }

    /// 预置已持久化的自定义时长，模拟「上次运行留下的数据」。
    func seedDurations(_ minutes: [Int], forKey key: String) {
        storedDurations[key] = minutes
    }
}
