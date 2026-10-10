import SwiftUI

struct WorkoutPage: View {
    @Environment(AppModel.self) private var model

    @State private var renamingID: String?
    @State private var draftName = ""
    @FocusState private var renameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FQHead(index: "Workout", title: "My templates", meta: "Saved workouts. Tap one to see it and your past sessions.")
            VStack(spacing: 0) {
                ForEach(Array(model.templates.enumerated()), id: \.element.id) { index, template in
                    templateRow(template, index: index)
                }
            }
            .aeroCard(vertical: 4)

            if let active = model.activeTemplate {
                session(active)
            } else {
                Text("No templates left. Generate a new plan from your profile.").copy().aeroCard()
            }
        }
    }

    // MARK: Templates

    private func templateRow(_ template: WorkoutTemplate, index: Int) -> some View {
        let isToday = template.id == model.activeTemplate?.id
        return FQRow(divider: template.id != model.templates.last?.id) {
            Text(String(format: "%02d", index + 1)).caption(13).frame(width: 22, alignment: .leading)
            if renamingID == template.id {
                TextField("", text: $draftName)
                    .font(Theme.heading(16))
                    .foregroundStyle(Theme.ink)
                    .tint(Theme.azure)
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
                    .focused($renameFocused)
                    .onSubmit(commitRename)
                    .onChange(of: renameFocused) { if !renameFocused { commitRename() } }
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(Capsule().fill(.white))
                    .overlay(Capsule().strokeBorder(Theme.aqua, lineWidth: 1))
            } else {
                Button { model.present(.template(template.id)) } label: {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(template.name).heading(16)
                            Text("\(template.exercises.count) exercises\(isToday ? " · today" : "")").caption()
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityHint("Opens the workout and its past sessions")
            }
            MoreMenu(label: "More for \(template.name)") {
                if !isToday {
                    Button("Make today’s workout") { model.activeTemplateID = template.id }
                }
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
        return VStack(alignment: .leading, spacing: 8) {
            CardTitle(title: "Today’s recommended workout")
            Text("\(active.name) · \(done)/\(active.exercises.count) done · about 55 min").caption(13)
            Text("Bench load is up 5 lb from last week: all sets hit 8 reps at RIR 2. Overhead press stays swapped out for your left shoulder.")
                .copy(14)
            VStack(spacing: 0) {
                ForEach(active.exercises) { exercise in
                    ExerciseRow(exercise: exercise, templateID: active.id, divider: exercise.id != active.exercises.last?.id) {
                        MoreMenu(label: "More for \(exercise.name)") {
                            Button("About exercise") { model.present(.aboutExercise(exercise)) }
                            Button("Replace exercise") { model.replaceExercise(exercise) }
                            Button("Remove exercise", role: .destructive) { model.removeExercise(exercise) }
                        }
                    }
                }
            }
            FQButton(title: done == 0 ? "Start workout" : done == active.exercises.count ? "Review workout" : "Continue workout") {
                model.startWorkout(active.id)
            }
            .disabled(active.exercises.isEmpty)
            .padding(.top, 8)
        }
        .aeroCard()
    }
}

/// One exercise of a template: muscle-group orb, name and prescription. Tapping it starts the workout there.
struct ExerciseRow<Trailing: View>: View {
    let exercise: Exercise
    let templateID: String
    var divider = true
    @ViewBuilder var trailing: Trailing

    @Environment(AppModel.self) private var model

    var body: some View {
        let done = model.isDone(exercise)
        FQRow(divider: divider) {
            Glossy(shape: Circle(), fill: done ? Theme.greenGloss : Theme.blueGloss)
                .overlay {
                    if done {
                        Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    } else {
                        Text(exercise.group.prefix(3).capitalized).heading(11, color: .white)
                    }
                }
                .frame(width: 42, height: 42)
                .accessibilityHidden(true)
            Button { model.startWorkout(templateID, at: exercise.id) } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Text(exercise.name).copy(color: done ? Theme.muted : Theme.ink).multilineTextAlignment(.leading)
                    Text("\(exercise.prescription) · \(exercise.restSeconds)s rest").caption()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityValue(done ? "Done" : "")
            trailing
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
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }
}

struct AboutExerciseCard: View {
    let exercise: Exercise
    @Environment(AppModel.self) private var model

    var body: some View {
        FQScrim(onClose: model.dismiss) {
            VStack(alignment: .leading, spacing: 10) {
                Text(exercise.group.capitalized).caption(13)
                Text(exercise.name).heading(20)
                Text(exercise.about).copy()
                Text("Substitute · \(exercise.alternative)").caption(13)
                FQButton(title: "Close", variant: .secondary, action: model.dismiss).padding(.top, 4)
            }
            .padding(20)
        }
    }
}
