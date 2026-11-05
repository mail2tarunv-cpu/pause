import SwiftUI
import FamilyControls

struct PAUSERulesView: View {
    @ObservedObject var model: PAUSEModel
    @State private var picking = false

    var body: some View {
        PAUSEPage {
            PAUSEHeader(
                eyebrow: "Your rules",
                headline: "A nudge,\nnot a wall.",
                description: "Choose exactly what to monitor, when PAUSE should intervene, and how it should sound."
            )

            PAUSECard {
                HStack {
                    PAUSEKicker(text: "01 / iPhone access")
                    Spacer()
                    PAUSEStatusPill(
                        text: model.screenTimeAuthorized ? "Authorized" : "Required",
                        positive: model.screenTimeAuthorized
                    )
                }
                Text("Screen Time")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                Text("Apple asks for your permission. Your selected apps stay private on this iPhone.")
                    .font(.system(size: 12))
                    .foregroundStyle(PAUSEPalette.secondary)
                    .lineSpacing(3)
                if !model.screenTimeAuthorized {
                    Button("Allow Screen Time access") {
                        Task { await model.authorizeScreenTime() }
                    }
                    .buttonStyle(PAUSEButton())
                }

                Rectangle().fill(PAUSEPalette.line).frame(height: 1)

                HStack {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(PAUSEPalette.ink)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gentle notifications")
                            .font(.system(size: 13, weight: .semibold))
                        Text("A check-in when a limit is reached")
                            .font(.system(size: 11))
                            .foregroundStyle(PAUSEPalette.secondary)
                    }
                    Spacer()
                    Button(model.notificationAuthorized ? "Enabled" : "Enable") {
                        Task { await model.requestNotifications() }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .disabled(model.notificationAuthorized)
                }
            }

            PAUSECard {
                PAUSEKicker(text: "02 / Choose apps and sites")

                Button {
                    model.saveSelection()
                    picking = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "square.grid.3x3")
                            .font(.system(size: 22))
                            .frame(width: 39, height: 39)
                            .background(PAUSEPalette.background, in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Select what to monitor")
                                .font(.system(size: 14, weight: .semibold))
                            Text("\(model.selection.applicationTokens.count) apps · \(model.selection.categoryTokens.count) categories · \(model.selection.webDomainTokens.count) websites")
                                .font(.system(size: 11))
                                .foregroundStyle(PAUSEPalette.secondary)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(PAUSEPalette.ink)
                }
                .buttonStyle(.plain)
                .disabled(!model.screenTimeAuthorized)
                .familyActivityPicker(isPresented: $picking, selection: $model.selection)
                .onChange(of: model.selection) { _, _ in
                    model.saveSelection()
                }

                Text("Only selected apps, categories, and websites count towards this rule. Apple hides their exact identities from PAUSE.")
                    .font(.system(size: 11))
                    .foregroundStyle(PAUSEPalette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PAUSECard {
                PAUSEKicker(text: "03 / When should we check in?")
                Text("Daily usage threshold")
                    .font(.system(size: 15, weight: .medium))
                HStack(alignment: .firstTextBaseline) {
                    Text("\(model.thresholdMinutes)")
                        .font(.system(size: 54, weight: .medium, design: .rounded))
                        .tracking(-2.2)
                    Text("min")
                        .font(.system(size: 14))
                        .foregroundStyle(PAUSEPalette.secondary)
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 23))
                        .foregroundStyle(PAUSEPalette.secondary)
                }
                HStack(spacing: 10) {
                    Button {
                        model.thresholdMinutes = max(5, model.thresholdMinutes - 5)
                    } label: {
                        Image(systemName: "minus")
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                    }
                    .buttonStyle(PAUSEButton(filled: false))

                    Button {
                        model.thresholdMinutes = min(240, model.thresholdMinutes + 5)
                    } label: {
                        Image(systemName: "plus")
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                    }
                    .buttonStyle(PAUSEButton(filled: false))
                }
                Text("The limit counts selected activity across each day. It is not a timer that resets each time you open an app.")
                    .font(.system(size: 11))
                    .foregroundStyle(PAUSEPalette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PAUSECard {
                PAUSEKicker(text: "04 / Choose your nudge")
                ForEach(PAUSECategory.allCases) { category in
                    Button {
                        model.category = category
                    } label: {
                        HStack(alignment: .top, spacing: 13) {
                            Image(systemName: category.icon)
                                .font(.system(size: 19))
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category.title)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(category.detail)
                                    .font(.system(size: 11))
                                    .foregroundStyle(PAUSEPalette.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 3)
                            Image(systemName: model.category == category ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 19))
                        }
                        .foregroundStyle(PAUSEPalette.ink)
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)
                }
                Text("This label chooses the nudge wording. The actual apps are whatever you selected above.")
                    .font(.system(size: 11))
                    .foregroundStyle(PAUSEPalette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                Button(model.monitoring ? "Update monitoring" : "Start monitoring") {
                    model.startMonitoring()
                }
                .buttonStyle(PAUSEButton())
                .disabled(!model.screenTimeAuthorized || !model.hasSelection)

                if model.monitoring {
                    Button("Pause monitoring") {
                        model.stopMonitoring()
                    }
                    .buttonStyle(PAUSEButton(filled: false))
                }
            }
            PAUSEStatusNotice(text: model.status)
        }
    }
}
