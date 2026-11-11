import Testing
@testable import PluginCaffeinate

/// 品牌配置注入：宿主传入自己的插件 id、日志子系统与无障碍标识前缀，
/// 插件本身不写死任何宿主品牌信息。
@Suite("CaffeinateConfiguration 品牌注入")
@MainActor
struct CaffeinateConfigurationTests {
    @Test("默认配置使用 Lumi 品牌")
    func defaultsUseLumiBrand() {
        let configuration = CaffeinateConfiguration()

        #expect(configuration.pluginID == "com.coffic.lumi.plugin.caffeinate")
        #expect(configuration.loggerSubsystem == "com.coffic.lumi.plugin.caffeinate")
        #expect(configuration.accessibilityIdentifierPrefix == "caffeinate")
    }

    @Test("宿主注入的配置被插件采用")
    func hostConfigurationIsAdopted() {
        let configuration = CaffeinateConfiguration(
            pluginID: "CaffeinatePlugin",
            loggerSubsystem: "com.coffic.wakey.plugin.caffeinate",
            accessibilityIdentifierPrefix: "wakey.caffeinate"
        )
        let plugin = PluginCaffeinate(configuration: configuration)

        #expect(plugin.id == "CaffeinatePlugin")
        #expect(plugin.metadata.id == "CaffeinatePlugin")
        #expect(plugin.configuration.loggerSubsystem == "com.coffic.wakey.plugin.caffeinate")
        #expect(plugin.configuration.accessibilityIdentifierPrefix == "wakey.caffeinate")
    }

    @Test("默认构造的插件沿用默认启动顺序与启用策略")
    func defaultOrderAndPolicy() {
        let plugin = PluginCaffeinate()

        #expect(plugin.order == 7)
        #expect(plugin.metadata.policy == .enabledByDefault)
    }
}
