import CoreText
import SwiftUI

/// Design tokens: a monochrome black canvas with white display type, serif body and mono labels.
/// Weight 400 everywhere; emphasis comes from size, tracking, case and family.
enum Theme {
    // MARK: Colour

    static let white = Color(hex: 0xFFFFFF)
    static let ink = Color(hex: 0xFFFFFF)
    static let body = Color(hex: 0xCCCCCC)
    static let bodyStrong = Color(hex: 0xE6E6E6)
    static let muted = Color(hex: 0x999999)
    static let mutedSoft = Color(hex: 0x666666)

    static let canvas = Color(hex: 0x000000)
    static let surfaceSoft = Color(hex: 0x0D0D0D)
    static let surfaceCard = Color(hex: 0x141414)
    static let surfaceElevated = Color(hex: 0x1F1F1F)

    static let hairline = Color(hex: 0x262626)
    static let hairlineStrong = Color(hex: 0x3A3A3A)

    static let link = Color(hex: 0xC3D9F3)
    static let warning = Color(hex: 0xD4A017)
    static let success = Color(hex: 0x5FA657)

    // MARK: Type

    static func display(_ size: CGFloat) -> Font { font("SairaCondensed-Regular", size) }
    static func text(_ size: CGFloat) -> Font { font("EBGaramond-Regular", size) }
    static func mono(_ size: CGFloat) -> Font { font("JetBrainsMono-Regular", size) }

    private static func font(_ name: String, _ size: CGFloat) -> Font {
        _ = registerFonts
        return .custom(name, size: size)
    }

    /// Registers the bundled fonts on first use, so previews and tests need no setup.
    private static let registerFonts: Void = {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        for url in bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()
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
    /// Uppercase tracked headline. 32/2 is the page title, 20/1 a section title, 16/1.5 a row title.
    func display(_ size: CGFloat = 32, tracking: CGFloat = 2, color: Color = Theme.ink) -> some View {
        font(Theme.display(size)).tracking(tracking).textCase(.uppercase).foregroundStyle(color)
    }

    /// Sentence-case serif running text.
    func serif(_ size: CGFloat = 16, color: Color = Theme.body) -> some View {
        font(Theme.text(size)).foregroundStyle(color)
    }

    /// Uppercase mono label for metadata, units and captions.
    func mono(_ size: CGFloat = 11, tracking: CGFloat = 2, color: Color = Theme.muted) -> some View {
        font(Theme.mono(size)).tracking(tracking).textCase(.uppercase).foregroundStyle(color)
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
