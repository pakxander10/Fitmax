import SwiftUI

/// Seven days around a focus day. Drag sideways or tap a date to move the focus;
/// tap a tick box to jump to the page it tracks.
struct WeekStrip: View {
    @Environment(AppModel.self) private var model

    @State private var offset = 0
    @State private var dragAnchor: CGFloat = 0

    private static let weights: [CGFloat] = [1, 1, 1, 2.4, 1, 1, 1]
    private static let stepWidth: CGFloat = 40

    var body: some View {
        let center = model.today.adding(offset)
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("7-day progress").heading(18).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                if offset == 0 {
                    Text("Drag to move").caption()
                } else {
                    Button { offset = 0 } label: { Text("Back to today").caption(13, color: Theme.link) }
                        .buttonStyle(PressStyle())
                }
            }
            WeightedRow(weights: Self.weights) {
                ForEach(-3...3, id: \.self) { delta in
                    cell(center.adding(delta), focused: delta == 0)
                        .padding(2)
                        .contentShape(Rectangle())
                        .onTapGesture { offset += delta }
                }
            }
            .highPriorityGesture(drag)
            .sensoryFeedback(.selection, trigger: offset)
        }
        .aeroCard(horizontal: 12)
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
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return VStack(alignment: focused ? .leading : .center, spacing: 2) {
            Text(focused ? day.relativeLabel(to: model.today) : day.weekdayShort)
                .caption(focused ? 11 : 10, color: focused || status.both ? Theme.ink : Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(focused ? "\(day.weekdayShort) \(day.dayOfMonth) \(day.monthShort)" : day.dayOfMonth)
                .heading(focused ? 15 : 14)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            VStack(alignment: .leading, spacing: 0) {
                mark("Calories", page: .calorie, on: status.calories, day: day, focused: focused)
                mark("Workout", page: .workout, on: status.workout, day: day, focused: focused)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .padding(.horizontal, focused ? 8 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: focused ? .topLeading : .top)
        .background {
            if status.both {
                shape.fill(Theme.leafWash).overlay(shape.strokeBorder(.white, lineWidth: 1))
            } else if focused {
                shape.fill(.white).overlay(shape.strokeBorder(Theme.aqua.opacity(0.7), lineWidth: 1))
            }
        }
        .opacity(day > model.today && !focused ? 0.5 : 1)
        .animation(.easeOut(duration: 0.2), value: status)
    }

    /// One tick box. Tapping it opens the page that goal is tracked on.
    private func mark(_ label: String, page: AppModel.Page, on: Bool, day: Day, focused: Bool) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.32)) { model.page = page }
        } label: {
            HStack(spacing: 5) {
                FQCheck(on: on, size: 14)
                if focused { Text(label).caption(10, color: Theme.body).lineLimit(1) }
            }
            .frame(maxWidth: focused ? nil : .infinity, minHeight: 24, alignment: focused ? .leading : .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("\(label), \(day.weekdayName) \(day.dayOfMonth): \(on ? "done" : "not done")")
        .accessibilityHint("Opens the \(page.title) page")
    }
}
