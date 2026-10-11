import SwiftUI

struct DashboardPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let consumed = model.consumed
        let remaining = model.remainingKcal
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                FQHead(index: "Dashboard", title: model.today.weekdayName)
                Spacer()
                Button { model.present(.profile) } label: { FQAvatar(initials: (model.account ?? SampleData.account).initials, size: 46) }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel("Profile")
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    FQRing(value: consumed.kcal, max: model.targets.kcal, size: 148)
                    VStack(alignment: .leading, spacing: 12) {
                        FQBar(label: "Carbs", value: consumed.carbs, max: model.targets.carbs)
                        FQBar(label: "Protein", value: consumed.protein, max: model.targets.protein)
                        FQBar(label: "Fat", value: consumed.fat, max: model.targets.fat)
                    }
                }
                Text(remaining >= 0 ? "\(remaining) kcal remaining today · estimate" : "\(-remaining) kcal over budget · estimate")
                    .caption(13, color: remaining >= 0 ? Theme.muted : Theme.warning)
            }
            .aeroCard()

            Button { withAnimation(.easeOut(duration: 0.32)) { model.page = .gym } } label: {
                HStack(spacing: 12) {
                    FQAvatar(initials: model.gym.logo, size: 40)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(model.gym.name).heading(16).lineLimit(1).minimumScaleFactor(0.8)
                        Text("\(model.friendsHere(at: model.gymID)) friends here now").caption()
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                }
                .aeroCard(vertical: 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())

            PetPanel()
            WeekStrip()
        }
    }
}
