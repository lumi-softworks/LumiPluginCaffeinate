import Foundation
import IOKit.pwr_mgt
import KernelCore
import KitAgentTool
import ProviderLogo
import ProviderStorage
import ProviderToolManager
import Testing
@testable import PluginCaffeinate

/// 宿主能力接入的守卫测试。
///
/// 防休眠插件通过宿主注入三项能力：
/// - `StorageProviding`：持久化默认启动模式；
/// - `LogoProviding`：防休眠激活时高亮状态栏 Logo；
/// - `ToolManagerProviding`：注册 4 个 Agent 工具。
///
/// 这些能力都是可选的——宿主没提供时插件仍然可用，只是缺少对应效果。
@Suite("宿主能力接入")
@MainActor
struct CaffeinateHostCapabilityTests {

    // MARK: - 测试替身

    /// 可控的 Logo 能力实现，记录高亮调用。
    private final class FakeLogoProviding: LogoProviding {
        private(set) var isLogoHighlighted = false
        private(set) var highlightCallCount = 0

        func setLogoHighlighted(_ highlighted: Bool) {
            guard isLogoHighlighted != highlighted else { return }
            isLogoHighlighted = highlighted
            highlightCallCount += 1
        }

        var allLogoItems: [LogoItem] { [] }

        func registerLogoItem(_ item: LogoItem) {}
        func unregisterLogoItem(id: String) {}
    }

    /// 可控的存储能力实现，指向临时目录。
    private final class FakeStorageProviding: StorageProviding {
        let dataRootDirectory: URL

        init(dataRootDirectory: URL) {
            self.dataRootDirectory = dataRootDirectory
        }

        func pluginDataDirectory(for pluginID: String) -> URL {
            dataRootDirectory.appendingPathComponent(pluginID, isDirectory: true)
        }

        func coreDataDirectory() -> URL {
            dataRootDirectory.appendingPathComponent("core", isDirectory: true)
        }

        func dataRootDirectorySizeInBytes() async -> Int64 { 0 }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("caffeinate-host-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Logo 高亮

    @Test("激活防休眠时点亮 Logo，停止时熄灭")
    func logoHighlightsWhileActive() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)
        let logo = FakeLogoProviding()

        manager.configure(storage: nil, logo: logo, pluginID: "test.caffeinate")
        manager.activate(mode: .systemAndDisplay, duration: 0)

        #expect(logo.isLogoHighlighted)
        #expect(logo.highlightCallCount == 1)

        manager.deactivate()

        #expect(logo.isLogoHighlighted == false)
        #expect(logo.highlightCallCount == 2)
    }

    @Test("没有 Logo 能力时激活依然可用")
    func activationWorksWithoutLogoCapability() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.configure(storage: nil, logo: nil, pluginID: "test.caffeinate")

        #expect(manager.activate(mode: .systemOnly, duration: 0))
        #expect(manager.isActive)
    }

    // MARK: - 默认模式持久化

    @Test("默认启动模式写入插件数据目录并可读回")
    func persistedDefaultModeRoundTrips() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let storage = FakeStorageProviding(dataRootDirectory: root)
        let manager = CaffeinateManager(environment: FakeCaffeinateEnvironment())

        manager.configure(storage: storage, logo: nil, pluginID: "test.caffeinate")

        #expect(manager.setPersistedDefaultMode(.systemOnly))
        #expect(manager.persistedDefaultMode == .systemOnly)

        // 写入落到了插件专属目录，而不是全局 UserDefaults。
        let settingsFile = root
            .appendingPathComponent("test.caffeinate", isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
            .appendingPathComponent("settings.plist")
        #expect(FileManager.default.fileExists(atPath: settingsFile.path))

        // 新实例读回同一个偏好。
        let reloaded = CaffeinateManager(environment: FakeCaffeinateEnvironment())
        reloaded.configure(storage: storage, logo: nil, pluginID: "test.caffeinate")
        #expect(reloaded.persistedDefaultMode == .systemOnly)
    }

    @Test("清除默认模式后恢复为随用随选")
    func clearingPersistedDefaultMode() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let storage = FakeStorageProviding(dataRootDirectory: root)
        let manager = CaffeinateManager(environment: FakeCaffeinateEnvironment())
        manager.configure(storage: storage, logo: nil, pluginID: "test.caffeinate")

        #expect(manager.setPersistedDefaultMode(.systemAndDisplay))
        #expect(manager.setPersistedDefaultMode(nil))
        #expect(manager.persistedDefaultMode == nil)
    }

    @Test("启动时按下持久化的默认模式")
    func appliesPersistedDefaultModeOnStart() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let storage = FakeStorageProviding(dataRootDirectory: root)
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)
        manager.configure(storage: storage, logo: nil, pluginID: "test.caffeinate")
        #expect(manager.setPersistedDefaultMode(.systemOnly))

        let started = CaffeinateManager(environment: fake)
        started.configure(storage: storage, logo: nil, pluginID: "test.caffeinate")

        #expect(started.applyPersistedDefaultModeIfNeeded())
        #expect(started.activeAction == .systemOnly)
    }

    @Test("已在防休眠时不再套用默认模式")
    func doesNotOverrideActiveSession() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)
        manager.configure(storage: nil, logo: nil, pluginID: "test.caffeinate")
        #expect(manager.setPersistedDefaultMode(.systemOnly))

        manager.activate(mode: .systemAndDisplay, duration: 0)

        #expect(manager.applyPersistedDefaultModeIfNeeded() == false)
        #expect(manager.activeAction == .systemAndDisplay)
    }

    // MARK: - 关屏动作的状态语义

    @Test("关屏动作会记录标志位，但运行模式仍是 systemOnly")
    func turnOffDisplayRecordsFlagButKeepsSystemOnlyMode() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activateAndTurnOffDisplay(duration: 0)

        #expect(fake.turnOffDisplayCount == 1)
        #expect(manager.isDisplayOffRequested)
        // 关屏动作的稳态就是「防休眠 + 允许关屏」，因此 activeAction 落在
        // systemOnly 上——弹窗里的勾选只反映这两项真正的运行模式。
        #expect(manager.activeAction == .systemOnly)
        #expect(manager.mode == .systemOnly)
    }

    @Test("普通模式激活会清掉关屏标志位")
    func plainActivationClearsDisplayOffFlag() {
        let fake = FakeCaffeinateEnvironment()
        let manager = CaffeinateManager(environment: fake)

        manager.activateAndTurnOffDisplay(duration: 0)
        #expect(manager.isDisplayOffRequested)

        manager.deactivate()
        #expect(manager.isDisplayOffRequested == false)

        manager.activate(mode: .systemAndDisplay, duration: 0)
        #expect(manager.isDisplayOffRequested == false)
    }

    // MARK: - Agent 工具注册

    @Test("onBoot 向工具管理器注册 4 个 Agent 工具")
    func onBootRegistersAgentTools() throws {
        let kernel = KernelCoreContainer()
        let toolManager = DefaultToolManagerProviding()
        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)

        let plugin = PluginCaffeinate()
        try kernel.start(plugins: [plugin])

        let names = toolManager.allTools().map(\.name)
        #expect(names.contains("caffeinate_activate"))
        #expect(names.contains("caffeinate_deactivate"))
        #expect(names.contains("caffeinate_status"))
        #expect(names.contains("caffeinate_turn_off_display"))

        // 工具归属于本插件，便于 UI 按插件分组展示。
        let grouped = toolManager.toolsGroupedByPlugin()
        #expect(grouped.contains { $0.pluginID == plugin.id && $0.tools.count == 4 })
    }

    @Test("onShutdown 撤回 Agent 工具")
    func onShutdownRemovesAgentTools() throws {
        let kernel = KernelCoreContainer()
        let toolManager = DefaultToolManagerProviding()
        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)

        let plugin = PluginCaffeinate()
        try kernel.start(plugins: [plugin])
        #expect(toolManager.allTools().count == 4)

        try kernel.stop()

        #expect(toolManager.allTools().isEmpty)
    }

    @Test("工具的名称与 schema 保持稳定")
    func agentToolContractIsStable() {
        let tools = PluginCaffeinate.agentTools
        #expect(tools.map(\.name) == [
            "caffeinate_activate",
            "caffeinate_deactivate",
            "caffeinate_status",
            "caffeinate_turn_off_display",
        ])

        let activateProperties = tools[0].inputSchema(for: .english)["properties"] as? [String: Any]
        #expect(activateProperties?["mode"] != nil)
        #expect(activateProperties?["duration"] != nil)

        let turnOffProperties = tools[3].inputSchema(for: .english)["properties"] as? [String: Any]
        #expect(turnOffProperties?["duration"] != nil)

        // 全部为低风险：只影响本机电源状态，不触碰用户数据。
        for tool in tools {
            #expect(tool.permissionRiskLevel(arguments: [:]) == .low)
        }
    }
}
