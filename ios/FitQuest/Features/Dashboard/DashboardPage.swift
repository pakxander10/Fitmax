import SwiftUI

struct DashboardPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let consumed = model.consumed
        let remaining = model.remainingKcal
        VStack(alignment: .leading, spacing: 32) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("02 · DASHBOARD").mono()
                    Text(model.today.weekdayName).display().accessibilityAddTraits(.isHeader)
                }
                Spacer()
                Button { model.overlay = .profile } label: {
                    FQAvatar(initials: "A", size: 44, border: Theme.white)
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Profile")
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 20) {
                    FQRing(value: consumed.kcal, max: model.targets.kcal, size: 156)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("MACROS").mono(color: Theme.ink)
                        FQBar(label: "CARBS", value: consumed.carbs, max: model.targets.carbs)
                        FQBar(label: "PROTEIN", value: consumed.protein, max: model.targets.protein)
                        FQBar(label: "FAT", value: consumed.fat, max: model.targets.fat)
                    }
                }
                Text(remaining >= 0 ? "\(remaining) KCAL REMAINING TODAY · ESTIMATE" : "\(-remaining) KCAL OVER BUDGET · ESTIMATE")
                    .mono()
            }

            Button { withAnimation(.easeOut(duration: 0.32)) { model.page = .gym } } label: {
                HStack(spacing: 14) {
                    FQAvatar(initials: model.gym.logo, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.gym.name).display(16, tracking: 1.5).lineLimit(1).minimumScaleFactor(0.8)
                        Text("\(model.gym.friendsHere) FRIENDS HERE NOW").mono()
                    }
                    Spacer(minLength: 0)
                    Text("→").mono(color: Theme.ink)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .overlay(Rectangle().strokeBorder(Theme.hairline, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())

            PetPanel()
            WeekStrip()
        }
    }
}
