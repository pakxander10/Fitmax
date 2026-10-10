import SwiftUI

struct ProfileSheet: View {
    @Environment(AppModel.self) private var model

    private static let biometrics = [
        ("178", "Height cm"), ("74.5", "Weight kg"), ("38.2", "Neck cm"),
        ("99.0", "Chest cm"), ("82.5", "Waist cm"), ("97.0", "Hips cm"),
    ]

    private var facts: [(String, String)] {
        let targets = model.targets
        return [
            ("Goal", "Lean bulk · 4 days a week"),
            ("Experience", "Intermediate"),
            ("Injuries", "Left shoulder: avoid overhead barbell work"),
            ("Equipment", "Full gym · barbell, dumbbells, cables"),
            ("Diet", "Peanut allergy"),
            ("Targets", "\(targets.kcal) kcal · P \(targets.protein) · C \(targets.carbs) · F \(targets.fat) g"),
        ]
    }

    var body: some View {
        @Bindable var model = model
        let game = model.game
        let scanned = model.today.adding(-7)
        FQOverlay(title: "Profile", onBack: model.dismiss) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    FQAvatar(initials: "A", size: 72)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Alex Moreno").heading(24)
                        Text("Pet level \(game.level) · \(game.xp.formatted(.number.grouping(.automatic))) XP").caption(13)
                        Label(
                            model.hidesProfileFromNonFriends ? "Visible to friends only" : "Visible to everyone at your gym",
                            systemImage: model.hidesProfileFromNonFriends ? "lock.fill" : "eye"
                        )
                        .font(Theme.caption(12))
                        .foregroundStyle(Theme.muted)
                    }
                }
                .aeroCard()

                VStack(alignment: .leading, spacing: 12) {
                    CardTitle(title: "Biometrics · estimate", trailing: "Scanned \(scanned.dayOfMonth) \(scanned.monthShort)")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(Self.biometrics, id: \.1) { SpecCell(value: $0.0, label: $0.1) }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("16.4%").heading(28)
                        Text("Body fat · Navy method · ±4 pts").caption()
                    }
                }
                .aeroCard()

                VStack(spacing: 0) {
                    ForEach(facts, id: \.0) { fact in
                        FQRow(alignment: .firstTextBaseline, divider: fact.0 != facts.last?.0) {
                            Text(fact.0).caption(13).frame(width: 88, alignment: .leading)
                            Text(fact.1).copy(color: Theme.ink)
                        }
                    }
                }
                .aeroCard(vertical: 4)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $model.hidesProfileFromNonFriends) {
                        Text("Hide my profile from non-friends").heading(16)
                    }
                    .tint(Theme.lime)
                    Text(model.hidesProfileFromNonFriends
                        ? "Only friends can see your profile, gym activity and what you listen to. Others at your gym see you counted as a private listener, and can find you by name to send a friend request."
                        : "Anyone at your gym can see your profile, gym activity and what you listen to.")
                        .copy(13, color: Theme.muted)
                }
                .aeroCard()

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        FQButton(title: "New scan") { model.flash("Scan · coming soon") }
                        FQButton(title: "Edit", variant: .secondary) { model.flash("Edit profile · coming soon") }
                    }
                    Text("All body measurements are estimates from photos. Trends matter more than single readings. This app is not medical advice.")
                        .copy(13, color: Theme.muted)
                }
                .aeroCard()
            }
        }
    }
}
