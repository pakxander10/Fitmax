import SwiftUI

/// Biscuit, drawn from shapes so no image asset is needed. Faces right.
/// Advance `stride` (radians) to wag the tail and, while `walking`, swing the legs and bob the body.
struct DogView: View {
    var stride: Double = 0
    var walking = true

    static let size = CGSize(width: 106, height: 78)

    private let coat = Color(hex: 0xF6BC52)
    private let shade = Color(hex: 0xD98F26)
    private let cream = Color(hex: 0xFFEBC2)
    private let dark = Color(hex: 0x3B2A1A)

    var body: some View {
        let swing = walking ? sin(stride) * 26 : 0
        let fur = LinearGradient(colors: [coat, shade], startPoint: .top, endPoint: .bottom)
        ZStack {
            Ellipse().fill(.black.opacity(0.14)).frame(width: 76, height: 9).position(x: 50, y: 73)
            Group {
                // Tail, wagging from its base on the rump.
                Capsule().fill(shade).frame(width: 7, height: 24)
                    .rotationEffect(.degrees(-40 + sin(stride * 2) * 18), anchor: .bottom)
                    .position(x: 17, y: 25)
                // Far-side legs swing opposite the near-side pair.
                leg(shade, x: 30, angle: -swing)
                leg(shade, x: 66, angle: swing)
                Capsule().fill(fur).frame(width: 64, height: 30).position(x: 46, y: 42)
                Ellipse().fill(cream).frame(width: 40, height: 11).position(x: 46, y: 51)
                Ellipse().fill(.white.opacity(0.45)).frame(width: 40, height: 7).position(x: 44, y: 32)
                leg(coat, x: 24, angle: swing)
                leg(coat, x: 60, angle: -swing)
                // Collar.
                Capsule().fill(Theme.blueGloss).frame(width: 8, height: 22).rotationEffect(.degrees(22)).position(x: 68, y: 36)
                Circle().fill(Color(hex: 0xFFD84D)).frame(width: 5, height: 5).position(x: 71, y: 46)
                // Head.
                Circle().fill(fur).frame(width: 32, height: 32).position(x: 80, y: 24)
                Ellipse().fill(.white.opacity(0.4)).frame(width: 16, height: 7).position(x: 80, y: 13)
                Ellipse().fill(cream).frame(width: 20, height: 14).position(x: 92, y: 30)
                Circle().fill(dark).frame(width: 6, height: 6).position(x: 100, y: 26)
                Circle().fill(dark).frame(width: 5.5, height: 5.5).position(x: 84, y: 20)
                Circle().fill(.white).frame(width: 2, height: 2).position(x: 85, y: 19)
                Ellipse().fill(shade).frame(width: 13, height: 24).rotationEffect(.degrees(18)).position(x: 70, y: 22)
            }
            .offset(y: walking ? abs(sin(stride)) * -1.5 : 0)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .accessibilityHidden(true)
    }

    private func leg(_ color: Color, x: CGFloat, angle: Double) -> some View {
        Capsule().fill(color).frame(width: 10, height: 24)
            .rotationEffect(.degrees(angle), anchor: .top)
            .position(x: x, y: 60)
    }
}

/// A strip of sky and grass for the dog to stand on.
struct DogYard<Content: View>: View {
    var height: CGFloat = 124
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Color(hex: 0xBFE8FF), Color(hex: 0xEAF9FF)], startPoint: .top, endPoint: .bottom)
            Glossy(shape: Rectangle(), fill: LinearGradient(colors: [Color(hex: 0x9BE24A), Color(hex: 0x4FB01F)], startPoint: .top, endPoint: .bottom))
                .frame(height: 22)
            content.padding(.bottom, 12)
        }
        .frame(height: height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white, lineWidth: 1))
    }
}
