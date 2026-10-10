import SwiftUI

struct WorkoutPage: View {
    @Environment(AppModel.self) private var model

    @State private var renamingID: String?
    @State private var draftName = ""
    @FocusState private var renameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            FQHead(index: "03 · WORKOUT", title: "My templates", meta: "Saved workouts. Tap one to make it today’s session.")
            VStack(spacing: 0) {
                ForEach(Array(model.templates.enumerated()), id: \.element.id) { index, template in
                    templateRow(template, index: index)
                }
            }
            if let active = model.activeTemplate {
                session(active).padding(.top, 16)
            } else {
                Text("No templates left. Generate a new plan from your profile.").serif().padding(.top, 16)
            }
        }
    }

    // MARK: Templates

    private func templateRow(_ template: WorkoutTemplate, index: Int) -> some View {
        FQRow {
            Text(String(format: "%02d", index + 1)).mono().frame(width: 24, alignment: .leading)
            if renamingID == template.id {
                TextField("", text: $draftName)
                    .font(Theme.display(16))
                    .tracking(1.5)
                    .foregroundStyle(Theme.ink)
                    .tint(Theme.white)
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
                    .focused($renameFocused)
                    .onSubmit(commitRename)
                    .onChange(of: renameFocused) { if !renameFocused { commitRename() } }
                    .frame(height: 40)
                    .overlay(alignment: .bottom) { Hairline(color: Theme.white) }
            } else {
                Button { model.activeTemplateID = template.id } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.name).display(16, tracking: 1.5)
                        Text("\(template.exercises.count) EXERCISES\(template.id == model.activeTemplate?.id ? " · TODAY" : "")").mono()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
            }
            MoreMenu(label: "More for \(template.name)") {
                Button("Rename") { beginRename(template) }
                Button("Remove template", role: .destructive) { model.removeTemplate(template.id) }
            }
        }
    }

    private func beginRename(_ template: WorkoutTemplate) {
        draftName = template.name
        renamingID = template.id
        renameFocused = true
    }

    private func commitRename() {
        guard let id = renamingID else { return }
        model.renameTemplate(id, to: draftName)
        renamingID = nil
    }

    // MARK: Today's session

    private func session(_ active: WorkoutTemplate) -> some View {
        let done = model.doneCount
        return VStack(alignment: .leading, spacing: 12) {
            Text("Today’s recommended workout").display(20, tracking: 1).accessibilityAddTraits(.isHeader)
            Text("\(active.name) · \(done)/\(active.exercises.count) DONE · ~55 MIN").mono()
            Text("Bench load is up 5 lb from last week: all sets hit 8 reps at RIR 2. Overhead press stays swapped out for your left shoulder.")
                .serif(14, color: Theme.muted)
            VStack(spacing: 0) {
                ForEach(active.exercises) { exerciseRow($0) }
            }
            FQButton(title: done == 0 ? "Start workout" : done == active.exercises.count ? "Review workout" : "Continue workout") {
                let next = active.exercises.first { !model.isDone($0) } ?? active.exercises.first
                if let next { model.overlay = .exercise(next.id) }
            }
            .disabled(active.exercises.isEmpty)
            .padding(.top, 12)
        }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        let done = model.isDone(exercise)
        return FQRow {
            Circle()
                .fill(Theme.surfaceSoft)
                .overlay(Circle().strokeBorder(done ? Theme.success : Theme.hairlineStrong, lineWidth: 1))
                .overlay {
                    if done {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .light)).foregroundStyle(Theme.success)
                    } else {
                        Text(exercise.group.prefix(3)).mono(9, tracking: 1)
                    }
                }
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            Button { model.overlay = .exercise(exercise.id) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name).serif(color: done ? Theme.muted : Theme.ink).multilineTextAlignment(.leading)
                    Text("\(exercise.prescription) · \(exercise.restSeconds)S REST").mono()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityValue(done ? "Done" : "")
            MoreMenu(label: "More for \(exercise.name)") {
                Button("About exercise") { model.overlay = .aboutExercise(exercise) }
                Button("Replace exercise") { model.replaceExercise(exercise) }
                Button("Remove exercise", role: .destructive) { model.removeExercise(exercise) }
            }
        }
    }
}

/// The "···" affordance on a row, opening the system menu.
private struct MoreMenu<Items: View>: View {
    let label: String
    @ViewBuilder var items: Items

    var body: some View {
        Menu {
            items
        } label: {
            Text("···").mono(16, tracking: 1).frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }
}

struct AboutExerciseCard: View {
    let exercise: Exercise
    @Environment(AppModel.self) private var model

    var body: some View {
        FQScrim(onClose: { model.overlay = nil }) {
            VStack(alignment: .leading, spacing: 14) {
                Text(exercise.group).mono()
                Text(exercise.name).display(20, tracking: 1)
                Text(exercise.about).serif()
                Text("SUBSTITUTE · \(exercise.alternative)").mono()
                FQButton(title: "Close") { model.overlay = nil }
            }
            .padding(24)
        }
    }
}
