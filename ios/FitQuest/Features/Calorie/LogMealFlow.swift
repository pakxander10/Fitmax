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
            HStack(spacing: 16) {
                FQRing(value: total.kcal, max: model.targets.kcal, size: 120)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(slot.label) · estimate").caption(13, color: Theme.ink)
                    Text("Adjust grams if a portion looks off. Calories and macros update with it.").copy(14)
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
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: 0) {
                            stepButton("minus", label: "Less \(item.name)") { item.adjust(by: -10) }
                            Text("\(item.grams) g").heading(14).frame(width: 50)
                            stepButton("plus", label: "More \(item.name)") { item.adjust(by: 10) }
                        }
                    }
                }
            }
            .aeroCard(vertical: 4)

            HStack(spacing: 12) {
                FQButton(title: "Save to log") {
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
                notice = "Couldn't analyse that — check your connection and try again."
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
