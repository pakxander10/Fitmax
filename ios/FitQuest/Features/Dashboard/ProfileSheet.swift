import SwiftUI

struct ProfileSheet: View {
    @Environment(AppModel.self) private var model

    private static let biometrics = [
        ("178", "HEIGHT CM"), ("74.5", "WEIGHT KG"), ("38.2", "NECK CM"),
        ("99.0", "CHEST CM"), ("82.5", "WAIST CM"), ("97.0", "HIPS CM"),
    ]

    private var facts: [(String, String)] {
        let targets = model.targets
        return [
            ("GOAL", "Lean bulk · 4 days a week"),
            ("EXPERIENCE", "Intermediate"),
            ("INJURIES", "Left shoulder: avoid overhead barbell work"),
            ("EQUIPMENT", "Full gym · barbell, dumbbells, cables"),
            ("DIET", "Peanut allergy"),
            ("TARGETS", "\(targets.kcal) kcal · P \(targets.protein) · C \(targets.carbs) · F \(targets.fat) g"),
        ]
    }

    var body: some View {
        let game = model.game
        let scanned = model.today.adding(-7)
        FQOverlay(title: "Profile", onBack: { model.overlay = nil }) {
            VStack(alignment: .leading, spacing: 32) {
                HStack(spacing: 20) {
                    FQAvatar(initials: "A", size: 80, border: Theme.white)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Alex Moreno").display(28)
                        Text("RANK \(game.rank.rawValue) · LVL \(game.level) · \(game.xp.formatted(.number.grouping(.automatic))) XP").mono()
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("BIOMETRICS · ESTIMATE").mono(color: Theme.ink)
                        Spacer(minLength: 8)
                        Text("SCANNED \(scanned.dayOfMonth) \(scanned.monthShort)").mono()
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 0) {
                        ForEach(Self.biometrics, id: \.1) { SpecCell(value: $0.0, label: $0.1) }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("16.4%").display()
                        Text("BODY FAT · NAVY · ±4 PTS").mono()
                    }
                    .padding(.top, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .top) { Hairline() }
                }

                VStack(spacing: 0) {
                    ForEach(facts, id: \.0) { fact in
                        FQRow(alignment: .firstTextBaseline) {
                            Text(fact.0).mono().frame(width: 96, alignment: .leading)
                            Text(fact.1).serif(color: Theme.ink)
                        }
                    }
                }

                HStack(spacing: 12) {
                    FQButton(title: "New scan") { model.flash("SCAN · COMING SOON") }
                    FQButton(title: "Edit", variant: .ghost) { model.flash("EDIT PROFILE · COMING SOON") }
                }

                Text("All body measurements are estimates from photos. Trends matter more than single readings. This app is not medical advice.")
                    .serif(14, color: Theme.mutedSoft)
            }
        }
    }
}
