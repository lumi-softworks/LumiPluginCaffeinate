import LumiUI
import SwiftUI

struct CaffeinateSettingsView: View {
    @State private var manager = CaffeinateManager.shared
    @State private var customMinutes: Int = 45

    let configuration: CaffeinateConfiguration

    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            AppSettingSection(title: String(localized: "Anti-Sleep Durations", table: "Caffeinate", bundle: .module)) {
                VStack(spacing: 0) {
                    // 用选项自身的稳定 id 标识行，而不是数组下标——
                    // 列表会被增删并重新排序，下标变化会让 SwiftUI 把旧行
                    // 的状态套用到别的行上。
                    ForEach(manager.availableDurations) { option in
                        AppSettingRow(
                            title: option.displayName,
                            description: CaffeinateManager.commonDurations.contains(option)
                                ? nil
                                : String(localized: "Custom duration", table: "Caffeinate", bundle: .module),
                            icon: "clock"
                        ) {
                            if !CaffeinateManager.commonDurations.contains(option) {
                                AppButton(systemImage: "minus", style: .destructive) {
                                    manager.removeDuration(option)
                                }
                                .help(Text("Delete", tableName: "Caffeinate", bundle: .module))
                                .accessibilityIdentifier("\(configuration.accessibilityIdentifierPrefix).duration.remove.\(Int(option.timeInterval))")
                            }
                        }
                        if option != manager.availableDurations.last {
                            Divider().padding(.vertical, 8)
                        }
                    }

                    Divider().padding(.vertical, 8)

                    AppSettingRow(
                        title: String(localized: "Add Custom (minutes):", table: "Caffeinate", bundle: .module),
                        description: String(localized: "Add a duration for manual activation.", table: "Caffeinate", bundle: .module),
                        icon: "plus.circle"
                    ) {
                        HStack(spacing: 8) {
                            TextField("", value: $customMinutes, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 64)
                                .accessibilityIdentifier("\(configuration.accessibilityIdentifierPrefix).custom-duration.minutes")
                                .onSubmit { addCustomDuration() }
                            AppButton(systemImage: "plus", style: .secondary, action: addCustomDuration)
                                .disabled(customMinutes <= 0)
                                .accessibilityIdentifier("\(configuration.accessibilityIdentifierPrefix).custom-duration.add")
                        }
                    }

                    Divider().padding(.vertical, 8)

                    AppSettingRow(
                        title: String(localized: "Reset to Default Durations", table: "Caffeinate", bundle: .module),
                        description: String(localized: "Restore the built-in anti-sleep durations.", table: "Caffeinate", bundle: .module),
                        icon: "arrow.counterclockwise"
                    ) {
                        AppButton(
                            String(localized: "Reset", table: "Caffeinate", bundle: .module),
                            systemImage: "arrow.counterclockwise",
                            style: .secondary,
                            size: .small,
                            action: manager.resetDurations
                        )
                        .accessibilityIdentifier("\(configuration.accessibilityIdentifierPrefix).duration.reset")
                    }
                }
            }
        }
        .onAppear {
            customMinutes = 45
        }
    }

    private func addCustomDuration() {
        guard customMinutes > 0 else { return }
        manager.addCustomDuration(minutes: customMinutes)
        customMinutes = 45 // Reset to default suggestion
    }
}

#Preview {
    CaffeinateSettingsView(configuration: CaffeinateConfiguration())
        .frame(width: 400, height: 400)
}
