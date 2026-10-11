import SwiftUI

/// Capture → analysing → review. Photos and typed entries both go through `AppModel.foodAnalyzer`.
struct LogMealFlow: View {
    private enum Step { case capture, analysing, review }

    @Environment(AppModel.self) private var model

    @State private var step: Step
    @State private var slot = MealSlot.dinner
    @State private var text = ""
    @State private var items: [FoodItem]
    @State private var source = MealSource.photo
    @State private var notice: String?
    /// The food whose amount field has the keyboard, if any.
    @FocusState private var editingItem: FoodItem.ID?
    @State private var showingCamera = false
    @State private var camera = CameraModel()

    /// `previewItems` opens straight on the review step, for previews and render tests.
    init(previewItems: [FoodItem] = []) {
        _items = State(initialValue: previewItems)
        _step = State(initialValue: previewItems.isEmpty ? .capture : .review)
    }

    var body: some View {
        FQOverlay(title: step == .review ? "Review estimate" : "Log a meal", onBack: model.dismiss) {
            switch step {
            case .capture: capture
            case .analysing: analysing
            case .review: review
            }
        }
        // The number pad has no return key, so offer a way to put it away.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if editingItem != nil {
                HStack {
                    Spacer()
                    FQButton(title: "Done", compact: true) { editingItem = nil }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.glass)
            }
        }
    }

    // MARK: Steps

    private var capture: some View {
        VStack(alignment: .leading, spacing: 16) {
            viewfinder
            if let notice {
                Text(notice).copy(14, color: Theme.warning)
            }
            FlowLayout(spacing: 8) {
                ForEach(MealSlot.allCases) { option in
                    let selected = slot == option
                    Button { slot = option } label: {
                        Text(option.label)
                            .caption(13, color: selected ? .white : Theme.link)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background { Glossy(shape: Capsule(), fill: selected ? Theme.blueGloss : Theme.pearlGloss) }
                            .overlay(Capsule().strokeBorder(selected ? .clear : Theme.aqua.opacity(0.6), lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            Button(action: shutter) {
                Glossy(shape: Circle(), fill: Theme.greenGloss)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3).padding(6))
                    .frame(width: 72, height: 72)
                    .shadow(color: Theme.green.opacity(0.4), radius: 8, y: 4)
                    .contentShape(Circle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Take photo")
            .frame(maxWidth: .infinity)

            PhotoImportButtons(onPhoto: { analyse(.photo($0)) }, onError: { notice = $0 })
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text("Or type what you ate").caption(13)
                HStack(spacing: 10) {
                    TextField("", text: $text, prompt: Text("2 eggs and toast").foregroundStyle(Theme.muted.opacity(0.7)))
                        .font(Theme.copy(16))
                        .foregroundStyle(Theme.ink)
                        .tint(Theme.azure)
                        .textFieldStyle(.plain)
                        .submitLabel(.done)
                        .onSubmit(logText)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(Capsule().fill(.white))
                        .overlay(Capsule().strokeBorder(Theme.aqua.opacity(0.6), lineWidth: 1))
                    FQButton(title: "Log", compact: true, action: logText)
                        .disabled(trimmedText.isEmpty)
                }
            }
        }
        .aeroCard()
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        #if canImport(UIKit)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker(
                onCapture: { jpeg in
                    showingCamera = false
                    analyse(.photo(jpeg))
                },
                onCancel: { showingCamera = false }
            )
            .ignoresSafeArea()
        }
        #endif
    }

    /// Live camera in the square; the placeholder when there is no camera or access is denied.
    @ViewBuilder private var viewfinder: some View {
        #if os(iOS)
        if camera.state == .running {
            CameraPreview(session: camera.session)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white, lineWidth: 1))
                .accessibilityLabel("Camera viewfinder")
        } else {
            PhotoPlaceholder(label: "Camera viewfinder", ratio: 1, symbol: "camera")
        }
        #else
        PhotoPlaceholder(label: "Camera viewfinder", ratio: 1, symbol: "camera")
        #endif
    }

    private var analysing: some View {
        VStack(spacing: 14) {
            Text("Estimating portions").heading(18)
            IndeterminateLine()
            Text("Grams first, then nutrition").caption()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .aeroCard()
        .padding(.top, 100)
    }

    private var review: some View {
        let total = items.map(\.macros).total
        return VStack(alignment: .leading, spacing: 16) {
            if model.usesSampleFoodEstimates {
                Label("Sample result, not your meal. Add a Gemini key to Secrets.plist and rebuild for real estimates.", systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.caption(13))
                    .foregroundStyle(Theme.warning)
                    .aeroCard(vertical: 12)
            }
            HStack(spacing: 16) {
                FQRing(value: total.kcal, max: model.targets.kcal, size: 120)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(slot.label) · estimate").caption(13, color: Theme.ink)
                    Text("Type an amount or use − and + if a portion looks off. Calories and macros update with it.").copy(14)
                }
            }
            .aeroCard()

            VStack(spacing: 0) {
                ForEach($items) { $item in
                    FQRow(divider: item.id != items.last?.id) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).copy(color: Theme.ink)
                            Text("\(item.macros.kcal) kcal · P \(item.macros.protein) · C \(item.macros.carbs) · F \(item.macros.fat) · \(item.confidence.label) confidence")
                                .caption()
                            if let serving = item.serving {
                                Text("1 serving = 1 \(serving.name) · \(serving.grams.formatted(.number.precision(.fractionLength(0...1)))) g").caption()
                            }
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 0) {
                                stepButton("minus", label: "Less \(item.name)") { item.step(-1) }
                                AmountField(item: $item, editing: $editingItem)
                                stepButton("plus", label: "More \(item.name)") { item.step(1) }
                            }
                            if item.serving != nil {
                                UnitSwitch(item: $item)
                            } else {
                                Text("grams").caption(11).padding(.trailing, 6)
                            }
                        }
                    }
                }
            }
            .aeroCard(vertical: 4)

            HStack(spacing: 12) {
                FQButton(title: "Save to log") {
                    editingItem = nil
                    model.saveMeal(slot: slot, items: items, source: source)
                }
                FQButton(title: "Retake", variant: .secondary) { step = .capture }
            }
            .aeroCard()
        }
    }

    // MARK: Actions

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func shutter() {
        guard camera.state == .running else {
            showingCamera = true // no live camera: pick a photo instead
            return
        }
        Task {
            if let jpeg = await camera.capture() {
                analyse(.photo(jpeg))
            } else {
                notice = "Couldn't take the photo — try again."
            }
        }
    }

    private func logText() {
        guard !trimmedText.isEmpty else { return }
        analyse(.text(trimmedText))
    }

    private func analyse(_ input: FoodInput) {
        source = input.source
        notice = nil
        step = .analysing
        Task {
            let found: [FoodItem]
            do {
                found = try await model.foodAnalyzer.estimate(input)
            } catch {
                if case GeminiClient.ClientError.badResponse(GeminiClient.quotaStatus) = error {
                    notice = "The Gemini key has used up its requests for now. Try again later."
                } else {
                    notice = "Couldn't analyse that — check your connection and try again."
                }
                step = .capture
                return
            }
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
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background { Glossy(shape: Circle(), fill: Theme.blueGloss) }
                .frame(width: 38, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

/// The portion as an editable number, in whichever unit the food is set to.
private struct AmountField: View {
    @Binding var item: FoodItem
    var editing: FocusState<FoodItem.ID?>.Binding

    @State private var text = ""

    private var isEditing: Bool { editing.wrappedValue == item.id }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        TextField("", text: $text)
            .font(Theme.heading(15))
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.ink)
            .tint(Theme.azure)
            .textFieldStyle(.plain)
            .numericKeyboard(decimal: true)
            .focused(editing, equals: item.id)
            .frame(width: 58, height: 36)
            .background(shape.fill(.white))
            .overlay(shape.strokeBorder(isEditing ? Theme.azure : Theme.aqua.opacity(0.5), lineWidth: 1))
            .accessibilityLabel("Amount of \(item.name)")
            .accessibilityValue("\(item.amountText) \(item.unit == .servings ? "servings" : "grams")")
            .onAppear { text = item.amountText }
            .onChange(of: text) {
                // Half-typed or empty input is left alone until it reads as a number above zero.
                if isEditing, let value = FoodItem.parseAmount(text) { item.setAmount(value) }
            }
            .onChange(of: item.amountText) {
                // Follow the steppers and the unit switch, but never rewrite what is being typed
                // while it still means the same amount ("1." must not snap back to "1").
                if !isEditing || FoodItem.parseAmount(text) != FoodItem.parseAmount(item.amountText) { text = item.amountText }
            }
            .onChange(of: isEditing) {
                if !isEditing { text = item.amountText }
            }
    }
}

/// Grams or servings, for foods that have a natural serving.
private struct UnitSwitch: View {
    @Binding var item: FoodItem

    var body: some View {
        HStack(spacing: 0) {
            option("g", .grams, label: "Grams")
            option("servings", .servings, label: "Servings")
        }
        .background(Capsule().fill(Theme.well))
        .overlay(Capsule().strokeBorder(Theme.aqua.opacity(0.5), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Unit for \(item.name)")
    }

    private func option(_ title: String, _ unit: AmountUnit, label: String) -> some View {
        let selected = item.unit == unit
        return Button { item.setUnit(unit) } label: {
            Text(title)
                .caption(12, color: selected ? .white : Theme.link)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background { if selected { Glossy(shape: Capsule(), fill: Theme.blueGloss) } }
                .frame(minHeight: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Glossy segment sweeping along a track while an estimate is in flight.
private struct IndeterminateLine: View {
    @State private var sweeping = false

    var body: some View {
        Capsule()
            .fill(Theme.ink.opacity(0.1))
            .frame(width: 180, height: 8)
            .overlay(alignment: .leading) {
                Glossy(shape: Capsule(), fill: Theme.blueGloss).frame(width: 64, height: 8).offset(x: sweeping ? 180 : -64)
            }
            .clipShape(Capsule())
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) { sweeping = true }
            }
            .accessibilityHidden(true)
    }
}
