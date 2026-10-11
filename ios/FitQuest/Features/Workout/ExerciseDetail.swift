import SwiftUI

/// Set-by-set logging for one exercise of today's session. Swipe or tap the dashes to move between exercises.
struct ExerciseDetail: View {
    @Environment(AppModel.self) private var model
    @Environment(\.flatScroll) private var flat

    @State private var currentID: String
    @State private var forward = true
    @State private var restTrigger = 0

    init(initialID: String) {
        _currentID = State(initialValue: initialID)
    }

    private var exercises: [Exercise] { model.activeTemplate?.exercises ?? [] }
    private var index: Int { exercises.firstIndex { $0.id == currentID } ?? 0 }

    var body: some View {
        if exercises.indices.contains(index) {
            let exercise = exercises[index]
            VStack(spacing: 0) {
                topBar
                if flat {
                    content(exercise)
                    RestTimer(base: exercise.restSeconds, trigger: restTrigger)
                } else {
                    ScrollView { content(exercise) }
                        .scrollIndicators(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            RestTimer(base: exercise.restSeconds, trigger: restTrigger)
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: flat ? nil : .infinity, alignment: .top)
            .background { AeroBackground() }
            .simultaneousGesture(swipe)
        }
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack(spacing: 8) {
            FQIconButton(label: "Back", symbol: "chevron.left", action: model.dismiss)
            HStack(spacing: 4) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { position, exercise in
                    Button { show(exercise.id) } label: {
                        Capsule()
                            .fill(model.isDone(exercise) ? Theme.lime : position == index ? .white : .white.opacity(0.35))
                            .frame(height: 6)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel(exercise.name)
                }
            }
            .padding(.horizontal, 6)
            Text("\(index + 1)/\(exercises.count)")
                .heading(14, color: Theme.onSky)
                .skyShadow()
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 30).onEnded { value in
            let dx = value.translation.width
            guard abs(dx) > 60, abs(dx) > abs(value.translation.height) * 1.5 else { return }
            step(dx < 0 ? 1 : -1)
        }
    }

    // MARK: Body

    private func content(_ exercise: Exercise) -> some View {
        let progress = model.progress(for: exercise)
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Glossy(shape: Circle(), fill: Theme.blueGloss)
                        .overlay {
                            VStack(spacing: 2) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.system(size: 26, weight: .regular))
                                Text(exercise.group.capitalized).font(Theme.caption(10))
                            }
                            .foregroundStyle(.white)
                        }
                        .frame(width: 84, height: 84)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name).heading(22).accessibilityAddTraits(.isHeader)
                        Text("\(exercise.prescription) · target RIR \(exercise.targetRIR)").caption(13)
                    }
                    Spacer(minLength: 0)
                    VStack(spacing: 0) {
                        FQCheck(on: progress.done, size: 36, label: "Exercise done") { finish(exercise) }
                        Text("Done").caption(11)
                    }
                }
                HStack(alignment: .top, spacing: 8) {
                    SpecCell(value: progress.volume.formatted(.number.grouping(.automatic)), label: "Volume · lb")
                    SpecCell(value: model.lastRecord(for: exercise), label: "Last record")
                }
            }
            .aeroCard()

            VStack(alignment: .leading, spacing: 12) {
                setsTable(exercise, progress)
                HStack(spacing: 12) {
                    FQButton(title: "Add set", variant: .secondary, compact: true) { model.addSet(to: exercise) }
                    FQButton(title: "Remove set", variant: .secondary, compact: true) { model.removeSet(from: exercise) }
                        .disabled(progress.sets.count <= 1)
                }
                Text("Swipe for the next or previous exercise").caption().frame(maxWidth: .infinity)
            }
            .aeroCard(vertical: 12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .id(exercise.id)
        .transition(.push(from: forward ? .trailing : .leading))
    }

    private func setsTable(_ exercise: Exercise, _ progress: ExerciseProgress) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Set").caption().frame(width: 30, alignment: .leading)
                ForEach(["lb", "Reps", "RIR"], id: \.self) { Text($0).caption().frame(maxWidth: .infinity) }
                Text("Done").caption().frame(width: 48)
            }
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) { Hairline() }

            ForEach(progress.sets.indices, id: \.self) { row in
                let entry = progress.sets[row]
                HStack(spacing: 10) {
                    Text("\(row + 1)").heading(15).frame(width: 30, alignment: .leading)
                    cell("Weight, set \(row + 1)", text: field(row, exercise, \.lbs), placeholder: "0", done: entry.done, decimal: true)
                    cell("Reps, set \(row + 1)", text: field(row, exercise, \.reps), placeholder: exercise.repLabel, done: entry.done)
                    cell("Reps in reserve, set \(row + 1)", text: field(row, exercise, \.rir), placeholder: "\(exercise.targetRIR)", done: entry.done)
                    FQCheck(on: entry.done, label: "Set \(row + 1) done") {
                        model.toggleSet(row, of: exercise)
                        if !entry.done { restTrigger += 1 }
                    }
                    .frame(width: 48)
                }
                .padding(.vertical, 2)
                .overlay(alignment: .bottom) { if row < progress.sets.count - 1 { Hairline() } }
            }
        }
    }

    private func field(_ row: Int, _ exercise: Exercise, _ keyPath: WritableKeyPath<SetEntry, String>) -> Binding<String> {
        Binding(
            get: {
                let sets = model.progress(for: exercise).sets
                return sets.indices.contains(row) ? sets[row][keyPath: keyPath] : ""
            },
            set: { value in model.setEntry(row, of: exercise) { $0[keyPath: keyPath] = value } }
        )
    }

    private func cell(_ label: String, text: Binding<String>, placeholder: String, done: Bool, decimal: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return TextField("", text: text, prompt: Text(placeholder).foregroundStyle(Theme.muted.opacity(0.6)))
            .font(Theme.heading(15))
            .multilineTextAlignment(.center)
            .foregroundStyle(done ? Theme.success : Theme.ink)
            .tint(Theme.azure)
            .textFieldStyle(.plain)
            .numericKeyboard(decimal: decimal)
            .frame(height: 36)
            .frame(maxWidth: .infinity)
            .background(shape.fill(done ? Color(hex: 0xE6F8D2) : .white))
            .overlay(shape.strokeBorder(done ? Theme.lime.opacity(0.6) : Theme.aqua.opacity(0.5), lineWidth: 1))
            .accessibilityLabel(label)
    }

    // MARK: Navigation

    private func step(_ delta: Int) {
        let target = index + delta
        guard exercises.indices.contains(target) else { return }
        show(exercises[target].id)
    }

    private func show(_ id: String) {
        guard let target = exercises.firstIndex(where: { $0.id == id }), target != index else { return }
        forward = target > index
        withAnimation(.easeOut(duration: 0.22)) { currentID = id }
    }

    /// Ticks the exercise off, lets the tick land, then moves on or ends the workout.
    private func finish(_ exercise: Exercise) {
        let outcome = model.toggleExerciseDone(exercise.id)
        guard outcome != .undone else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            switch outcome {
            case .undone:
                break
            case .next(let id):
                show(id)
            case .workoutComplete:
                model.completeWorkout()
                model.dismiss()
            }
        }
    }
}

/// Rest countdown pinned under the set table. Starts itself whenever a set is ticked.
private struct RestTimer: View {
    let base: Int
    let trigger: Int

    @State private var left: Int
    @State private var running = false

    init(base: Int, trigger: Int) {
        self.base = base
        self.trigger = trigger
        _left = State(initialValue: base)
    }

    var body: some View {
        HStack(spacing: 2) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Rest time").caption()
                Text(String(format: "%d:%02d", left / 60, left % 60))
                    .heading(24, color: running ? Theme.azure : Theme.ink)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            FQIconButton(label: "Less rest", symbol: "minus") { left = max(0, left - 15) }
            FQIconButton(label: "More rest", symbol: "plus") { left += 15 }
            FQIconButton(label: running ? "Pause" : "Start", symbol: running ? "pause.fill" : "play.fill") { running.toggle() }
            FQIconButton(label: "Stop", symbol: "stop.fill") {
                running = false
                left = base
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background {
            Rectangle()
                .fill(Theme.glass)
                .overlay(alignment: .top) { Color.white.frame(height: 1) }
                .shadow(color: Theme.azure.opacity(0.25), radius: 10, y: -4)
                .ignoresSafeArea(edges: .bottom)
        }
        .onChange(of: base) {
            left = base
            running = false
        }
        .onChange(of: trigger) {
            left = base
            running = true
        }
        .task(id: running) {
            guard running else { return }
            while left > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                left -= 1
            }
            running = false
        }
    }
}
