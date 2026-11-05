import SwiftUI
import FamilyControls

struct PAUSESettingsView: View {
    @ObservedObject var model: PAUSEModel
    @State private var showClearConfirmation = false
    @State private var showDisconnectConfirmation = false

    var body: some View {
        PAUSEPage {
            PAUSEHeader(
                eyebrow: "Preferences & privacy",
                headline: "Your attention\nstays yours.",
                description: "No account, no ads, no cloud activity archive. You decide what PAUSE can monitor."
            )

            PAUSECard {
                PAUSEKicker(text: "01 / Access")
                settingRow(icon: "lock.shield", title: "Screen Time",
                           detail: "Apple-controlled access",
                           value: model.screenTimeAuthorized ? "Allowed" : "Off")
                Rectangle().fill(PAUSEPalette.line).frame(height: 1)
                settingRow(icon: "bell", title: "Notifications",
                           detail: "Gentle threshold reminders",
                           value: model.notificationAuthorized ? "Allowed" : "Off")

                if !model.screenTimeAuthorized {
                    Button("Allow Screen Time") {
                        Task { await model.authorizeScreenTime() }
                    }
                    .buttonStyle(PAUSEButton(filled: false))
                }
                if !model.notificationAuthorized {
                    Button("Enable notifications") {
                        Task { await model.requestNotifications() }
                    }
                    .buttonStyle(PAUSEButton(filled: false))
                }
                Text("You can revoke access in iPhone Settings at any time.")
                    .font(.system(size: 11))
                    .foregroundStyle(PAUSEPalette.secondary)
            }

            PAUSECard {
                PAUSEKicker(text: "02 / Monitoring")
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.monitoring ? "Monitoring is on" : "Monitoring is paused")
                            .font(.system(size: 16, weight: .medium))
                        Text("Selected activity only")
                            .font(.system(size: 12))
                            .foregroundStyle(PAUSEPalette.secondary)
                    }
                    Spacer()
                    PAUSEStatusPill(text: model.monitoring ? "On" : "Off", positive: model.monitoring)
                }
                if model.monitoring {
                    Button("Stop all PAUSE monitoring") {
                        model.stopMonitoring()
                    }
                    .buttonStyle(PAUSEButton(filled: false))
                }
                Text("PAUSE does not block apps or access the contents of your messages.")
                    .font(.system(size: 12))
                    .foregroundStyle(PAUSEPalette.secondary)
            }

            PAUSECard {
                PAUSEKicker(text: "03 / Your local data")
                HStack(alignment: .top) {
                    Image(systemName: "externaldrive")
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Saved on your iPhone")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Rules, app-selection tokens, and \(model.recentEvents.count) recent threshold events. Detailed reports stay in Apple's protected Screen Time extension.")
                            .font(.system(size: 12))
                            .foregroundStyle(PAUSEPalette.secondary)
                            .lineSpacing(3)
                    }
                }

                Button("Clear PAUSE event history") {
                    showClearConfirmation = true
                }
                .buttonStyle(PAUSEButton(filled: false))

                Button("Forget paired board") {
                    showDisconnectConfirmation = true
                }
                .buttonStyle(PAUSEButton(filled: false))
            }

            PAUSECard(color: PAUSEPalette.sage.opacity(0.6)) {
                PAUSEKicker(text: "How this prototype works")
                privacyRow("Screen Time data", "Apple's reporting extension draws your charts. The main app does not receive raw app-by-app usage.")
                privacyRow("Thresholds", "Your iPhone records a small local event when a selected daily limit is reached.")
                privacyRow("Remote board", "Only when you pair a board, PAUSE attempts to send a generic nudge. The Mac bridge is optional.")
                privacyRow("No AI yet", "Today's prompts use predictable wording. Model-generated nudges aren't connected.")
            }

            HStack {
                Text("PAUSE / iOS PROTOTYPE")
                    .tracking(1.4)
                Spacer()
                Text("0.4")
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(PAUSEPalette.secondary)
            .padding(.horizontal, 4)

            PAUSEStatusNotice(text: model.status)
        }
        .confirmationDialog(
            "Delete local check-in history?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete history", role: .destructive) {
                model.clearLocalHistory()
            }
        } message: {
            Text("Your Screen Time data isn't affected. Only the PAUSE event list is cleared.")
        }
        .confirmationDialog(
            "Forget this board?",
            isPresented: $showDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button("Forget board", role: .destructive) {
                model.boardAddress = ""
                model.boardKey = ""
                model.boardConnected = false
                model.saveBoardConnection()
                model.status = "Board pairing cleared from this iPhone."
            }
        } message: {
            Text("You can pair again later using the Mac relay address and a fresh code.")
        }
    }

    @ViewBuilder private func settingRow(
        icon: String, title: String, detail: String, value: String
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(PAUSEPalette.secondary)
            }
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PAUSEPalette.secondary)
        }
    }

    @ViewBuilder private func privacyRow(_ title: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(PAUSEPalette.ink.opacity(0.68))
                .lineSpacing(3)
        }
    }
}
