import SwiftUI

/// The sky every screen sits on: azure fading to a mint horizon, a sun glow, a soft
/// swoosh of light, and a scatter of glassy bubbles.
struct AeroBackground: View {
    /// Position and diameter of each bubble, as fractions of the screen and points.
    /// None sit in the top-left fifth of the screen, where page titles are.
    private static let bubbles: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (0.97, 0.19, 22), (0.05, 0.33, 44), (0.93, 0.28, 26), (0.72, 0.40, 74),
        (0.08, 0.53, 36), (0.91, 0.63, 52), (0.28, 0.79, 90), (0.80, 0.90, 40),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Theme.skyTop, location: 0),
                        .init(color: Theme.skyMid, location: 0.38),
                        .init(color: Theme.skyLow, location: 0.74),
                        .init(color: Theme.meadow, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                RadialGradient(
                    colors: [.white.opacity(0.5), .white.opacity(0)],
                    center: UnitPoint(x: 0.88, y: 0.06), startRadius: 0, endRadius: 280
                )
                Ellipse()
                    .fill(LinearGradient(colors: [.white.opacity(0.24), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .frame(width: geo.size.width * 2.2, height: 420)
                    .rotationEffect(.degrees(-14))
                    .position(x: geo.size.width * 0.3, y: geo.size.height * 0.62)
                ForEach(Self.bubbles.indices, id: \.self) { index in
                    let bubble = Self.bubbles[index]
                    Bubble(size: bubble.size)
                        .position(x: geo.size.width * bubble.x, y: geo.size.height * bubble.y)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct Bubble: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(RadialGradient(
                colors: [.white.opacity(0.02), .white.opacity(0.3)],
                center: .center, startRadius: size * 0.2, endRadius: size * 0.5
            ))
            .overlay(Circle().strokeBorder(.white.opacity(0.55), lineWidth: 1))
            .overlay(alignment: .topLeading) {
                Ellipse()
                    .fill(.white.opacity(0.7))
                    .frame(width: size * 0.28, height: size * 0.16)
                    .rotationEffect(.degrees(-35))
                    .offset(x: size * 0.16, y: size * 0.14)
            }
            .frame(width: size, height: size)
    }
}

/// Frosted white panel with a bright rim and a soft blue drop shadow.
struct GlassPanel: View {
    var radius: CGFloat = 22

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape
            .fill(Theme.glass)
            .overlay(shape.strokeBorder(.white.opacity(0.95), lineWidth: 1))
            .shadow(color: Theme.azure.opacity(0.26), radius: 14, y: 8)
    }
}

/// A gradient fill with the hard half-height highlight that makes Aero controls look wet.
struct Glossy<S: InsettableShape>: View {
    let shape: S
    let fill: LinearGradient

    var body: some View {
        shape
            .fill(fill)
            .overlay {
                shape.fill(LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.55), location: 0),
                        .init(color: .white.opacity(0.12), location: 0.5),
                        .init(color: .white.opacity(0), location: 0.5),
                    ],
                    startPoint: .top, endPoint: .bottom
                ))
            }
            .overlay(shape.strokeBorder(.white.opacity(0.75), lineWidth: 1))
    }
}
