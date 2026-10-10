import SwiftUI

/// Biscuit pacing the yard, with a thought bubble that surfaces the current mood every so often.
struct PetPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var walking = false
    @State private var bubbleShown = false

    var body: some View {
        let game = model.game
        Button { model.overlay = .pet } label: {
            VStack(spacing: 14) {
                HStack {
                    Text("PET · BISCUIT").mono(color: Theme.ink)
                    Spacer()
                    Text("\(game.streakDays)-DAY STREAK").mono()
                }
                yard
                VStack(spacing: 8) {
                    HStack {
                        Text("LVL \(game.level) · HUNTER RANK \(game.rank.rawValue)").mono(color: Theme.ink)
                        Spacer(minLength: 8)
                        Text(game.nextRank.map { "\(game.xpToNext) XP TO \($0.rawValue)" } ?? "TOP RANK").mono()
                    }
                    FQProgressLine(fraction: game.progress)
                }
            }
            .padding(16)
            .overlay(Rectangle().strokeBorder(Theme.hairline, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Biscuit is \(model.mood.rawValue). Level \(game.level), Hunter Rank \(game.rank.rawValue), \(game.streakDays) day streak.")
        .accessibilityAddTraits(.isButton)
        .task { await cycleBubble() }
    }

    private var yard: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                Circle()
                    .fill(Theme.surfaceSoft)
                    .overlay(Circle().strokeBorder(Theme.white, lineWidth: 1))
                    .overlay { Text("DOG").mono(9) }
                    .frame(width: 56, height: 56)
                bubble
                    .offset(x: 44, y: -48)
                    .opacity(bubbleShown ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: bubbleShown)
            }
            .offset(x: walking ? max(0, geo.size.width - 160) : 0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 9).repeatForever(autoreverses: true), value: walking)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.bottom, 6)
        }
        .frame(height: 110)
        .overlay(alignment: .bottom) { Hairline(color: Theme.hairlineStrong) }
        .onAppear { walking = true }
    }

    private var bubble: some View {
        HStack(alignment: .bottom, spacing: 4) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach([4.0, 6.0, 8.0], id: \.self) { size in
                    Circle().strokeBorder(Theme.muted, lineWidth: 1).frame(width: size, height: size)
                }
            }
            .padding(.bottom, 2)
            Text(model.mood.label)
                .mono(10, color: Theme.ink)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(Capsule().fill(Theme.canvas))
                .overlay(Capsule().strokeBorder(Theme.white, lineWidth: 1))
        }
        .fixedSize()
    }

    private func cycleBubble() async {
        try? await Task.sleep(for: .milliseconds(1_200))
        while !Task.isCancelled {
            bubbleShown = true
            try? await Task.sleep(for: .seconds(3))
            bubbleShown = false
            try? await Task.sleep(for: .seconds(7))
        }
    }
}
