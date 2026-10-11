import SwiftUI

/// Biscuit walking the yard.
struct PetPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Seconds for one trip across the yard and back.
    private static let lap: Double = 16

    var body: some View {
        let game = model.game
        Button { model.present(.pet) } label: {
            VStack(spacing: 12) {
                CardTitle(title: "Biscuit", trailing: "\(game.streakDays)-day streak")
                yard
                VStack(spacing: 6) {
                    HStack {
                        Text("Pet level \(game.level)").caption(13, color: Theme.ink)
                        Spacer(minLength: 8)
                        Text("\(game.xpToNextLevel) XP to level \(game.level + 1)").caption()
                    }
                    FQProgressLine(fraction: game.progress)
                }
            }
            .aeroCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Biscuit is feeling \(model.mood.rawValue). Pet level \(game.level), \(game.xpToNextLevel) XP to the next level, \(game.streakDays) day streak.")
        .accessibilityAddTraits(.isButton)
    }

    private var yard: some View {
        DogYard {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
                GeometryReader { geo in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let lapFraction = reduceMotion ? 0.2 : time.truncatingRemainder(dividingBy: Self.lap) / Self.lap
                    let outbound = lapFraction < 0.5
                    let travel = max(0, geo.size.width - DogView.size.width - 24)
                    let x = 12 + (outbound ? lapFraction * 2 : 2 - lapFraction * 2) * travel
                    ZStack(alignment: .bottomLeading) {
                        DogView(stride: reduceMotion ? 0 : time * 8)
                            .scaleEffect(x: outbound ? 1 : -1, y: 1)
                            .offset(x: x)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
        }
    }
}
