import SwiftUI

/// Biscuit walking the yard, with a thought bubble showing a fresh emoji for the current mood.
struct PetPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var emoji = ""
    @State private var bubbleShown = true

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
        .task { await cycleBubble() }
        .onChange(of: model.mood) { emoji = model.mood.randomEmoji() }
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
                        bubble
                            .offset(x: x + (outbound ? 62 : 6), y: -(DogView.size.height - 14))
                            .opacity(bubbleShown ? 1 : 0)
                            .animation(.easeOut(duration: 0.25), value: bubbleShown)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
        }
    }

    private var bubble: some View {
        Text(emoji.isEmpty ? model.mood.emojis[0] : emoji)
            .font(.system(size: 20))
            .frame(width: 38, height: 38)
            .background(Circle().fill(.white).shadow(color: Theme.azure.opacity(0.3), radius: 4, y: 2))
            .overlay(Circle().strokeBorder(Theme.aqua.opacity(0.5), lineWidth: 1))
            .overlay(alignment: .bottomLeading) {
                Circle().fill(.white).frame(width: 8, height: 8).offset(x: -2, y: 5)
            }
    }

    /// Shows a face for a few seconds, hides it, then comes back with a different one.
    private func cycleBubble() async {
        emoji = model.mood.randomEmoji()
        while !Task.isCancelled {
            bubbleShown = true
            try? await Task.sleep(for: .seconds(4))
            bubbleShown = false
            try? await Task.sleep(for: .seconds(2))
            emoji = model.mood.randomEmoji(excluding: emoji)
        }
    }
}
