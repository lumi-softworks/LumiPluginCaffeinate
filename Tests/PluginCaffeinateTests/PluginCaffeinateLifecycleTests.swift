import KernelCore
import ProviderDocsView
import ProviderSettingView
import ProviderMenuBar
import SwiftUI
import Testing
@testable import PluginCaffeinate

/// 插件的核心契约是「onBoot 贡献状态栏弹窗与设置入口、onShutdown 按 id 撤回」。
/// 这里通过真实的 `DefaultMenuBarProviding` / `DefaultSettingViewProviding`
/// 验证注册表行为，不触碰视图渲染。
@Suite("PluginCaffeinate 插件生命周期")
@MainActor
struct PluginCaffeinateLifecycleTests {
    private func makeKernel() -> KernelCoreContainer {
        KernelCoreContainer()
    }

    @Test("onBoot 注册状态栏弹窗")
    func onBootRegistersPopupView() throws {
        let kernel = makeKernel()
        let popups = DefaultMenuBarProviding()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider(MenuBarProviding.self, popups)
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = PluginCaffeinate()
        try kernel.start(plugins: [plugin])

        #expect(popups.popupItems.count == 1)
    }

    /// 防休眠是用户最常从菜单栏触发的能力，弹窗应排在弹出菜单最前。
    ///
    /// 这里的呈现权重与插件**启动顺序**刻意解耦：启动顺序受依赖关系约束，
    /// 不能为了视觉排序调整；而弹窗位置是纯呈现诉求。
    @Test("弹窗排在其他插件的弹窗之前")
    func popupIsOrderedBeforeOtherPlugins() throws {
        let kernel = makeKernel()
        let popups = DefaultMenuBarProviding()
        try kernel.registerProvider(MenuBarProviding.self, popups)

        // 模拟一个启动顺序更早、但呈现权重更大的其它插件弹窗。
        popups.addPopup(MenuBarContribution(
            id: "OtherPlugin.popup",
            title: "Other",
            order: 200,
            ownerPluginID: "OtherPlugin"
        ) {
            Text("Other")
        })

        let plugin = PluginCaffeinate()
        try kernel.start(plugins: [plugin])

        #expect(popups.popupItems.first?.id == "\(plugin.id).popup")
        #expect(popups.popupItems.first?.order == PluginCaffeinate.popupOrder)
    }

    @Test("onBoot 注册设置入口")
    func onBootRegistersSettingEntry() throws {
        let kernel = makeKernel()
        let popups = DefaultMenuBarProviding()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider(MenuBarProviding.self, popups)
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = PluginCaffeinate()
        try kernel.start(plugins: [plugin])

        #expect(settings.entries.count == 1)
        #expect(settings.entries.first?.id == plugin.id)
    }

    @Test("onShutdown 撤回本插件贡献的弹窗与入口")
    func onShutdownRemovesContributions() throws {
        let kernel = makeKernel()
        let popups = DefaultMenuBarProviding()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider(MenuBarProviding.self, popups)
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = PluginCaffeinate()
        try kernel.start(plugins: [plugin])
        #expect(popups.popupItems.count == 1)

        try kernel.stop()

        #expect(popups.popupItems.isEmpty)
        #expect(settings.entries.isEmpty)
    }

    @Test("禁用自动撤回，重新启用恢复弹窗")
    func disableAndEnableRestoresPopup() async throws {
        let kernel = makeKernel()
        let popups = DefaultMenuBarProviding()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider(MenuBarProviding.self, popups)
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        let plugin = PluginCaffeinate()
        try kernel.start(plugins: [plugin])

        try await kernel.disablePlugin(id: plugin.id)
        #expect(popups.popupItems.isEmpty)

        try await kernel.enablePlugin(id: plugin.id)
        #expect(popups.popupItems.map(\.id) == ["\(plugin.id).popup"])
    }

    @Test("onShutdown 不影响其它 owner 的弹窗")
    func onShutdownKeepsOtherOwnersPopupViews() throws {
        let kernel = makeKernel()
        let popups = DefaultMenuBarProviding()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider(MenuBarProviding.self, popups)
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        popups.addPopup(MenuBarContribution(
            id: "OtherPlugin.popup",
            title: "Other",
            ownerPluginID: "OtherPlugin"
        ) {
            Text("Other")
        })

        let plugin = PluginCaffeinate()
        try kernel.start(plugins: [plugin])
        #expect(popups.popupItems.count == 2)

        try kernel.stop()

        #expect(popups.popupItems.count == 1)
    }

    @Test("缺少 provider 时优雅降级")
    func degradesWithoutProviders() throws {
        let kernel = makeKernel()
        let plugin = PluginCaffeinate()

        try kernel.start(plugins: [plugin])
        try kernel.stop()

        #expect(kernel.registeredPluginCount == 0)
    }

    @Test("插件元数据与 id 一致")
    func metadataMatchesID() {
        let plugin = PluginCaffeinate()
        // 顺带确认插件自带的日志器可用
        plugin.logger.info("PluginCaffeinate metadata test")
        #expect(plugin.metadata.id == plugin.id)
        #expect(plugin.order == 7)
    }
}

/// 说明书条目由插件通过 `DocsViewProviding.addManual` 贡献，
/// 由设置页「通用 → 说明书」统一展示。
@Suite("PluginCaffeinate 说明书贡献")
@MainActor
struct PluginCaffeinateManualContributionTests {
    @Test("onBoot 贡献一条说明书条目")
    func onBootContributesManual() throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = PluginCaffeinate()
        try kernel.start(plugins: [plugin])

        #expect(docs.manualEntries.count == 1)
        #expect(docs.manualEntries.first?.id == plugin.id)
        #expect(docs.manualEntries.first?.name == plugin.metadata.name)
    }

    @Test("说明书视图可渲染")
    func manualViewRenders() throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = PluginCaffeinate()
        try kernel.start(plugins: [plugin])

        let entry = try #require(docs.manualEntries.first)
        _ = entry.makeView()
    }

    @Test("onShutdown 撤回本插件的说明书条目")
    func onShutdownRemovesManual() throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = PluginCaffeinate()
        try kernel.start(plugins: [plugin])
        #expect(docs.manualEntries.count == 1)

        try kernel.stop()

        #expect(docs.manualEntries.isEmpty)
    }
}

/// `onShutdown` 在防休眠仍处于激活状态时会顺带释放电源断言。
/// 这里操作的是进程内共享的 `CaffeinateManager.shared`，因此串行执行。
@Suite("PluginCaffeinate 卸载时释放防休眠", .serialized)
@MainActor
struct PluginCaffeinateShutdownReleaseTests {
    @Test("卸载时若仍激活则停用防休眠")
    func shutdownDeactivatesActiveCaffeinate() throws {
        let kernel = KernelCoreContainer()
        let plugin = PluginCaffeinate()

        // 激活共享管理器，使 onShutdown 走「仍处于激活状态」的分支。
        CaffeinateManager.shared.activate(mode: .systemOnly, duration: 0)
        #expect(CaffeinateManager.shared.isActive)

        try kernel.start(plugins: [plugin])
        try kernel.stop()

        #expect(CaffeinateManager.shared.isActive == false)
    }
}
