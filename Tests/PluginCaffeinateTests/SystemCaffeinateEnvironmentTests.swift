import Foundation
import IOKit.pwr_mgt
import Testing
@testable import PluginCaffeinate

/// `SystemCaffeinateEnvironment` 是生产环境实现，直接接触 IOKit、
/// `Timer` 与 `UserDefaults.standard`。
///
/// 这里只验证不会产生破坏性副作用的部分：
/// - 持久化使用独立的 key 前缀，测试结束后清理；
/// - 电源断言创建后立即释放；
/// - `turnOffDisplay()` 会真的熄灭开发机屏幕，因此不在单测中触发。
@MainActor
struct SystemCaffeinateEnvironmentTests {
    private let customKey = "PluginCaffeinateTests.customDurations"

    private func makeClean() -> SystemCaffeinateEnvironment {
        UserDefaults.standard.removeObject(forKey: customKey)
        return SystemCaffeinateEnvironment()
    }

    @Test("无记录时读取自定义时长返回 nil")
    func missingDurationsReturnNil() {
        let env = makeClean()
        #expect(env.savedCustomDurations(forKey: customKey) == nil)
    }

    @Test("写入的自定义时长可被读回")
    func durationsRoundTrip() {
        let env = makeClean()

        env.saveCustomDurations([15, 45], forKey: customKey)
        #expect(env.savedCustomDurations(forKey: customKey) == [15, 45])

        env.saveCustomDurations([], forKey: customKey)
        #expect(env.savedCustomDurations(forKey: customKey) == [])

        UserDefaults.standard.removeObject(forKey: customKey)
    }

    @Test("取消计时器后回调不会触发")
    func cancelStopsTimer() async {
        let env = makeClean()
        var fired = false
        env.scheduleTimer(after: 0.05) { fired = true }
        env.cancelScheduledTimer()

        try? await Task.sleep(for: .milliseconds(200))
        #expect(fired == false)
    }

    @Test("计时器到期后回调在主线程触发")
    func timerFiresOnMainActor() async {
        let env = makeClean()
        var fired = false
        env.scheduleTimer(after: 0.05) { fired = true }

        try? await Task.sleep(for: .milliseconds(300))
        #expect(fired)
    }

    @Test("电源断言创建成功时返回非零 id，失败时返回 0")
    func assertionResultCarriesID() {
        let env = makeClean()
        let result = env.createAssertion(kind: .system, reason: "PluginCaffeinateTests")

        // IOKit 成功时分配非零断言 id，失败时保持为 0。
        if result.isSuccess {
            #expect(result.id != 0)
        } else {
            #expect(result.id == 0)
        }

        env.releaseAssertion(id: result.id)
    }

    @Test("释放断言 id 0 是安全的空操作")
    func releasingZeroIsSafe() {
        let env = makeClean()
        env.releaseAssertion(id: 0)
    }
}
