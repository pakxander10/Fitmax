import SwiftUI

/// Frutiger Aero tokens: a bright sky behind frosted-glass panels, with glossy aqua and
/// green controls. Dark navy text sits on glass; white text sits only on the top of the sky.
enum Theme {
    // MARK: Sky

    static let skyTop = Color(hex: 0x0E78DA)
    static let skyMid = Color(hex: 0x38B2F4)
    static let skyLow = Color(hex: 0x9CE6F4)
    static let meadow = Color(hex: 0xC9F6C6)

    // MARK: Text

    static let ink = Color(hex: 0x0A3560)
    static let body = Color(hex: 0x25557A)
    static let muted = Color(hex: 0x4C7391)
    static let onSky = Color.white
    static let link = Color(hex: 0x0A66C8)

    // MARK: Surfaces

    static let divider = Color(hex: 0x0A3560).opacity(0.12)
    static let well = Color(hex: 0xD9F0FF)
    static let glass = LinearGradient(
        colors: [.white.opacity(0.96), Color(hex: 0xE4F5FF).opacity(0.88)],
        startPoint: .top, endPoint: .bottom
    )

    // MARK: Accents

    static let aqua = Color(hex: 0x35AEEF)
    static let azure = Color(hex: 0x0A5FC0)
    static let lime = Color(hex: 0x5DBE1A)
    static let green = Color(hex: 0x1C7F10)
    static let warning = Color(hex: 0xC76A00)
    static let success = green

    static let blueGloss = LinearGradient(colors: [aqua, azure], startPoint: .top, endPoint: .bottom)
    static let greenGloss = LinearGradient(colors: [lime, green], startPoint: .top, endPoint: .bottom)
    static let pearlGloss = LinearGradient(colors: [.white, Color(hex: 0xCDEAFF)], startPoint: .top, endPoint: .bottom)
    /// Soft green wash for "done" tiles that still need dark text on top.
    static let leafWash = LinearGradient(colors: [Color(hex: 0xDFF9B8), Color(hex: 0xA9E660)], startPoint: .top, endPoint: .bottom)

    // MARK: Type

    // Avenir Next ships with iOS and is Adrian Frutiger's own design, so nothing is bundled.
    static func heading(_ size: CGFloat) -> Font { .custom("AvenirNext-DemiBold", size: size) }
    static func copy(_ size: CGFloat) -> Font { .custom("AvenirNext-Regular", size: size) }
    static func caption(_ size: CGFloat) -> Font { .custom("AvenirNext-Medium", size: size) }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension View {
    /// Titles and figures.
    func heading(_ size: CGFloat = 30, color: Color = Theme.ink) -> some View {
        font(Theme.heading(size)).foregroundStyle(color)
    }

    /// Running text.
    func copy(_ size: CGFloat = 16, color: Color = Theme.body) -> some View {
        font(Theme.copy(size)).foregroundStyle(color)
    }

    /// Small labels: metadata, units, captions.
    func caption(_ size: CGFloat = 12, color: Color = Theme.muted) -> some View {
        font(Theme.caption(size)).foregroundStyle(color)
    }

    /// Lifts white text off the sky.
    func skyShadow() -> some View {
        shadow(color: Theme.ink.opacity(0.35), radius: 2, y: 1)
    }

    /// Frosted-glass panel behind a section of content.
    func aeroCard(horizontal: CGFloat = 16, vertical: CGFloat = 16) -> some View {
        padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { GlassPanel() }
    }

    func numericKeyboard(decimal: Bool = false) -> some View {
        #if os(iOS)
        keyboardType(decimal ? .decimalPad : .numberPad)
        #else
        self
        #endif
    }
}

extension EnvironmentValues {
    /// Lays scrolling screens out at full height instead of inside a `ScrollView`,
    /// which `ImageRenderer` cannot capture. Only the render tests turn this on.
    @Entry var flatScroll = false
}
