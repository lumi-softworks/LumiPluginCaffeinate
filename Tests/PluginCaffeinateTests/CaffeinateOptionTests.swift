import Foundation
import Testing
@testable import PluginCaffeinate

typealias DurationOption = CaffeinateManager.DurationOption
typealias SleepMode = CaffeinateManager.SleepMode
typealias QuickActionType = CaffeinateManager.QuickActionType

/// `CaffeinateManager` 通过 IOKit 创建真实电源断言、并直接调用 `pmset`
/// 与 UserDefaults，不适合在单测中实例化。
/// 本文件覆盖其枚举与预设表这些纯值逻辑层。
@Suite("SleepMode")
@MainActor
struct SleepModeTests {
    @Test("两种模式均可枚举")
    func hasTwoModes() {
        #expect(SleepMode.allCases.count == 2)
        #expect(SleepMode.allCases.contains(.systemOnly))
        #expect(SleepMode.allCases.contains(.systemAndDisplay))
    }

    @Test("rawValue 可往返")
    func rawValuesRoundTrip() {
        for mode in SleepMode.allCases {
            #expect(SleepMode(rawValue: mode.rawValue) == mode)
        }
    }

    @Test("rawValue 使用 snake_case")
    func usesSnakeCaseRawValues() {
        #expect(SleepMode.systemOnly.rawValue == "systemOnly")
        #expect(SleepMode.systemAndDisplay.rawValue == "systemAndDisplay")
    }

    @Test("displayName 可解析且两模式不同")
    func displayNamesAreDistinct() {
        let names = SleepMode.allCases.map(\.displayName)
        #expect(names.allSatisfy { !$0.isEmpty })
        #expect(Set(names).count == 2)
    }
}

@Suite("DurationOption 语义")
struct DurationOptionTests {
    @Test("indefinite 对应 0 秒（永久）")
    func indefiniteIsZero() {
        // activate 中以 duration == 0 表示不设定时器
        #expect(DurationOption.indefinite.timeInterval == 0)
    }

    @Test("minutes 换算为秒")
    func minutesToSeconds() {
        #expect(DurationOption.minutes(30).timeInterval == 1800)
        #expect(DurationOption.minutes(45).timeInterval == 2700)
    }

    @Test("hours 换算为秒")
    func hoursToSeconds() {
        #expect(DurationOption.hours(1).timeInterval == 3600)
        #expect(DurationOption.hours(5).timeInterval == 18000)
    }

    @Test("相等性基于 case 与数值")
    func equalityIsValueBased() {
        #expect(DurationOption.minutes(30) == .minutes(30))
        #expect(DurationOption.indefinite != .minutes(0))
    }

    @Test("可存入 Set 去重")
    func deduplicatesInSet() {
        let set: Set<DurationOption> = [
            .indefinite,
            .indefinite,
            .hours(1),
        ]
        #expect(set.count == 2)
    }

    @Test("displayName 均可解析")
    func displayNamesAreResolvable() {
        let options: [DurationOption] = [.indefinite, .minutes(30), .hours(2)]
        #expect(options.allSatisfy { !$0.displayName.isEmpty })
    }

    @Test("indefinite 与 minutes(0) 是不同选项")
    func indefiniteDiffersFromZeroMinutes() {
        // 两者 timeInterval 同为 0，但语义不同（永久 vs 0 分钟）
        #expect(DurationOption.indefinite.timeInterval == DurationOption.minutes(0).timeInterval)
        #expect(DurationOption.indefinite != .minutes(0))
    }
}

@Suite("commonDurations 预设")
@MainActor
struct CommonDurationsTests {
    @Test("包含 5 个预设时长")
    func hasFivePresets() {
        #expect(CaffeinateManager.commonDurations.count == 5)
    }

    @Test("首个预设为永久")
    func startsWithIndefinite() {
        #expect(CaffeinateManager.commonDurations.first == .indefinite)
    }

    @Test("预设按时间递增排列")
    func isSortedAscending() {
        let values = CaffeinateManager.commonDurations.map(\.timeInterval)
        #expect(values == values.sorted())
    }

    @Test("预设互不重复")
    func hasNoDuplicates() {
        let durations = CaffeinateManager.commonDurations
        #expect(Set(durations).count == durations.count)
    }

    @Test("覆盖分钟与小时两种单位")
    func coversBothUnits() {
        let durations = CaffeinateManager.commonDurations
        #expect(durations.contains(.minutes(30)))
        #expect(durations.contains(.hours(1)))
        #expect(durations.contains(.hours(5)))
    }
}

@Suite("QuickActionType")
struct QuickActionTypeTests {
    @Test("三种快捷操作均可区分")
    func hasThreeDistinctTypes() {
        #expect(QuickActionType.systemAndDisplay != .systemOnly)
        #expect(QuickActionType.systemOnly != .turnOffDisplay)
        #expect(QuickActionType.systemAndDisplay != .turnOffDisplay)
    }

    @Test("相等性基于 case")
    func equalityIsCaseBased() {
        #expect(QuickActionType.systemOnly == .systemOnly)
        #expect(QuickActionType.turnOffDisplay == .turnOffDisplay)
    }
}
