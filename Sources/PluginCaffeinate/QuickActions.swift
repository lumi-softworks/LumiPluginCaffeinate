import SwiftUI

/// Anti-sleep quick actions component
struct CaffeinateQuickActions: View {
    @State private var manager = CaffeinateManager.shared

    let configuration: CaffeinateConfiguration

    var body: some View {
        VStack(spacing: 0) {
            QuickActionMenuItem(
                title: String(localized: "Keep Awake & Display On", table: "Caffeinate", bundle: .module, comment: "Option to keep both system and display awake"),
                icon: "sun.max.fill",
                color: .orange,
                isSelected: manager.activeAction == .systemAndDisplay,
                identifier: "\(configuration.accessibilityIdentifierPrefix).action.system-and-display",
                action: {
                    toggleAction(.systemAndDisplay)
                }
            )

            Divider()
                .padding(.leading, 36)

            QuickActionMenuItem(
                title: String(localized: "Keep Awake & Allow Display Sleep", table: "Caffeinate", bundle: .module, comment: "Option to keep system awake but allow display to sleep"),
                icon: "moon.fill",
                color: .blue,
                isSelected: manager.activeAction == .systemOnly,
                identifier: "\(configuration.accessibilityIdentifierPrefix).action.system-only",
                action: {
                    toggleAction(.systemOnly)
                }
            )

            Divider()
                .padding(.leading, 36)

            QuickActionMenuItem(
                title: String(localized: "Keep Awake & Turn Off Display Now", table: "Caffeinate", bundle: .module, comment: "Option to keep system awake and turn off display immediately"),
                icon: "power",
                color: .purple,
                showCheckmark: false, // Instant action, no checkmark
                identifier: "\(configuration.accessibilityIdentifierPrefix).action.turn-off-display",
                action: {
                    // Turn off display immediately and switch to "systemOnly" mode
                    manager.activateAndTurnOffDisplay(duration: manager.selectedDuration)
                }
            )
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helper Methods

    /// 切换防休眠动作的状态
    /// - Parameter action: 要切换的动作类型
    private func toggleAction(_ action: CaffeinateManager.QuickActionType) {
        if manager.activeAction == action {
            // 点击已选中的项将其停用
            manager.deactivate()
        } else {
            // 选择新项并激活（切换模式时由 manager 先停掉旧会话）
            manager.switchAction(action)
        }
    }
}

// MARK: - Quick Action Menu Item

private struct QuickActionMenuItem: View {
    let title: String
    let icon: String
    let color: Color
    var isSelected: Bool = false
    var showCheckmark: Bool? = nil // nil means automatic based on isSelected
    let identifier: String
    let action: () -> Void

    @State private var isHovering = false

    private var shouldShowCheckmark: Bool {
        if let showCheckmark = showCheckmark {
            return showCheckmark
        }
        return isSelected
    }

    /// 快捷操作菜单项的视图主体
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(isHovering ? .white : color)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(isHovering ? .white : .secondary)

                Spacer()

                // Show checkmark
                if shouldShowCheckmark {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(isHovering ? .white : color)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(shouldShowCheckmark ? "selected" : "not selected")
        .background(
            Rectangle()
                .fill(isHovering ? Color(nsColor: .selectedContentBackgroundColor) : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    CaffeinateQuickActions(configuration: CaffeinateConfiguration())
        .frame(width: 250)
        .padding()
}
