import LumiUI
import SwiftUI

// MARK: - Manual View

/// 防休眠使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `DocsViewProviding` 的 manual 条目暴露,
/// 在 设置 → 通用 → 说明书 中阅读。
struct CaffeinateManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Caffeinate"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of Anti-sleep: choosing a duration, switching between anti-sleep modes, and managing custom durations."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Duration: a horizontal strip of duration buttons. The selected button is highlighted; the strip scrolls sideways when there are many durations.")),
                .init(L("Actions: three anti-sleep modes, each with an icon and a selection checkmark.")),
                .init(L("Settings page: under Anti-Sleep Durations, the built-in durations, the add-custom field, and the reset button.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open the menu-bar popover and pick a duration under Duration.")),
                .init(L("Choose a mode under Actions to start anti-sleep; the checkmark marks the active mode.")),
                .init(L("Click the active mode again to stop anti-sleep and release the power assertion.")),
                .init(L("To change the duration while anti-sleep is running, pick another duration; the timer restarts with the new value.")),
            ])

            ManualSectionHeader(number: 4, title: L("Anti-sleep Modes"))
            ManualBulletList(items: [
                .init(L("Keep Awake & Display On: prevents both system sleep and display sleep. Use it for presentations or long reading sessions.")),
                .init(L("Keep Awake & Allow Display Sleep: prevents system sleep but lets the display turn off. Use it when you only need the computer to keep running.")),
                .init(L("Keep Awake & Turn Off Display Now: turns the display off immediately and keeps the system awake.")),
            ])

            ManualSectionHeader(number: 5, title: L("Custom Durations"))
            ManualStepList(items: [
                .init(L("Open Settings and go to the Caffeinate page.")),
                .init(L("Enter a positive number of minutes in the Add Custom field and click the add button, or press Return.")),
                .init(L("The new duration appears in the list and is marked as a custom duration.")),
                .init(L("Click the delete button next to a custom duration to remove it. Built-in durations cannot be deleted.")),
                .init(L("Click Reset to restore the built-in durations and drop all custom ones.")),
            ])

            ManualSectionHeader(number: 6, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("The Indefinite duration keeps the system awake until you stop it manually.")),
                .init(L("When anti-sleep is running, the system power assertion and the timer are released automatically at the end of the selected duration.")),
                .init(L("Uninstalling or disabling the plugin while anti-sleep is active releases the power assertion immediately.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Status-bar popover layout")) {
            VStack(alignment: .leading, spacing: 10) {
                // ① 头部
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.primary)
                    Text(L("Caffeinate"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                }

                Divider()

                // ② 时长区
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Duration"))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textSecondary)

                    HStack(spacing: 5) {
                        ForEach([L("Indefinite"), L("30 min"), L("1 hr"), L("2 hr")], id: \.self) { title in
                            Text(title)
                                .font(.system(size: 9))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(theme.primary.opacity(0.12))
                                )
                                .foregroundStyle(theme.primary)
                        }
                    }
                }

                Divider()

                // ③ 动作区
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Actions"))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textSecondary)

                    ForEach([
                        (L("Keep Awake & Display On"), "sun.max.fill"),
                        (L("Keep Awake & Allow Display Sleep"), "moon.fill"),
                        (L("Keep Awake & Turn Off Display Now"), "power"),
                    ], id: \.0) { title, icon in
                        HStack(spacing: 7) {
                            Image(systemName: icon)
                                .font(.system(size: 10))
                                .foregroundStyle(theme.textSecondary)
                                .frame(width: 14)
                            Text(title)
                                .font(.system(size: 10))
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(theme.primary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Localization

    /// 取本插件资源表中的文案；查不到时回退为 key 本身。
    ///
    /// 用 `Bundle.module.localizedString` 而非 `String(localized:)`：后者的
    /// `LocalizationValue` 需要编译期字面量，动态 key 取不到条目。
    private func L(_ key: String) -> String {
        Bundle.module.localizedString(forKey: key, value: key, table: "Caffeinate")
    }
}

#if DEBUG
#Preview {
    ScrollView {
        CaffeinateManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
#endif
