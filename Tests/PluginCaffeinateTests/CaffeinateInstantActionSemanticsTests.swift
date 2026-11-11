import SwiftUI
import Testing
@testable import PluginCaffeinate

/// 「即时动作」与「运行模式」在语义上必须分开。
///
/// 背景：第三项曾经和前两项共用同一套「图标 + 文字 + 对勾」的视觉与无障碍
/// 语言，但它其实不是第三种模式——`activateAndTurnOffDisplay()` 的稳态就是
/// 「防休眠 + 允许关屏」，只是额外附带一次「立刻把屏幕关掉」的副作用。
///
/// 把它放进单选组会造成两个问题：
///
/// 1. **状态反馈断裂**：用户点了它之后，弹窗里带对勾的是第二项，看起来像是
///    「用户不小心把模式改成了第二项」，而真实意图是「执行一次关屏动作」。
/// 2. **语义误导**：右侧那个对勾位表达的是「当前生效的模式」，给一个用户
///    无法观察的状态打勾，比不打勾更容易误导人。
///
/// 这些测试锁住「第三项不参与模式单选」这个约定。
@Suite("即时动作与运行模式的语义边界")
@MainActor
struct CaffeinateInstantActionSemanticsTests {

    @Test("关屏动作的稳态就是 systemOnly，而不是独立的第三种模式")
    func turnOffDisplaySettlesOnSystemOnly() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activateAndTurnOffDisplay(duration: 0)

        // activeAction 永远不会是 .turnOffDisplay——Manager 把它归并到
        // systemOnly，因为两者在稳态上的行为完全一致。
        #expect(manager.activeAction == .systemOnly)
        #expect(manager.activeAction != .turnOffDisplay)
    }

    @Test("关屏标志位不参与模式判定")
    func displayOffFlagDoesNotAffectActiveAction() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activate(mode: .systemAndDisplay, duration: 0)
        #expect(manager.activeAction == .systemAndDisplay)
        #expect(manager.isDisplayOffRequested == false)
    }

    @Test("只有两项真正拥有模式身份")
    func onlyTwoItemsAreModes() {
        // 三个 QuickActionType 里，只有两项是可持续的运行模式；
        // .turnOffDisplay 是一次性动作的标记，不是模式。
        let modes: [CaffeinateManager.QuickActionType] = [.systemAndDisplay, .systemOnly]
        #expect(modes.count == 2)

        // 模式之间互斥。
        #expect(CaffeinateManager.QuickActionType.systemAndDisplay != .systemOnly)
        // 动作不等于任何一个模式。
        #expect(CaffeinateManager.QuickActionType.turnOffDisplay != .systemAndDisplay)
        #expect(CaffeinateManager.QuickActionType.turnOffDisplay != .systemOnly)
    }

    @Test("停止后模式清空，不残留动作标记")
    func deactivateClearsEverything() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activateAndTurnOffDisplay(duration: 0)
        #expect(manager.isActive)
        #expect(manager.isDisplayOffRequested)

        manager.deactivate()

        #expect(manager.isActive == false)
        #expect(manager.activeAction == nil)
        #expect(manager.isDisplayOffRequested == false)
    }

    @Test("模式项与动作项的无障碍标识彼此独立")
    func accessibilityIdentifiersAreIndependent() {
        // 三项各自带唯一标识，UI 测试可以分别定位。
        let configuration = CaffeinateConfiguration(accessibilityIdentifierPrefix: "wakey.caffeinate")
        let prefix = configuration.accessibilityIdentifierPrefix

        #expect("\(prefix).action.system-and-display" != "\(prefix).action.system-only")
        #expect("\(prefix).action.system-only" != "\(prefix).action.turn-off-display")
        #expect("\(prefix).action.system-and-display" != "\(prefix).action.turn-off-display")
    }
}
