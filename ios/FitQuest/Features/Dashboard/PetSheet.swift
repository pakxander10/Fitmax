import SwiftUI

struct PetSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var emoji = ""

    private static let shop: [(name: String, kind: String, cost: Int, owned: Bool)] = [
        ("Molsheim garage", "Background", 200, true),
        ("Night track", "Background", 350, false),
        ("Racing collar", "Accessory", 120, true),
        ("Carbon kennel", "Interior", 600, false),
    ]

    private static let achievements: [(name: String, earned: Bool)] = [
        ("First scan", true),
        ("7-day streak", false),
        ("100 meals logged", false),
        ("Visit a friend’s pet", true),
    ]

    var body: some View {
        let game = model.game
        let face = emoji.isEmpty ? model.mood.emojis[0] : emoji
        FQOverlay(title: "Biscuit", onBack: model.dismiss) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    DogYard(height: 190) {
                        // Standing still here, so only the tail wags.
                        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
                            DogView(stride: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate * 5, walking: false)
                                .scaleEffect(1.7, anchor: .bottom)
                        }
                    }
                    HStack(alignment: .top, spacing: 8) {
                        SpecCell(value: face, label: "Mood · \(model.mood.rawValue)")
                        SpecCell(value: "\(game.level)", label: "Pet level")
                        SpecCell(value: "\(model.points)", label: "Points")
                    }
                    VStack(spacing: 6) {
                        HStack {
                            Text("\(game.xp.formatted(.number.grouping(.automatic))) XP").caption(13, color: Theme.ink)
                            Spacer(minLength: 8)
                            Text("\(game.xpToNextLevel) XP to level \(game.level + 1)").caption()
                        }
                        FQProgressLine(fraction: game.progress)
                    }
                    Text("Biscuit is happy when you hit your goals and levels up as you earn XP. Earn points at the gym and by following your plan.")
                        .copy(14)
                }
                .aeroCard()

                VStack(alignment: .leading, spacing: 0) {
                    CardTitle(title: "Shop").padding(.vertical, 12)
                    ForEach(Self.shop, id: \.name) { item in
                        FQRow(divider: item.name != Self.shop.last?.name) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(item.name).copy(color: Theme.ink)
                                Text(item.kind).caption()
                            }
                            Spacer(minLength: 0)
                            Text(item.owned ? "Owned" : "\(item.cost) pts").caption(13, color: item.owned ? Theme.success : Theme.ink)
                        }
                    }
                }
                .aeroCard(vertical: 4)

                VStack(alignment: .leading, spacing: 0) {
                    CardTitle(title: "Achievements").padding(.vertical, 12)
                    ForEach(Self.achievements, id: \.name) { item in
                        FQRow(divider: item.name != Self.achievements.last?.name) {
                            FQCheck(on: item.earned, size: 20)
                            Text(item.name).copy(color: item.earned ? Theme.ink : Theme.muted)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(item.earned ? "Earned" : "Not earned")
                    }
                }
                .aeroCard(vertical: 4)
            }
        }
        .onAppear { emoji = model.mood.randomEmoji() }
    }
}
