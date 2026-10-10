import SwiftUI

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.55 : 1)
    }
}

struct Hairline: View {
    var color = Theme.hairline

    var body: some View {
        color.frame(height: 1)
    }
}

/// Transparent pill with a 1px white outline. Never filled.
struct FQButton: View {
    enum Variant { case primary, ghost }

    let title: String
    var variant = Variant.primary
    var compact = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .mono(14, tracking: 2.5, color: Theme.ink)
                .lineLimit(1)
                .padding(.horizontal, compact ? 20 : 32)
                .frame(height: 44)
                .overlay(Capsule().strokeBorder(variant == .primary ? Theme.white : .clear, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
        .opacity(isEnabled ? 1 : 0.4)
    }
}

/// Circular 40pt outline button holding one SF Symbol.
struct FQIconButton: View {
    let label: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { FQIconGlyph(symbol: symbol) }
            .buttonStyle(PressStyle())
            .accessibilityLabel(label)
    }
}

struct FQIconGlyph: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .light))
            .foregroundStyle(Theme.ink)
            .frame(width: 40, height: 40)
            .overlay(Circle().strokeBorder(Theme.white, lineWidth: 1))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}

/// A figure over its mono unit label, with a hairline above.
struct SpecCell: View {
    let value: String
    let label: String
    var padding: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value).display().lineLimit(1).minimumScaleFactor(0.5)
            Text(label).mono().lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.vertical, padding)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Hairline() }
        .accessibilityElement(children: .combine)
    }
}

/// Square-cornered stand-in for imagery that has not been supplied yet.
struct PhotoPlaceholder: View {
    let label: String
    var ratio: CGFloat = 16.0 / 9.0
    var bordered = false

    var body: some View {
        Rectangle()
            .fill(Theme.surfaceSoft)
            .aspectRatio(ratio, contentMode: .fit)
            .overlay { Text(label).mono(color: Theme.mutedSoft) }
            .overlay { if bordered { Rectangle().strokeBorder(Theme.hairline, lineWidth: 1) } }
            .accessibilityLabel(label)
    }
}

struct FQRing: View {
    let value: Int
    let max: Int
    var size: CGFloat = 168

    private var fraction: Double { Swift.max(0, Swift.min(1, Double(value) / Double(Swift.max(1, max)))) }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.hairline, lineWidth: 6)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Theme.white, lineWidth: 6)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: fraction)
            VStack(spacing: 2) {
                // String() keeps the figure free of locale grouping, matching the design.
                Text(String(value)).display(30, tracking: 1).contentTransition(.numericText())
                Text("/ \(String(max)) KCAL").mono()
            }
        }
        .frame(width: size - 14, height: size - 14)
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) of \(max) kilocalories, estimate")
    }
}

struct FQBar: View {
    let label: String
    let value: Int
    let max: Int
    var unit = "G"

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label).mono(color: Theme.ink)
                Spacer(minLength: 4)
                Text("\(value) / \(max) \(unit)").mono().lineLimit(1).minimumScaleFactor(0.7)
            }
            FQProgressLine(fraction: Double(value) / Double(Swift.max(1, max)))
        }
        .accessibilityElement(children: .combine)
    }
}

struct FQProgressLine: View {
    let fraction: Double

    var body: some View {
        Theme.hairline
            .frame(height: 2)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Theme.white.frame(width: geo.size.width * Swift.max(0, Swift.min(1, fraction)))
                }
            }
            .animation(.easeInOut(duration: 0.6), value: fraction)
    }
}

/// Square tick box that fills green when on. Pass no action for a read-only mark.
struct FQCheck: View {
    let on: Bool
    var size: CGFloat = 22
    var label = ""
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { box.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) }
                .buttonStyle(PressStyle())
                .accessibilityLabel(label)
                .accessibilityAddTraits(on ? .isSelected : [])
        } else {
            box.accessibilityHidden(true)
        }
    }

    private var box: some View {
        Rectangle()
            .fill(on ? Theme.success : .clear)
            .overlay(Rectangle().strokeBorder(on ? Theme.success : Theme.hairlineStrong, lineWidth: 1))
            .overlay {
                if on {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.5, weight: .regular))
                        .foregroundStyle(.black)
                }
            }
            .frame(width: size, height: size)
            .animation(.easeOut(duration: 0.18), value: on)
    }
}

struct FQAvatar: View {
    let initials: String
    var size: CGFloat = 48
    var fill = Theme.surfaceCard
    var border = Theme.hairlineStrong
    var borderWidth: CGFloat = 1

    var body: some View {
        Circle()
            .fill(fill)
            .overlay(Circle().strokeBorder(border, lineWidth: borderWidth))
            .overlay { Text(initials).mono(Swift.max(8, size * 0.26), tracking: 1, color: Theme.ink) }
            .frame(width: size, height: size)
    }
}

/// List row: 56pt minimum, hairline underneath.
struct FQRow<Content: View>: View {
    var alignment = VerticalAlignment.center
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: alignment, spacing: 12) { content }
            // Take the wrapped height before the minimum-height frame can squeeze text to one line.
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .overlay(alignment: .bottom) { Hairline() }
    }
}

struct FQHead: View {
    var index: String?
    let title: String
    var meta: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let index { Text(index).mono() }
            Text(title).display().accessibilityAddTraits(.isHeader)
            if let meta { Text(meta).serif(14, color: Theme.muted) }
        }
    }
}

/// Vertical scroller for one of the four top-level pages. Leaves room for the nav dots.
struct PageScroll<Content: View>: View {
    @Environment(\.flatScroll) private var flat
    @ViewBuilder var content: Content

    var body: some View {
        if flat {
            content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// Full-screen sheet with a back button and a centred mono title.
struct FQOverlay<Content: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder var content: Content

    @Environment(\.flatScroll) private var flat

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                FQIconButton(label: "Back", symbol: "arrow.left", action: onBack)
                Text(title).mono(color: Theme.ink).frame(maxWidth: .infinity)
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 10)

            if flat {
                padded
            } else {
                ScrollView { padded }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: flat ? nil : .infinity, alignment: .top)
        .background(Theme.canvas.ignoresSafeArea())
    }

    private var padded: some View {
        content
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Dimmed backdrop holding one centred card. Tapping the backdrop closes it.
struct FQScrim<Content: View>: View {
    let onClose: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.82)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .accessibilityLabel("Close")
                .accessibilityAddTraits(.isButton)
            content
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surfaceCard)
                .padding(20)
        }
    }
}

/// Wraps children onto new lines when they run out of width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let origins = arrange(width: bounds.width, subviews).origins
        for (subview, origin) in zip(subviews, origins) {
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, _ subviews: Subviews) -> (origins: [CGPoint], size: CGSize) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (origins, CGSize(width: widest, height: y + lineHeight))
    }
}

/// Splits its width between children by weight and stretches them to a common height.
struct WeightedRow: Layout {
    let weights: [CGFloat]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let heights = zip(subviews, widths(in: width)).map { subview, cell in
            subview.sizeThatFits(ProposedViewSize(width: cell, height: nil)).height
        }
        return CGSize(width: width, height: heights.max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (subview, cell) in zip(subviews, widths(in: bounds.width)) {
            subview.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: cell, height: bounds.height))
            x += cell
        }
    }

    private func widths(in total: CGFloat) -> [CGFloat] {
        let sum = max(weights.reduce(0, +), 1)
        return weights.map { total * $0 / sum }
    }
}
