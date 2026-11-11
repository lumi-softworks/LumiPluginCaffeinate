import Foundation
import Testing

/// 防休眠设置页的布局守卫。
///
/// 这套断言原先由 Wakey 仓的 `SettingsLayoutConformanceTests` 承担。防休眠插件包
/// 迁到独立远程包后，源码不再位于宿主仓的 `Packages/` 下，仓库级审计会静默
/// 跳过该页（找不到源文件即 `continue`），布局约束就会失去守卫。因此守卫
/// 跟着代码一起迁到这里，基准值与宿主仓保持一致。
@Suite("防休眠设置页布局")
struct CaffeinateSettingsLayoutTests {
    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // PluginCaffeinateTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // <pkg>
    }

    private static func source(_ relativePath: String) throws -> String {
        let url = Self.packageRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("使用共享设置页布局与卡片组件")
    func usesSharedSettingsLayout() throws {
        let source = try Self.source(
            "Sources/PluginCaffeinate/CaffeinateSettingsView.swift"
        )

        #expect(source.contains("AppSettingsContentScaffold"))
        #expect(!source.contains("Form {"))
        #expect(!source.contains("Form("))
        #expect(!source.contains(".padding(18)"))
        #expect(!source.contains("GroupBox {"))

        for component in [
            "AppCard",
            "AppSettingsSection(",
            "AppSettingsRow(",
            "AppSettingsToggleRow(",
            "AppSettingsStepperRow(",
            "AppSettingsPickerRow(",
            "AppSettingsSegmentedPickerRow(",
            "AppSettingsReadOnlyRow(",
            "AppSettingsSecureFieldRow(",
        ] {
            #expect(!source.contains(component))
        }
    }

    @Test("无障碍标识前缀由宿主注入，不写死品牌")
    func accessibilityIdentifierIsParameterized() throws {
        let source = try Self.source(
            "Sources/PluginCaffeinate/CaffeinateSettingsView.swift"
        )

        #expect(source.contains("configuration.accessibilityIdentifierPrefix"))
        // 不得出现写死的宿主前缀
        #expect(!source.contains("wakey.caffeinate"))
        #expect(!source.contains("com.coffic.wakey"))
    }
}
