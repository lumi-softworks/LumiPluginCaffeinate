import KernelCore
import KitAgentTool
import OSLog
import ProviderDocsView
import ProviderLogo
import ProviderMenuBar
import ProviderSettingView
import ProviderStorage
import ProviderToolManager
import SwiftUI

/// Anti-sleep plugin: prevents system sleep, supports scheduled and manual control.
///
/// 共享远程包：宿主（Lumi / Wakey / …）在装配时注入自己的品牌配置，
/// 插件本身不写死任何宿主品牌信息。
@MainActor
public final class PluginCaffeinate: SuperPlugin {
    /// 品牌配置（插件 id、日志子系统、无障碍标识前缀）。
    public let configuration: CaffeinateConfiguration

    /// 日志子系统跟随宿主注入的子系统，便于宿主在系统日志中区分品牌。
    nonisolated let logger: Logger

    public let id: String
    public let order: Int
    public let metadata: PluginMetadata

    /// - Parameters:
    ///   - configuration: 品牌配置。宿主必须传入自己的历史 id，
    ///     否则会丢失用户已保存的启用状态与插件专属数据目录。
    ///   - order: 插件启动顺序（数值越小越先启动）。
    ///   - policy: 启用策略。
    public init(
        configuration: CaffeinateConfiguration = CaffeinateConfiguration(),
        order: Int = 7,
        policy: PluginEnablePolicy = .enabledByDefault
    ) {
        self.configuration = configuration
        self.id = configuration.pluginID
        self.order = order
        self.metadata = PluginMetadata(
            id: configuration.pluginID,
            name: String(localized: "Caffeinate", table: "Caffeinate", bundle: .module, comment: "Name of the anti-sleep plugin"),
            description: String(localized: "Prevent system sleep, supporting scheduled and manual control", table: "Caffeinate", bundle: .module, comment: "Description of what the Caffeinate plugin does"),
            policy: policy
        )
        self.logger = Logger(subsystem: configuration.loggerSubsystem, category: "Caffeinate")
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 绑定宿主能力：Logo 高亮 + 插件数据目录（默认模式持久化）。
        CaffeinateManager.shared.configure(
            storage: kernel.resolveProvider((any StorageProviding).self),
            logo: kernel.resolveProvider((any LogoProviding).self),
            pluginID: id
        )

        // 说明书条目：设置页「通用 → 说明书」中展示
        kernel.resolveProvider((any DocsViewProviding).self)?
            .addManual(DocsEntry(id: id, name: metadata.name) {
                CaffeinateManualView()
            })

        // 注册 Agent 工具。
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.add(tool, pluginID: id)
            }
        }

        try contributeMenuBar(to: kernel)

        // 设置页标签
        kernel.resolveProvider((any SettingViewProviding).self)?
            .addEntries([
                SettingEntryItem(
                    id: id,
                    title: String(localized: "Caffeinate", table: "Caffeinate", bundle: .module, comment: "Name of the anti-sleep plugin"),
                    systemImage: "bolt",
                    detail: { CaffeinateSettingsView(configuration: self.configuration) }
                )
            ])

        // 用户配置过默认模式时，启动即按下该模式。
        CaffeinateManager.shared.applyPersistedDefaultModeIfNeeded()
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        try contributeMenuBar(to: kernel)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: [id])

        // 撤回 Agent 工具
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.remove(id: tool.name)
            }
        }

        // 清理：卸载插件时若仍处于防休眠状态则释放电源断言与定时器
        if CaffeinateManager.shared.isActive {
            CaffeinateManager.shared.deactivate()
        }
    }

    private func contributeMenuBar(to kernel: KernelCoreContainer) throws {
        guard let menuBar = kernel.resolveProvider(MenuBarProviding.self) else { return }
        let ownerID = id
        try kernel.trackContribution {
            menuBar.removeItems(ownedBy: ownerID)
        }
        menuBar.addPopup(MenuBarContribution(
            id: "\(id).popup",
            title: metadata.name,
            order: order,
            ownerPluginID: id
        ) {
            CaffeinatePopupView(configuration: self.configuration)
        })
    }

    // MARK: - Agent Tools

    /// 插件贡献的 Agent 工具。
    ///
    /// 工具与 UI 共用同一个 `CaffeinateManager`，因此 Agent 触发的防休眠
    /// 会同步反映到菜单栏弹窗与 Logo 高亮上。
    public static let agentTools: [any SuperAgentTool] = [
        CaffeinateActivateTool(),
        CaffeinateDeactivateTool(),
        CaffeinateStatusTool(),
        CaffeinateTurnOffDisplayTool(),
    ]
}
