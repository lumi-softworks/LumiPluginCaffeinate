import Foundation
import IOKit.pwr_mgt
import LumiLoggingKit
import Observation
import OSLog
import SwiftUI

/// Anti-sleep manager: responsible for managing system power states
@MainActor
@Observable
class CaffeinateManager: SuperLog {
    nonisolated static let emoji = "🍽️"
    /// 详细日志开关。生产环境保持关闭，测试中可临时打开以覆盖日志分支。
    static var verbose: Bool = false

    // MARK: - Singleton

    static let shared = CaffeinateManager()

    // MARK: - Properties

    /// Whether anti-sleep is currently active
    private(set) var isActive: Bool = false

    /// Currently active action type, nil if not active
    private(set) var activeAction: QuickActionType?

    /// Duration selected by the user (seconds), used for next activation or updating current activation
    var selectedDuration: TimeInterval = 0

    /// Activation start time
    private(set) var startTime: Date?

    /// Preset duration (seconds), 0 for indefinite
    private(set) var duration: TimeInterval = 0

    private(set) var mode: SleepMode = .systemAndDisplay

    /// IOKit assertion ID
    private var assertionID: UInt32 = 0

    private var displayAssertionID: UInt32 = 0

    /// 电源断言 / 关屏 / 计时 / 持久化的来源。
    /// 生产环境为系统实现，测试可注入可控实现。
    private let environment: any CaffeinateEnvironment

    // MARK: - Custom Intervals Support

    private let customDurationsKey = "CaffeinateCustomDurations"

    /// Available durations (including defaults and custom ones)
    private(set) var availableDurations: [DurationOption] = []

    // MARK: - Initialization

    init(environment: any CaffeinateEnvironment = SystemCaffeinateEnvironment()) {
        self.environment = environment
        if Self.verbose {
            os_log("\(self.t)CaffeinateManager initialized")
        }
        loadAvailableDurations()
    }

    // MARK: - Public Methods

    /// 激活防休眠模式
    /// - Parameter duration: 持续时间（秒），0 表示永久
    @discardableResult
    func activate(duration: TimeInterval = 0) -> Bool {
        activate(mode: .systemAndDisplay, duration: duration)
    }

    /// 激活防休眠模式并立即关闭显示器
    ///
    /// 仅在防休眠确实激活成功后才关闭显示器——断言创建失败时不应让用户
    /// 看到「屏幕黑了但系统仍会休眠」的状态。
    ///
    /// - Parameter duration: 持续时间（秒），0 表示永久
    func activateAndTurnOffDisplay(duration: TimeInterval = 0) {
        // 若已有会话在运行，先停掉旧的：否则 activate 会因 isActive 直接返回，
        // 且旧的显示器断言会继续阻止屏幕熄灭。
        if isActive {
            deactivate()
        }

        guard activate(mode: .systemOnly, duration: duration) else {
            os_log(.error, "\(self.t)Cannot turn off display: anti-sleep assertion failed")
            return
        }

        // activeAction / selectedDuration 已由 activate 成功路径写入。
        turnOffDisplay()
    }

    /// 切换到指定的防休眠动作。
    ///
    /// 若已有会话在运行，先释放旧的电源断言再激活新的模式——否则
    /// `activate(mode:duration:)` 会因 `isActive` 为真直接返回，新模式不生效。
    ///
    /// - Parameter action: 目标动作
    func switchAction(_ action: QuickActionType) {
        if isActive {
            deactivate()
        }

        switch action {
        case .systemAndDisplay:
            activate(mode: .systemAndDisplay, duration: selectedDuration)
        case .systemOnly:
            activate(mode: .systemOnly, duration: selectedDuration)
        case .turnOffDisplay:
            activateAndTurnOffDisplay(duration: selectedDuration)
        }
    }

    /// 立即关闭显示器
    private func turnOffDisplay() {
        environment.turnOffDisplay()
    }

    /// 激活指定的防休眠模式
    /// - Parameters:
    ///   - mode: 休眠模式（仅系统或系统与显示器）
    ///   - duration: 持续时间（秒），0 表示永久
    /// - Returns: 是否成功激活（断言创建成功且会话已进入运行状态）
    @discardableResult
    func activate(mode: SleepMode, duration: TimeInterval = 0) -> Bool {
        guard !isActive else {
            if Self.verbose {
                os_log("\(self.t)Anti-sleep already active, ignoring duplicate request")
            }
            return false
        }

        self.mode = mode
        let reason = String(localized: "Anti-sleep mode enabled via Wakey", table: "Caffeinate", bundle: .module, comment: "Reason shown in system power assertions when anti-sleep is active") as NSString

        let systemResult = environment.createAssertion(kind: .system, reason: reason as String)
        assertionID = systemResult.id

        var displayResult = CaffeinateAssertionResult(code: kIOReturnSuccess)
        if mode == .systemAndDisplay {
            displayResult = environment.createAssertion(kind: .display, reason: reason as String)
            displayAssertionID = displayResult.id
        } else {
            displayAssertionID = 0
        }

        if systemResult.isSuccess && displayResult.isSuccess {
            isActive = true
            activeAction = (mode == .systemAndDisplay) ? .systemAndDisplay : .systemOnly
            startTime = Date()
            self.duration = duration
            self.selectedDuration = duration

            if Self.verbose {
                os_log("\(self.t)Caffeinate activated successfully with duration: \(duration)s")
            }

            // If timed, start timer
            if duration > 0 {
                startTimer(duration: duration)
            }

            return true
        } else {
            if !systemResult.isSuccess {
                os_log(.error, "\(self.t)Failed to create system sleep assertion: \(systemResult.code)")
            }
            if !displayResult.isSuccess {
                os_log(.error, "\(self.t)Failed to create display sleep assertion: \(displayResult.code)")
            }
            if assertionID != 0 {
                environment.releaseAssertion(id: assertionID)
                assertionID = 0
            }
            if displayAssertionID != 0 {
                environment.releaseAssertion(id: displayAssertionID)
                displayAssertionID = 0
            }

            return false
        }
    }

    /// 停止防休眠并清理资源
    func deactivate() {
        guard isActive else { return }

        if Self.verbose {
            os_log("\(self.t)Deactivating Caffeinate")
        }

        // 1. 释放 IOKit 断言
        if assertionID != 0 {
            environment.releaseAssertion(id: assertionID)
            assertionID = 0
        }

        if displayAssertionID != 0 {
            environment.releaseAssertion(id: displayAssertionID)
            displayAssertionID = 0
        }

        // 2. 更新状态
        isActive = false
        activeAction = nil
        startTime = nil
        duration = 0

        // 3. 停止定时器
        environment.cancelScheduledTimer()
    }

    /// Toggle anti-sleep state
    func toggle() {
        if isActive {
            deactivate()
        } else {
            activate(mode: mode)
        }
    }

    /// 获取自激活以来的持续时间
    /// - Returns: 持续时间（秒）
    func getActiveDuration() -> TimeInterval {
        guard let start = startTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    // MARK: - Private Methods

    /// 启动定时器
    /// - Parameter duration: 持续时间（秒）
    private func startTimer(duration: TimeInterval) {
        environment.scheduleTimer(after: duration) { [weak self] in
            self?.deactivate()
        }

        if Self.verbose {
            os_log("\(self.t)Timer scheduled for \(duration)s")
        }
    }
    
    // MARK: - Custom Intervals Support
    
    /// Load available durations
    func loadAvailableDurations() {
        var durations = Self.commonDurations
        
        // Load custom durations from UserDefaults
        if let customMinutes = environment.savedCustomDurations(forKey: customDurationsKey) {
            let customOptions = customMinutes.map { DurationOption.minutes($0) }
            for option in customOptions {
                if !durations.contains(option) {
                    durations.append(option)
                }
            }
        }
        
        // Sort: indefinite first (0), then by duration
        durations.sort {
            if $0.timeInterval == 0 { return true }
            if $1.timeInterval == 0 { return false }
            return $0.timeInterval < $1.timeInterval
        }
        
        self.availableDurations = durations
    }
    
    /// Add a custom duration
    /// - Parameter minutes: Duration in minutes
    func addCustomDuration(minutes: Int) {
        let option = DurationOption.minutes(minutes)
        // 按时长（秒）判重：自定义 60 分钟与预设 1 小时是同一时长，
        // 同时存在会让选择器渲染出两个按钮且同时高亮。
        guard !availableDurations.contains(where: { $0.timeInterval == option.timeInterval }) else {
            return
        }
        availableDurations.append(option)
        // Re-sort
        availableDurations.sort {
            if $0.timeInterval == 0 { return true }
            if $1.timeInterval == 0 { return false }
            return $0.timeInterval < $1.timeInterval
        }
        saveCustomDurations()
    }
    
    /// Remove a duration option
    /// - Parameter option: The option to remove
    func removeDuration(_ option: DurationOption) {
        // Don't remove default durations
        guard !Self.commonDurations.contains(option) else { return }

        availableDurations.removeAll { $0 == option }
        saveCustomDurations()

        // If the selected duration no longer exists, fall back to a valid
        // option — otherwise the picker shows nothing highlighted and the
        // next activation silently uses a value the user can no longer select.
        if !availableDurations.contains(where: { $0.timeInterval == selectedDuration }) {
            selectedDuration = Self.commonDurations[0].timeInterval
        }
    }

    /// Reset durations to default
    func resetDurations() {
        availableDurations = Self.commonDurations
        saveCustomDurations()

        // The selected duration may no longer exist after the reset.
        if !availableDurations.contains(where: { $0.timeInterval == selectedDuration }) {
            selectedDuration = Self.commonDurations[0].timeInterval
        }
    }
    
    private func saveCustomDurations() {
        // Extract custom durations (those not in commonDurations)
        let customOptions = availableDurations.filter { !Self.commonDurations.contains($0) }
        
        // Convert to minutes for storage
        let customMinutes = customOptions.map { option -> Int in
            switch option {
            case .minutes(let m): return m
            case .hours(let h): return h * 60
            case .indefinite: return 0 // Should not happen for custom
            }
        }
        
        environment.saveCustomDurations(customMinutes, forKey: customDurationsKey)
    }

    // MARK: - Cleanup

    deinit {
        // Note: As a @MainActor class, deinit is executed on the main thread
        // However, deinit cannot access actor-isolated properties
        //
        // Normally, resources should be cleaned up via deactivate()
        // deactivate() already cleans up:
        //   - IOKit assertions (assertionID, displayAssertionID)
        //   - Timer
        //
        // If the object is released without deactivate,
        // the system automatically cleans up IOKit assertions (when process ends)
        // Timer will also be automatically released
    }
}

// MARK: - Duration Options

extension CaffeinateManager {
    /// 休眠模式枚举
    enum SleepMode: String, CaseIterable {
        case systemOnly
        case systemAndDisplay
        
        /// 获取模式的显示名称
        var displayName: String {
            switch self {
            case .systemOnly:
                return String(localized: "Keep system awake, allow display sleep", table: "Caffeinate", bundle: .module, comment: "Option to prevent system sleep but allow the monitor to turn off")
            case .systemAndDisplay:
                return String(localized: "Keep system awake, prevent display sleep", table: "Caffeinate", bundle: .module, comment: "Option to prevent both system and monitor from sleeping")
            }
        }
    }

    /// 预设持续时间选项
    enum DurationOption: Hashable, Equatable, Identifiable {
        case indefinite
        case minutes(Int)
        case hours(Int)

        /// 稳定的行标识。
        ///
        /// 列表会被增删并重新排序，标识必须跟随选项本身而非数组位置，
        /// 否则 SwiftUI 会把旧行的状态套用到新行上。
        var id: String {
            switch self {
            case .indefinite: return "indefinite"
            case let .minutes(m): return "m\(m)"
            case let .hours(h): return "h\(h)"
            }
        }

        /// 获取持续时间的显示名称
        var displayName: String {
            switch self {
            case .indefinite:
                return String(localized: "Indefinite", table: "Caffeinate", bundle: .module, comment: "Label for infinite duration")
            case let .minutes(m):
                return String(format: String(localized: "%lld minutes", table: "Caffeinate", bundle: .module, comment: "Label for duration in minutes"), m)
            case let .hours(h):
                return String(format: String(localized: "%lld hours", table: "Caffeinate", bundle: .module, comment: "Label for duration in hours"), h)
            }
        }

        /// 获取对应的秒数
        var timeInterval: TimeInterval {
            switch self {
            case .indefinite:
                return 0
            case let .minutes(m):
                return TimeInterval(m * 60)
            case let .hours(h):
                return TimeInterval(h * 3600)
            }
        }
    }

    /// Quick action types
    enum QuickActionType: Equatable {
        case systemAndDisplay // Prevent sleep and keep display on
        case systemOnly // Prevent sleep and allow display to turn off
        case turnOffDisplay // Prevent sleep and turn off display immediately
    }

    /// Common duration options list
    static let commonDurations: [DurationOption] = [
        .indefinite,
        .minutes(30),
        .hours(1),
        .hours(2),
        .hours(5),
    ]
}
