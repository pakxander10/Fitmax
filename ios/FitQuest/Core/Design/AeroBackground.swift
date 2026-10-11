import SwiftUI

/// The sky every screen sits on: deep azure easing to aqua, crossed by soft aurora ribbons
/// of light that drift slowly, Vista-style. Ribbons stay below the top third, where page titles are.
struct AeroBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Theme.skyTop, location: 0),
                        .init(color: Theme.skyMid, location: 0.35),
                        .init(color: Theme.skyLow, location: 0.72),
                        .init(color: Theme.horizon, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                // Light source behind the ribbons, upper right.
                RadialGradient(
                    colors: [Color(hex: 0x8FE9FF).opacity(0.45), .clear],
                    center: UnitPoint(x: 0.85, y: 0.28), startRadius: 0, endRadius: geo.size.width * 0.9
                )
                AuroraRibbons(size: geo.size)
            }
            // The ribbon layer is wider than the screen so it can sway; keep it from sizing anything.
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// The ribbons and their slow sway. The animation state lives here, not on `AeroBackground`,
/// so screens that host the background are not re-laid out by it.
private struct AuroraRibbons: View {
    let size: CGSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    /// Vertical centre, wave height, thickness, waves across the screen, phase, colour.
    private static let ribbons: [(y: CGFloat, amplitude: CGFloat, thickness: CGFloat, waves: CGFloat, phase: CGFloat, color: Color)] = [
        (0.34, 0.07, 0.10, 0.8, 0.0, Color(hex: 0x9FF3FF)),
        (0.47, 0.09, 0.16, 0.6, 1.6, Color(hex: 0x5FD8FF)),
        (0.58, 0.06, 0.07, 1.1, 3.4, Color(hex: 0xC8FF9A)),
        (0.72, 0.08, 0.18, 0.7, 4.8, .white),
    ]

    var body: some View {
        ribbons(in: size)
            .offset(x: drift ? -size.width * 0.06 : size.width * 0.06)
            .scaleEffect(y: drift ? 1.04 : 0.97)
            .onAppear {
                guard !reduceMotion else { return }
                // One slow sway, done by Core Animation on the flattened layer, so it costs almost nothing per frame.
                withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) { drift = true }
            }
    }

    private func ribbons(in size: CGSize) -> some View {
        ZStack {
            ForEach(Self.ribbons.indices, id: \.self) { index in
                let ribbon = Self.ribbons[index]
                let band = Ribbon(center: ribbon.y, amplitude: ribbon.amplitude, thickness: ribbon.thickness, waves: ribbon.waves, phase: ribbon.phase)
                let glow = LinearGradient(
                    stops: [
                        .init(color: ribbon.color.opacity(0), location: 0),
                        .init(color: ribbon.color.opacity(0.85), location: 0.45),
                        .init(color: ribbon.color.opacity(0.6), location: 0.7),
                        .init(color: ribbon.color.opacity(0), location: 1),
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
                ZStack {
                    band.fill(glow).blur(radius: 12)
                    // A thin bright edge along the top of each band, the "light streak" look.
                    RibbonEdge(center: ribbon.y, amplitude: ribbon.amplitude, waves: ribbon.waves, phase: ribbon.phase)
                        .stroke(glow, lineWidth: 1.5)
                        .blur(radius: 0.6)
                        .opacity(0.9)
                }
            }
        }
        .frame(width: size.width * 1.3, height: size.height)
        .drawingGroup()
        // Screen-blended onto the sky after flattening, so the ribbons read as light, not paint.
        .blendMode(.screen)
    }
}

/// A wavy band across the full width.
private struct Ribbon: Shape {
    let center: CGFloat
    let amplitude: CGFloat
    let thickness: CGFloat
    let waves: CGFloat
    let phase: CGFloat

    func path(in rect: CGRect) -> Path {
        let steps = 48
        func top(_ t: CGFloat) -> CGPoint { RibbonEdge.point(t, rect, center, amplitude, waves, phase) }
        // Thickness swells and thins along the band, like light folding.
        func bottom(_ t: CGFloat) -> CGPoint {
            let p = top(t)
            return CGPoint(x: p.x, y: p.y + rect.height * thickness * (0.55 + 0.45 * sin(t * .pi * 2 * waves + phase * 1.7)))
        }
        var path = Path()
        path.move(to: top(0))
        for i in 1...steps { path.addLine(to: top(CGFloat(i) / CGFloat(steps))) }
        for i in stride(from: steps, through: 0, by: -1) { path.addLine(to: bottom(CGFloat(i) / CGFloat(steps))) }
        path.closeSubpath()
        return path
    }
}

/// The top edge of a ribbon, as a line.
private struct RibbonEdge: Shape {
    let center: CGFloat
    let amplitude: CGFloat
    let waves: CGFloat
    let phase: CGFloat

    static func point(_ t: CGFloat, _ rect: CGRect, _ center: CGFloat, _ amplitude: CGFloat, _ waves: CGFloat, _ phase: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * t, y: rect.minY + rect.height * (center + amplitude * sin(t * .pi * 2 * waves + phase)))
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: Self.point(0, rect, center, amplitude, waves, phase))
        for i in 1...48 { path.addLine(to: Self.point(CGFloat(i) / 48, rect, center, amplitude, waves, phase)) }
        return path
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
