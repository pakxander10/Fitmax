import SwiftUI

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct Hairline: View {
    var color = Theme.divider

    var body: some View {
        color.frame(height: 1)
    }
}

/// Glossy pill. Primary is green for the one main action; secondary is pearl.
struct FQButton: View {
    enum Variant { case primary, secondary }

    let title: String
    var variant = Variant.primary
    var compact = false
    /// Stretches to the full width on offer, for the one button that ends a form.
    var wide = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .heading(16, color: variant == .primary ? .white : Theme.link)
                .shadow(color: variant == .primary ? Theme.green.opacity(0.7) : .clear, radius: 1, y: 1)
                .lineLimit(1)
                .padding(.horizontal, compact ? 18 : 26)
                .frame(maxWidth: wide ? .infinity : nil)
                .frame(height: 44)
                .background {
                    Glossy(shape: Capsule(), fill: variant == .primary ? Theme.greenGloss : Theme.pearlGloss)
                        .overlay(Capsule().strokeBorder(variant == .primary ? .clear : Theme.aqua.opacity(0.6), lineWidth: 1))
                        .shadow(color: Theme.azure.opacity(0.28), radius: 6, y: 3)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
        .opacity(isEnabled ? 1 : 0.45)
    }
}

/// Glossy blue orb holding one SF Symbol.
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
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background {
                Glossy(shape: Circle(), fill: Theme.blueGloss)
                    .shadow(color: Theme.azure.opacity(0.35), radius: 5, y: 3)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}

/// A figure over its label, in a pale inset tile.
struct SpecCell: View {
    let value: String
    let label: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        VStack(alignment: .leading, spacing: 2) {
            Text(value).heading(22).lineLimit(1).minimumScaleFactor(0.5)
            Text(label).caption().lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(Theme.well.opacity(0.8)))
        .overlay(shape.strokeBorder(.white, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Stand-in for imagery that has not been supplied yet.
struct PhotoPlaceholder: View {
    let label: String
    var ratio: CGFloat = 16.0 / 9.0
    var symbol = "photo"

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        shape
            .fill(LinearGradient(colors: [Color(hex: 0xCDEFFF), Color(hex: 0x8FD6F8)], startPoint: .top, endPoint: .bottom))
            .aspectRatio(ratio, contentMode: .fit)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: symbol).font(.system(size: 28, weight: .light)).foregroundStyle(.white)
                    Text(label).caption(color: Theme.ink.opacity(0.7))
                }
            }
            .overlay(shape.strokeBorder(.white, lineWidth: 1))
            .accessibilityElement(children: .ignore)
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
            Circle().stroke(Theme.ink.opacity(0.1), lineWidth: 12)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    LinearGradient(colors: [Theme.aqua, Theme.lime], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.aqua.opacity(0.5), radius: 4)
                .animation(.easeInOut(duration: 0.6), value: fraction)
            VStack(spacing: 0) {
                // String() keeps the figure free of locale grouping.
                Text(String(value)).heading(size * 0.2).contentTransition(.numericText())
                Text("of \(String(max)) kcal").caption()
            }
        }
        .frame(width: size - 12, height: size - 12)
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) of \(max) kilocalories, estimate")
    }
}

struct FQBar: View {
    let label: String
    let value: Int
    let max: Int
    var unit = "g"

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(label).caption(13, color: Theme.ink)
                Spacer(minLength: 4)
                Text("\(value) / \(max) \(unit)").caption().lineLimit(1).minimumScaleFactor(0.7)
            }
            FQProgressLine(fraction: Double(value) / Double(Swift.max(1, max)), fill: Theme.blueGloss)
        }
        .accessibilityElement(children: .combine)
    }
}

struct FQProgressLine: View {
    let fraction: Double
    var fill = Theme.greenGloss

    var body: some View {
        Capsule()
            .fill(Theme.ink.opacity(0.1))
            .frame(height: 8)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Glossy(shape: Capsule(), fill: fill)
                        .frame(width: Swift.max(8, geo.size.width * Swift.max(0, Swift.min(1, fraction))))
                }
            }
            .animation(.easeInOut(duration: 0.6), value: fraction)
    }
}

/// A labelled white well around one text field. Pass the field itself, so the caller keeps
/// its focus binding and keyboard settings.
struct FQField<Content: View>: View {
    let label: String
    var focused = false
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        VStack(alignment: .leading, spacing: 6) {
            Text(label).caption(13, color: Theme.ink).accessibilityHidden(true)
            content
                .font(Theme.copy(17))
                .foregroundStyle(Theme.ink)
                .tint(Theme.azure)
                .textFieldStyle(.plain)
                .accessibilityLabel(label)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(shape.fill(.white))
                .overlay(shape.strokeBorder(focused ? Theme.azure : Theme.aqua.opacity(0.6), lineWidth: focused ? 1.5 : 1))
        }
    }
}

/// A pill that is either picked or not: one of a set of choices.
struct FQChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .caption(14, color: selected ? .white : Theme.link)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(minWidth: 40, minHeight: 38)
                .background {
                    if selected {
                        Glossy(shape: Capsule(), fill: Theme.blueGloss)
                    } else {
                        Capsule().fill(.white).overlay(Capsule().strokeBorder(Theme.aqua.opacity(0.6), lineWidth: 1))
                    }
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Rounded tick box that turns glossy green when on. Pass no action for a read-only mark.
struct FQCheck: View {
    let on: Bool
    var size: CGFloat = 24
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
        let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        return ZStack {
            if on {
                Glossy(shape: shape, fill: Theme.greenGloss)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                shape.fill(.white).overlay(shape.strokeBorder(Theme.ink.opacity(0.28), lineWidth: 1))
            }
        }
        .frame(width: size, height: size)
        .animation(.easeOut(duration: 0.18), value: on)
    }
}

/// Glossy orb with initials. `active` adds a green ring.
struct FQAvatar: View {
    let initials: String
    var size: CGFloat = 48
    var active = false

    var body: some View {
        Glossy(shape: Circle(), fill: Theme.blueGloss)
            .overlay {
                Text(initials)
                    .heading(Swift.max(7, size * 0.32), color: .white)
                    .shadow(color: Theme.azure.opacity(0.6), radius: 1, y: 1)
            }
            .padding(active ? 3 : 0)
            .overlay { if active { Circle().strokeBorder(Theme.lime, lineWidth: 3) } }
            .frame(width: size, height: size)
            .shadow(color: Theme.azure.opacity(0.25), radius: size * 0.08, y: size * 0.05)
    }
}

/// List row: 56pt minimum, with a divider underneath unless it is the last in its card.
struct FQRow<Content: View>: View {
    var alignment = VerticalAlignment.center
    var divider = true
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: alignment, spacing: 12) { content }
            // Take the wrapped height before the minimum-height frame can squeeze text to one line.
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .overlay(alignment: .bottom) { if divider { Hairline() } }
    }
}

/// Page title block. Sits directly on the top of the sky, so it is white.
struct FQHead: View {
    var index: String?
    let title: String
    var meta: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let index { Text(index).caption(13, color: Theme.onSky.opacity(0.9)) }
            Text(title).heading(color: Theme.onSky).accessibilityAddTraits(.isHeader)
            if let meta { Text(meta).copy(15, color: Theme.onSky.opacity(0.95)) }
        }
        .skyShadow()
    }
}

/// Title row at the top of a card.
struct CardTitle: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).heading(18).accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let trailing { Text(trailing).caption() }
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

/// Full-screen sheet with a back button and a centred title.
struct FQOverlay<Content: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder var content: Content

    @Environment(\.flatScroll) private var flat

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                FQIconButton(label: "Back", symbol: "chevron.left", action: onBack)
                Text(title)
                    .heading(18, color: Theme.onSky)
                    .skyShadow()
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 8)

            if flat {
                padded
            } else {
                ScrollView { padded }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: flat ? nil : .infinity, alignment: .top)
        .background { AeroBackground() }
    }

    private var padded: some View {
        content
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Dimmed backdrop holding one centred glass card. Tapping the backdrop closes it.
struct FQScrim<Content: View>: View {
    let onClose: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Theme.ink.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .accessibilityLabel("Close")
                .accessibilityAddTraits(.isButton)
            content
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { GlassPanel(radius: 24) }
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
