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
            .background(Theme.canvas.ignoresSafeArea())
            .simultaneousGesture(swipe)
        }
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack(spacing: 8) {
            FQIconButton(label: "Back", symbol: "arrow.left") { model.overlay = nil }
            HStack(spacing: 4) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { position, exercise in
                    Button { show(exercise.id) } label: {
                        (model.isDone(exercise) ? Theme.success : position == index ? Theme.white : Theme.hairlineStrong)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel(exercise.name)
                }
            }
            .padding(.horizontal, 8)
            Text("\(index + 1)/\(exercises.count)").mono().frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
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
        return VStack(alignment: .leading, spacing: 0) {
            Circle()
                .fill(Theme.surfaceSoft)
                .overlay(Circle().strokeBorder(Theme.hairlineStrong, lineWidth: 1))
                .overlay {
                    VStack(spacing: 6) {
                        Text("EXERCISE ANIMATION").mono()
                        Text(exercise.group).mono(color: Theme.mutedSoft)
                    }
                }
                .frame(width: 180, height: 180)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 24)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.name).display(26).accessibilityAddTraits(.isHeader)
                    Text("\(exercise.prescription) · TARGET RIR \(exercise.targetRIR)").mono()
                }
                Spacer(minLength: 0)
                VStack(spacing: 2) {
                    FQCheck(on: progress.done, size: 40, label: "Exercise done") { finish(exercise) }
                    Text("DONE").mono(9)
                }
            }

            HStack(alignment: .top, spacing: 24) {
                SpecCell(value: progress.volume.formatted(.number.grouping(.automatic)), label: "VOLUME · LBS", padding: 12)
                SpecCell(value: exercise.lastRecord, label: "LAST RECORD", padding: 12)
            }
            .padding(.top, 20)
            .padding(.bottom, 8)

            setsTable(exercise, progress)

            HStack(spacing: 12) {
                FQButton(title: "+ Add set", compact: true) { model.addSet(to: exercise) }
                FQButton(title: "− Remove set", variant: .ghost, compact: true) { model.removeSet(from: exercise) }
                    .disabled(progress.sets.count <= 1)
            }
            .padding(.top, 20)

            Text("SWIPE FOR NEXT / PREVIOUS EXERCISE")
                .mono()
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 32)
        .id(exercise.id)
        .transition(.push(from: forward ? .trailing : .leading))
    }

    private func setsTable(_ exercise: Exercise, _ progress: ExerciseProgress) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("SET").mono(10).frame(width: 36, alignment: .leading)
                ForEach(["LBS", "REPS", "RIR"], id: \.self) { Text($0).mono(10).frame(maxWidth: .infinity) }
                Text("DONE").mono(10).frame(width: 52)
            }
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) { Hairline(color: Theme.hairlineStrong) }

            ForEach(progress.sets.indices, id: \.self) { row in
                let entry = progress.sets[row]
                HStack(spacing: 12) {
                    Text("\(row + 1)").mono(color: Theme.ink).frame(width: 36, alignment: .leading)
                    cell("Weight, set \(row + 1)", text: field(row, exercise, \.lbs), placeholder: "0", done: entry.done, decimal: true)
                    cell("Reps, set \(row + 1)", text: field(row, exercise, \.reps), placeholder: exercise.repLabel, done: entry.done)
                    cell("Reps in reserve, set \(row + 1)", text: field(row, exercise, \.rir), placeholder: "\(exercise.targetRIR)", done: entry.done)
                    FQCheck(on: entry.done, label: "Set \(row + 1) done") {
                        model.toggleSet(row, of: exercise)
                        if !entry.done { restTrigger += 1 }
                    }
                    .frame(width: 52)
                }
                .padding(.vertical, 4)
                .overlay(alignment: .bottom) { Hairline() }
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
        TextField("", text: text, prompt: Text(placeholder).foregroundStyle(Theme.mutedSoft))
            .font(Theme.mono(14))
            .multilineTextAlignment(.center)
            .foregroundStyle(done ? Theme.success : Theme.ink)
            .tint(Theme.white)
            .textFieldStyle(.plain)
            .numericKeyboard(decimal: decimal)
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottom) { Hairline(color: Theme.hairlineStrong) }
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
                model.overlay = nil
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
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                Text("REST TIME").mono()
                Text(String(format: "%d:%02d", left / 60, left % 60))
                    .display(22, tracking: 1, color: running ? Theme.ink : Theme.body)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            FQIconButton(label: "Less rest", symbol: "minus") { left = max(0, left - 15) }
            FQIconButton(label: "More rest", symbol: "plus") { left += 15 }
            FQIconButton(label: running ? "Pause" : "Start", symbol: running ? "pause" : "play") { running.toggle() }
            FQIconButton(label: "Stop", symbol: "stop") {
                running = false
                left = base
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Theme.surfaceCard.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Hairline() }
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
