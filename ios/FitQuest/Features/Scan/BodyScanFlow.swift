import SwiftUI

/// Tips → photo → scanning → review. The photo goes to the scan server once and is never kept;
/// only the numbers the person reviews are saved.
struct BodyScanFlow: View {
    private enum Step: Equatable {
        case intro
        case scanning
        case review(Biometrics)
        case failed(String)
    }

    /// Typed values outside this range are taken as typos and ignored.
    private static let plausibleInches = 8.0...80.0
    private static let tips = [
        "Whole body in the photo, head to feet",
        "Fitted clothes, long hair tied back",
        "Arms a little away from your sides",
        "Stand straight, facing the camera, plain background",
        "A friend takes it from 2–3 m away at chest height",
    ]

    @Environment(AppModel.self) private var model

    @State private var step: Step
    @State private var amounts: [Biometrics.Field: String]
    @State private var showingCamera = false
    @State private var saving = false
    @State private var saveError: String?
    @FocusState private var editing: Biometrics.Field?

    /// `preview` opens straight on the review step, for previews and render tests.
    init(preview: Biometrics? = nil) {
        _step = State(initialValue: preview.map(Step.review) ?? .intro)
        _amounts = State(initialValue: preview.map(Self.amounts) ?? [:])
    }

    var body: some View {
        FQOverlay(title: title, onBack: model.dismiss) {
            switch step {
            case .intro: intro
            case .scanning: scanning
            case .review(let scan): review(scan)
            case .failed(let message): failed(message)
            }
        }
        // The number pad has no return key, so offer a way to put it away.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if editing != nil {
                HStack {
                    Spacer()
                    FQButton(title: "Done", compact: true) { editing = nil }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.glass)
            }
        }
        #if canImport(UIKit)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker(
                onCapture: { jpeg in
                    showingCamera = false
                    scan(jpeg)
                },
                onCancel: { showingCamera = false }
            )
            .ignoresSafeArea()
        }
        #endif
    }

    private var title: String {
        switch step {
        case .review: "Review estimate"
        case .scanning: "Scanning…"
        default: "Body scan"
        }
    }

    // MARK: Steps

    private var intro: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                CardTitle(title: "For a good scan")
                ForEach(Self.tips, id: \.self) { tip in
                    Label(tip, systemImage: "checkmark.circle.fill")
                        .font(Theme.copy(15))
                        .foregroundStyle(Theme.ink)
                }
            }
            .aeroCard()

            VStack(alignment: .leading, spacing: 12) {
                if let profile = model.profile {
                    Text("Uses your profile: \(profile.heightText) · \(profile.weightText) lb · \(profile.sex.label)").copy(14)
                }
                Text("Your photo is sent once to our scan server to build a 3D estimate, then deleted. Only the measurements are saved.")
                    .copy(13, color: Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if model.bodyScanner == nil {
                    Text(ScanError.notConfigured.message).copy(14, color: Theme.warning)
                }
                FQButton(title: "Take photo", wide: true) { showingCamera = true }
                    .disabled(model.bodyScanner == nil)
            }
            .aeroCard()
        }
    }

    private var scanning: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.azure)
            Text("Building your 3D estimate").heading(18)
            Text("This can take up to a minute.").copy(14, color: Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .aeroCard()
    }

    private func review(_ scan: Biometrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                CardTitle(title: "Measurements", trailing: "inches · estimates")
                ForEach(Biometrics.Field.allCases) { field in
                    FQField(label: field.label, focused: editing == field) {
                        TextField("–", text: amountBinding(field, scan: scan))
                            .focused($editing, equals: field)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                }
                Text("Know a tape-measure number? Type it in and body fat updates to match.")
                    .caption()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .aeroCard()

            VStack(alignment: .leading, spacing: 8) {
                Text(scan.bodyFatPct.map { "Body fat about \(UserProfile.figure($0))%" } ?? "Body fat: not enough measurements")
                    .heading(20)
                Text("US Navy formula from the measurements above · scan confidence \(scan.confidence.rawValue). Not medical advice.")
                    .copy(13, color: Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .aeroCard()

            if let saveError {
                Text(saveError).copy(14, color: Theme.warning)
            }
            HStack(spacing: 12) {
                FQButton(title: saving ? "Saving…" : "Save") { save(scan) }
                    .disabled(saving)
                FQButton(title: "Retake", variant: .secondary) { showingCamera = true }
                    .disabled(saving)
            }
        }
    }

    private func failed(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(message).copy(16, color: Theme.ink)
            HStack(spacing: 12) {
                FQButton(title: "Try again") { showingCamera = true }
                FQButton(title: "Close", variant: .secondary, action: model.dismiss)
            }
        }
        .aeroCard()
    }

    // MARK: Actions

    private func scan(_ jpeg: Data) {
        step = .scanning
        Task {
            do {
                let result = try await model.scanBody(jpeg)
                amounts = Self.amounts(result)
                step = .review(result)
            } catch {
                step = .failed((error as? ScanError)?.message ?? ScanError.unavailable.message)
            }
        }
    }

    private func save(_ scan: Biometrics) {
        saving = true
        saveError = nil
        Task {
            do {
                try await model.saveBiometrics(scan)
            } catch {
                saveError = "Couldn’t save the scan. Try again."
                saving = false
            }
        }
    }

    /// Edits show in inches; the scan keeps cm. Unreadable or implausible typing leaves the scan as it was.
    private func amountBinding(_ field: Biometrics.Field, scan: Biometrics) -> Binding<String> {
        Binding(
            get: { amounts[field] ?? "" },
            set: { text in
                amounts[field] = text
                guard let inches = FoodItem.parseAmount(text), Self.plausibleInches.contains(inches) else { return }
                step = .review(scan.editing(field, cm: inches * UserProfile.cmPerInch))
            }
        )
    }

    private static func amounts(_ scan: Biometrics) -> [Biometrics.Field: String] {
        Dictionary(uniqueKeysWithValues: Biometrics.Field.allCases.compactMap { field in
            scan.value(of: field).map { (field, UserProfile.figure($0 / UserProfile.cmPerInch)) }
        })
    }
}
