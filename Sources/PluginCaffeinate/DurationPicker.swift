import SwiftUI

/// Anti-sleep duration picker component
struct CaffeinateDurationPicker: View {
    @State private var manager = CaffeinateManager.shared

    let configuration: CaffeinateConfiguration

    private var availableDurations: [CaffeinateManager.DurationOption] {
        manager.availableDurations
    }

    /// 持续时间选择器的视图主体
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(availableDurations, id: \.self) { option in
                    PopupDurationButton(
                        title: option.displayName,
                        isSelected: manager.selectedDuration == option.timeInterval,
                        identifier: "\(configuration.accessibilityIdentifierPrefix).duration.\(Int(option.timeInterval))",
                        action: {
                            // Update selected duration
                            manager.selectedDuration = option.timeInterval

                            // If anti-sleep is running, restart timer with new duration
                            if manager.isActive, let action = manager.activeAction {
                                // Deactivate first to reset timer
                                manager.deactivate()

                                // Reactivate with new duration
                                switch action {
                                case .systemAndDisplay:
                                    manager.activate(mode: .systemAndDisplay, duration: manager.selectedDuration)
                                case .systemOnly:
                                    manager.activate(mode: .systemOnly, duration: manager.selectedDuration)
                                case .turnOffDisplay:
                                    manager.activateAndTurnOffDisplay(duration: manager.selectedDuration)
                                }
                            }
                        }
                    )
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Duration Selection Button

/// 持续时间选择按钮
private struct PopupDurationButton: View {
    let title: String
    let isSelected: Bool
    let identifier: String
    let action: () -> Void

    /// 按钮的视图主体
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                .cornerRadius(3)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    CaffeinateDurationPicker(configuration: CaffeinateConfiguration())
        .padding()
}
