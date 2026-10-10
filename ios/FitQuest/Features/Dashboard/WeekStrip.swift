import SwiftUI

/// Seven days around a focus day. Drag sideways or tap a day to move the focus.
struct WeekStrip: View {
    @Environment(AppModel.self) private var model

    @State private var offset = 0
    @State private var dragAnchor: CGFloat = 0

    private static let weights: [CGFloat] = [1, 1, 1, 2.4, 1, 1, 1]
    private static let stepWidth: CGFloat = 40

    var body: some View {
        let center = model.today.adding(offset)
        VStack(spacing: 10) {
            HStack {
                Text("7-DAY PROGRESS").mono(color: Theme.ink)
                Spacer()
                if offset == 0 {
                    Text("DRAG TO MOVE").mono()
                } else {
                    Button { offset = 0 } label: { Text("BACK TO TODAY").mono(color: Theme.ink) }
                        .buttonStyle(PressStyle())
                }
            }
            WeightedRow(weights: Self.weights) {
                ForEach(-3...3, id: \.self) { delta in
                    cell(center.adding(delta), focused: delta == 0)
                        .overlay(alignment: .trailing) {
                            if delta < 3 { Theme.hairline.frame(width: 1) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { offset += delta }
                }
            }
            .overlay(Rectangle().strokeBorder(Theme.hairlineStrong, lineWidth: 1))
            .highPriorityGesture(drag)
            .sensoryFeedback(.selection, trigger: offset)
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let moved = value.translation.width - dragAnchor
                guard abs(moved) > Self.stepWidth else { return }
                offset += moved > 0 ? -1 : 1
                dragAnchor = value.translation.width
            }
            .onEnded { _ in dragAnchor = 0 }
    }

    private func cell(_ day: Day, focused: Bool) -> some View {
        let status = model.status(for: day)
        let onDone = Color.black
        return VStack(alignment: focused ? .leading : .center, spacing: 4) {
            Text(focused ? day.relativeLabel(to: model.today) : day.weekdayShort)
                .mono(focused ? 11 : 9, tracking: focused ? 2 : 1, color: status.both ? onDone : focused ? Theme.ink : Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(focused ? "\(day.weekdayShort) \(day.dayOfMonth) \(day.monthShort)" : day.dayOfMonth)
                .display(focused ? 16 : 14, tracking: 1, color: status.both ? onDone : Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            VStack(alignment: .leading, spacing: 6) {
                mark("CALORIES", on: status.calories, both: status.both, focused: focused)
                mark("WORKOUT", on: status.workout, both: status.both, focused: focused)
            }
            .padding(.top, 4)
        }
        .padding(.top, 10)
        .padding(.bottom, 12)
        .padding(.horizontal, focused ? 12 : 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: focused ? .topLeading : .top)
        .background(status.both ? Theme.success : focused ? Theme.surfaceCard : .clear)
        .opacity(day > model.today && !focused ? 0.5 : 1)
        .animation(.easeOut(duration: 0.2), value: status)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.weekdayName) \(day.dayOfMonth). Calories \(status.calories ? "on target" : "not met"), workout \(status.workout ? "done" : "not done").")
    }

    private func mark(_ label: String, on: Bool, both: Bool, focused: Bool) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(both ? .black : on ? Theme.success : .clear)
                .overlay(Rectangle().strokeBorder(both ? .black : on ? Theme.success : Theme.hairlineStrong, lineWidth: 1))
                .frame(width: 12, height: 12)
            if focused {
                Text(label).mono(9, tracking: 1.5, color: both ? .black : Theme.body)
            }
        }
    }
}
