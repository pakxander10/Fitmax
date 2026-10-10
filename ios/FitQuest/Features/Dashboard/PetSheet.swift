import SwiftUI

struct PetSheet: View {
    @Environment(AppModel.self) private var model

    private static let shop: [(name: String, kind: String, cost: Int, owned: Bool)] = [
        ("Molsheim garage", "BACKGROUND", 200, true),
        ("Night track", "BACKGROUND", 350, false),
        ("Racing collar", "ACCESSORY", 120, true),
        ("Carbon kennel", "INTERIOR", 600, false),
    ]

    private static let achievements: [(name: String, earned: Bool)] = [
        ("First scan", true),
        ("7-day streak", false),
        ("100 meals logged", false),
        ("Visit a friend’s pet", true),
    ]

    var body: some View {
        FQOverlay(title: "Biscuit", onBack: { model.overlay = nil }) {
            VStack(alignment: .leading, spacing: 32) {
                PhotoPlaceholder(label: "Pet · dog", ratio: 4.0 / 3.0, bordered: true)
                HStack(alignment: .top, spacing: 16) {
                    SpecCell(value: model.mood.label, label: "MOOD")
                    SpecCell(value: "\(model.game.level)", label: "LEVEL")
                    SpecCell(value: "\(model.points)", label: "POINTS")
                }
                Text("Biscuit is happy when you hit your goals and evolves when you level up. Earn points at the gym and by following your plan.")
                    .serif(14)
                VStack(alignment: .leading, spacing: 0) {
                    Text("SHOP").mono(color: Theme.ink)
                    ForEach(Self.shop, id: \.name) { item in
                        FQRow {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).serif(color: Theme.ink)
                                Text(item.kind).mono()
                            }
                            Spacer(minLength: 0)
                            Text(item.owned ? "OWNED" : "\(item.cost) PTS").mono(color: Theme.ink)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("ACHIEVEMENTS").mono(color: Theme.ink)
                    ForEach(Self.achievements, id: \.name) { item in
                        FQRow {
                            FQCheck(on: item.earned, size: 18)
                            Text(item.name).serif(color: item.earned ? Theme.ink : Theme.muted)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(item.earned ? "Earned" : "Not earned")
                    }
                }
            }
        }
    }
}
