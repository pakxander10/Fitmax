import SwiftUI

/// Capture → analysing → review. Photo capture is a placeholder until the camera is wired;
/// both paths go through `AppModel.foodAnalyzer`, which is where the backend call lands.
struct LogMealFlow: View {
    private enum Step { case capture, analysing, review }

    @Environment(AppModel.self) private var model

    @State private var step: Step
    @State private var slot = MealSlot.dinner
    @State private var text = ""
    @State private var items: [FoodItem]
    @State private var source = MealSource.photo
    @State private var notice: String?

    /// `previewItems` opens straight on the review step, for previews and render tests.
    init(previewItems: [FoodItem] = []) {
        _items = State(initialValue: previewItems)
        _step = State(initialValue: previewItems.isEmpty ? .capture : .review)
    }

    var body: some View {
        FQOverlay(title: step == .review ? "Review estimate" : "Log a meal", onBack: { model.overlay = nil }) {
            switch step {
            case .capture: capture
            case .analysing: analysing
            case .review: review
            }
        }
    }

    // MARK: Steps

    private var capture: some View {
        VStack(alignment: .leading, spacing: 24) {
            PhotoPlaceholder(label: "Camera viewfinder", ratio: 3.0 / 4.0, bordered: true)
            if let notice {
                Text(notice).serif(14, color: Theme.warning)
            }
            FlowLayout(spacing: 8) {
                ForEach(MealSlot.allCases) { option in
                    Button { slot = option } label: {
                        Text(option.label)
                            .mono(color: slot == option ? Theme.ink : Theme.muted)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .overlay(Capsule().strokeBorder(slot == option ? Theme.white : Theme.hairlineStrong, lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityAddTraits(slot == option ? .isSelected : [])
                }
            }
            Button { analyse(.photo) } label: {
                Circle()
                    .strokeBorder(Theme.hairlineStrong, lineWidth: 1)
                    .padding(6)
                    .overlay(Circle().strokeBorder(Theme.white, lineWidth: 1))
                    .frame(width: 72, height: 72)
                    .contentShape(Circle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Take photo")
            .frame(maxWidth: .infinity)

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Or type what you ate").mono()
                    TextField("", text: $text, prompt: Text("2 eggs and toast").foregroundStyle(Theme.muted))
                        .font(Theme.text(16))
                        .foregroundStyle(Theme.ink)
                        .tint(Theme.white)
                        .textFieldStyle(.plain)
                        .submitLabel(.done)
                        .onSubmit(logText)
                        .frame(height: 44)
                        .overlay(alignment: .bottom) { Hairline(color: Theme.hairlineStrong) }
                }
                FQButton(title: "Log", compact: true, action: logText)
                    .disabled(trimmedText.isEmpty)
            }
        }
    }

    private var analysing: some View {
        VStack(spacing: 16) {
            Text("Estimating portions").mono(color: Theme.ink)
            IndeterminateLine()
            Text("Grams first, then nutrition").mono()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 160)
    }

    private var review: some View {
        let total = items.map(\.macros).total
        return VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 24) {
                FQRing(value: total.kcal, max: model.targets.kcal, size: 120)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(slot.label) · ESTIMATE").mono()
                    Text("Adjust grams if a portion looks off. Calories and macros update with it.").serif(14)
                }
            }
            VStack(spacing: 0) {
                ForEach($items) { $item in
                    FQRow {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name).serif(color: Theme.ink)
                            Text("\(item.macros.kcal) KCAL · P \(item.macros.protein) · C \(item.macros.carbs) · F \(item.macros.fat) · \(item.confidence.label)")
                                .mono()
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: 0) {
                            stepButton("minus", label: "Less \(item.name)") { item.adjust(by: -10) }
                            Text("\(item.grams)G").mono(color: Theme.ink).frame(width: 48)
                            stepButton("plus", label: "More \(item.name)") { item.adjust(by: 10) }
                        }
                    }
                }
            }
            HStack(spacing: 12) {
                FQButton(title: "Save to log") {
                    model.saveMeal(slot: slot, items: items, source: source)
                }
                FQButton(title: "Retake", variant: .ghost) { step = .capture }
            }
        }
    }

    // MARK: Actions

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func logText() {
        guard !trimmedText.isEmpty else { return }
        analyse(.text(trimmedText))
    }

    private func analyse(_ input: FoodInput) {
        source = input.source
        notice = nil
        step = .analysing
        Task {
            let found = (try? await model.foodAnalyzer.estimate(input)) ?? []
            if found.isEmpty {
                // Never save silently when nothing was recognised.
                notice = "No food detected — try again?"
                step = .capture
            } else {
                items = found
                step = .review
            }
        }
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Theme.ink)
                .frame(width: 32, height: 32)
                .overlay(Circle().strokeBorder(Theme.hairlineStrong, lineWidth: 1))
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

/// 1px line with a white segment sweeping across while an estimate is in flight.
private struct IndeterminateLine: View {
    @State private var sweeping = false

    var body: some View {
        Theme.hairline
            .frame(width: 160, height: 1)
            .overlay(alignment: .leading) {
                Theme.white.frame(width: 64, height: 1).offset(x: sweeping ? 160 : -64)
            }
            .clipped()
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) { sweeping = true }
            }
            .accessibilityHidden(true)
    }
}
