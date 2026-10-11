import SwiftUI

/// Biscuit, a lean, athletic dog drawn from paths so no image asset is needed. Faces right.
/// Advance `stride` (radians) to swing the tail and, while `walking`, the legs and a slight body bob.
struct DogView: View {
    var stride: Double = 0
    var walking = true

    static let size = CGSize(width: 106, height: 78)

    private let coat = LinearGradient(colors: [Color(hex: 0x4A5D73), Color(hex: 0x1E2935)], startPoint: .top, endPoint: .bottom)
    private let farCoat = Color(hex: 0x18212B)
    private let tan = Color(hex: 0xC98A45)
    private let dark = Color(hex: 0x0D1218)

    var body: some View {
        let swing = walking ? sin(stride) * 22 : 0
        ZStack {
            Ellipse().fill(.black.opacity(0.16)).frame(width: 74, height: 7).position(x: 52, y: 74)
            Group {
                // Tail, held out and up, swinging a little.
                // Positioned so the bottom of the capsule, its pivot, sits on the rump.
                Capsule().fill(farCoat).frame(width: 4.5, height: 22)
                    .rotationEffect(.degrees(-58 + sin(stride * 1.5) * 8), anchor: .bottom)
                    .position(x: 21, y: 25)
                // Far-side legs, darker, swinging opposite the near pair.
                leg(x: 30, angle: -swing, far: true)
                leg(x: 72, angle: swing, far: true)
                torso
                leg(x: 25, angle: swing, far: false)
                leg(x: 77, angle: -swing, far: false)
                // Collar: the one glossy Aero accent.
                Capsule().fill(Theme.blueGloss).frame(width: 5, height: 15).rotationEffect(.degrees(28)).position(x: 77, y: 25)
                head
            }
            .offset(y: walking ? abs(sin(stride)) * -1.2 : 0)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .accessibilityHidden(true)
    }

    /// Deep chest, tucked waist, level back.
    private var torso: some View {
        let body = Path { p in
            p.move(to: CGPoint(x: 18, y: 34))
            p.addQuadCurve(to: CGPoint(x: 66, y: 28), control: CGPoint(x: 40, y: 26))
            p.addLine(to: CGPoint(x: 76, y: 16))
            p.addLine(to: CGPoint(x: 84, y: 26))
            p.addQuadCurve(to: CGPoint(x: 76, y: 50), control: CGPoint(x: 86, y: 44))
            p.addQuadCurve(to: CGPoint(x: 44, y: 44), control: CGPoint(x: 58, y: 54))
            p.addQuadCurve(to: CGPoint(x: 18, y: 44), control: CGPoint(x: 30, y: 40))
            p.addQuadCurve(to: CGPoint(x: 18, y: 34), control: CGPoint(x: 13, y: 39))
            p.closeSubpath()
        }
        let chest = Path { p in
            p.move(to: CGPoint(x: 82, y: 32))
            p.addQuadCurve(to: CGPoint(x: 75, y: 49), control: CGPoint(x: 84, y: 44))
            p.addQuadCurve(to: CGPoint(x: 72, y: 38), control: CGPoint(x: 72, y: 44))
            p.closeSubpath()
        }
        let sheen = Path { p in
            p.move(to: CGPoint(x: 24, y: 32))
            p.addQuadCurve(to: CGPoint(x: 66, y: 30), control: CGPoint(x: 42, y: 27))
            p.addQuadCurve(to: CGPoint(x: 26, y: 35), control: CGPoint(x: 44, y: 32))
            p.closeSubpath()
        }
        return ZStack {
            body.fill(coat)
            chest.fill(tan)
            sheen.fill(.white.opacity(0.25))
        }
    }

    /// Long wedge-shaped head with an upright ear and a narrow eye.
    private var head: some View {
        let skull = Path { p in
            p.move(to: CGPoint(x: 74, y: 15))
            p.addQuadCurve(to: CGPoint(x: 88, y: 9), control: CGPoint(x: 79, y: 8))
            p.addLine(to: CGPoint(x: 101, y: 17))
            p.addQuadCurve(to: CGPoint(x: 99, y: 22), control: CGPoint(x: 103, y: 20))
            p.addLine(to: CGPoint(x: 86, y: 25))
            p.addQuadCurve(to: CGPoint(x: 76, y: 24), control: CGPoint(x: 80, y: 27))
            p.closeSubpath()
        }
        let muzzle = Path { p in
            p.move(to: CGPoint(x: 88, y: 20))
            p.addLine(to: CGPoint(x: 99, y: 21))
            p.addLine(to: CGPoint(x: 86, y: 25))
            p.closeSubpath()
        }
        let ear = Path { p in
            p.move(to: CGPoint(x: 76, y: 12))
            p.addLine(to: CGPoint(x: 79, y: 0))
            p.addLine(to: CGPoint(x: 84, y: 10))
            p.closeSubpath()
        }
        let eye = Path { p in
            p.move(to: CGPoint(x: 85, y: 14))
            p.addQuadCurve(to: CGPoint(x: 90, y: 13.5), control: CGPoint(x: 87.5, y: 12))
            p.addQuadCurve(to: CGPoint(x: 85, y: 14), control: CGPoint(x: 87.5, y: 15.5))
        }
        return ZStack {
            ear.fill(farCoat)
            skull.fill(coat)
            muzzle.fill(tan)
            Path { p in p.move(to: CGPoint(x: 80, y: 11)); p.addQuadCurve(to: CGPoint(x: 96, y: 15), control: CGPoint(x: 88, y: 10)) }
                .stroke(.white.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            eye.fill(tan)
            Circle().fill(dark).frame(width: 2.6, height: 2.6).position(x: 87.6, y: 13.8)
            Circle().fill(dark).frame(width: 4, height: 4).position(x: 101, y: 18.5)
        }
    }

    /// A slim leg with a tan lower half, swung from the hip or shoulder.
    private func leg(x: CGFloat, angle: Double, far: Bool) -> some View {
        VStack(spacing: 0) {
            Capsule().fill(far ? AnyShapeStyle(farCoat) : AnyShapeStyle(coat)).frame(width: 8, height: 21)
            Capsule().fill(far ? tan.opacity(0.75) : tan).frame(width: 6, height: 12).offset(y: -5)
        }
        .frame(height: 30, alignment: .top)
        .rotationEffect(.degrees(angle), anchor: .top)
        .position(x: x, y: 59)
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
