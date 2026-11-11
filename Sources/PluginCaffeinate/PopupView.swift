import SwiftUI

/// Status bar popup view for the Caffeinate plugin
struct CaffeinatePopupView: View {
    let configuration: CaffeinateConfiguration

    var body: some View {
        VStack(spacing: 0) {
            // Header with plugin name
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)

                Text("Caffeinate", tableName: "Caffeinate", bundle: .module)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Section 1: Duration Options
            VStack(alignment: .leading, spacing: 4) {
                Text("Duration", tableName: "Caffeinate", bundle: .module)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                CaffeinateDurationPicker(configuration: configuration)
                    .padding(.horizontal, 8)
            }

            Divider()
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

            // Section 2: Quick Actions
            VStack(alignment: .leading, spacing: 4) {
                Text("Actions", tableName: "Caffeinate", bundle: .module)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                CaffeinateQuickActions(configuration: configuration)
            }
        }
        .padding(.bottom, 8)
        .background(
            ZStack {
                // Subtle energy gradient
                LinearGradient(
                    colors: [
                        Color.orange.opacity(0.06),
                        Color.yellow.opacity(0.03),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Decorative watermark icons
                ZStack {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.orange.opacity(0.04))
                        .rotationEffect(.degrees(-15))
                        .offset(x: 100, y: 40)

                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.brown.opacity(0.03))
                        .rotationEffect(.degrees(10))
                        .offset(x: -110, y: 50)
                }
            }
        )
        .clipped()
    }
}

#Preview("Caffeinate Status Bar Popup") {
    CaffeinatePopupView(configuration: CaffeinateConfiguration())
        .frame(width: 300)
}
