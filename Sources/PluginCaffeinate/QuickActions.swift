import SwiftUI

/// Anti-sleep quick actions component.
///
/// 弹窗的「操作」区由两组构成：
///
/// 1. **模式单选组**（前两项）：互斥的运行模式，带勾选标记。再次点击当前
///    生效的模式可停止防休眠。
/// 2. **即时动作组**（第三项）：一次性的动作按钮，不参与模式单选。
///
/// 把第三项单列成组是必要的，因为它在语义上不是「第三个模式」：
/// `activateAndTurnOffDisplay()` 的稳态就是「防休眠 + 允许关屏」，只是额外
/// 附带一次「立刻把屏幕关掉」的副作用。它从来不是一个可持续的独立模式，
/// 因此也不该占用右侧那个「当前生效模式」的对勾位——否则用户点了它之后
/// 看到的是第二项打勾，会误以为自己改错了模式。
struct CaffeinateQuickActions: View {
    @State private var manager = CaffeinateManager.shared

    let configuration: CaffeinateConfiguration

    var body: some View {
        VStack(spacing: 0) {
            // MARK: 模式单选组

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

            // MARK: 即时动作组

            // 与上面的单选组之间留出间距并加一条更明显的分隔线，
            // 让用户一眼看出「下面是动作，上面是模式」。
            Divider()
                .padding(.top, 4)
                .padding(.bottom, 4)

            QuickActionButton(
                title: String(localized: "Keep Awake & Turn Off Display Now", table: "Caffeinate", bundle: .module, comment: "Action that keeps the system awake and turns off the display immediately"),
                icon: "power",
                color: .purple,
                identifier: "\(configuration.accessibilityIdentifierPrefix).action.turn-off-display",
                action: {
                    // 立即关屏并切换到「systemOnly」模式。
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

/// 模式单选项：带勾选标记的可选项。
private struct QuickActionMenuItem: View {
    let title: String
    let icon: String
    let color: Color
    var isSelected: Bool = false
    let identifier: String
    let action: () -> Void

    @State private var isHovering = false

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

                // 勾选标记只出现在可选项上，标示当前生效的模式。
                if isSelected {
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
        .accessibilityValue(isSelected ? "selected" : "not selected")
        .background(
            Rectangle()
                .fill(isHovering ? Color(nsColor: .selectedContentBackgroundColor) : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Quick Action Button

/// 即时动作按钮：执行一次动作，不表达任何持续状态。
///
/// 与 `QuickActionMenuItem` 的区别：
/// - 右侧没有对勾位——动作没有「选中」这回事；
/// - 无障碍标识不带 `accessibilityValue` 的勾选语义，VoiceOver 读作按钮
///   而不是可选项。
private struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let identifier: String
    let action: () -> Void

    @State private var isHovering = false

    /// 动作按钮的视图主体
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

                // 动作按钮用箭头而非对勾，表明「点下去会做一件事」。
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(isHovering ? .white : color.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
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
