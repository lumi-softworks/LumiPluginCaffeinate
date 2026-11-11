import Foundation
import IOKit.pwr_mgt
import OSLog

/// 防休眠所需的系统能力抽象。
///
/// `CaffeinateManager` 原本直接调用 IOKit 创建电源断言、通过 `pmset`
/// 关闭显示器、用 `Timer` 计时并读写 `UserDefaults`。其中「立刻关闭显示器」
/// 在测试进程中会真的熄灭开发机的屏幕，电源断言创建失败等分支也无法稳定
/// 复现，因此把这些副作用收敛到本协议之后：
///
/// - 生产环境由 `SystemCaffeinateEnvironment` 提供真实实现，行为与抽象前完全一致；
/// - 测试可注入可控实现，精确模拟断言成功 / 失败、计时器触发等场景。
@MainActor
protocol CaffeinateEnvironment: AnyObject {
    /// 创建电源断言。
    func createAssertion(
        kind: CaffeinateAssertionKind,
        reason: String
    ) -> CaffeinateAssertionResult

    /// 释放电源断言。
    func releaseAssertion(id: UInt32)

    /// 立即关闭显示器。
    func turnOffDisplay()

    /// 在指定延迟后触发回调（回调运行在主线程）。
    func scheduleTimer(after delay: TimeInterval, handler: @escaping @MainActor () -> Void)

    /// 取消尚未触发的计时。
    func cancelScheduledTimer()

    /// 读取已持久化的自定义时长（分钟）；无记录时返回 nil。
    func savedCustomDurations(forKey key: String) -> [Int]?

    /// 写入自定义时长（分钟）。
    func saveCustomDurations(_ minutes: [Int], forKey key: String)
}

/// 电源断言类型。
enum CaffeinateAssertionKind: Equatable {
    /// 阻止系统因空闲而休眠。
    case system
    /// 阻止显示器因空闲而休眠。
    case display
}

/// 电源断言创建结果。
struct CaffeinateAssertionResult {
    /// IOKit 返回码。
    let code: IOReturn

    /// 断言 ID；创建失败时为 0。
    let id: UInt32

    init(code: IOReturn, id: UInt32 = 0) {
        self.code = code
        self.id = id
    }

    /// 是否创建成功。
    var isSuccess: Bool { code == kIOReturnSuccess }
}

/// 生产环境实现：直接使用系统 API，行为与抽象前一致。
@MainActor
final class SystemCaffeinateEnvironment: CaffeinateEnvironment {
    private var timer: Timer?

    func createAssertion(
        kind: CaffeinateAssertionKind,
        reason: String
    ) -> CaffeinateAssertionResult {
        var assertionID: IOPMAssertionID = 0
        let type: CFString = kind == .system
            ? kIOPMAssertionTypePreventUserIdleSystemSleep as CFString
            : kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString
        let code = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        return CaffeinateAssertionResult(code: code, id: assertionID)
    }

    func releaseAssertion(id: UInt32) {
        IOPMAssertionRelease(IOPMAssertionID(id))
    }

    func turnOffDisplay() {
        let task = Process()
        task.launchPath = "/usr/bin/pmset"
        task.arguments = ["displaysleepnow"]
        do {
            try task.run()
        } catch {
            os_log(.error, "Failed to turn off display: \(error.localizedDescription)")
        }
    }

    func scheduleTimer(after delay: TimeInterval, handler: @escaping @MainActor () -> Void) {
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            Task { @MainActor in
                handler()
            }
        }
    }

    func cancelScheduledTimer() {
        timer?.invalidate()
        timer = nil
    }

    func savedCustomDurations(forKey key: String) -> [Int]? {
        UserDefaults.standard.array(forKey: key) as? [Int]
    }

    func saveCustomDurations(_ minutes: [Int], forKey key: String) {
        UserDefaults.standard.set(minutes, forKey: key)
    }
}
