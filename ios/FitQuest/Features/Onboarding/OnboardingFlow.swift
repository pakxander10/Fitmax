import SwiftUI

/// About you → goal → training → diet → targets. Runs once after sign-up, and again from the profile
/// sheet (`editing`) to change the answers.
struct OnboardingFlow: View {
    enum Step: Int, CaseIterable { case body, goal, training, diet, targets }
    private enum Field { case age, weight, feet, inches }

    @Environment(AppModel.self) private var model

    private let editing: Bool
    @State private var step: Step
    @State private var draft: ProfileDraft
    @State private var problem: String?
    @State private var saving = false
    @FocusState private var focus: Field?

    /// `step` and `draft` open the flow part-way through, for previews and render tests.
    init(editing: Bool = false, step: Step = .body, draft: ProfileDraft = ProfileDraft()) {
        self.editing = editing
        _step = State(initialValue: step)
        _draft = State(initialValue: draft)
    }

    var body: some View {
        FQOverlay(title: title, onBack: back) {
            switch step {
            case .body: bodyStep
            case .goal: goalStep
            case .training: trainingStep
            case .diet: dietStep
            case .targets: targetsStep
            }
        }
        // The number pad has no return key, so offer a way to put it away.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if focus != nil {
                HStack {
                    Spacer()
                    FQButton(title: "Done", compact: true) { focus = nil }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.glass)
            }
        }
        .onChange(of: draft) { problem = nil }
    }

    private var title: String {
        if step == .targets { return "Your targets" }
        return "\(editing ? "Edit profile" : "Set up") · \(step.rawValue + 1) of \(Step.targets.rawValue)"
    }

    // MARK: Steps

    private var bodyStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            intro(
                editing ? "About you" : "Welcome\(model.account.map { ", \($0.firstName)" } ?? "")",
                "Your daily calories are worked out from these four answers."
            )
            question("Sex") {
                HStack(spacing: 8) {
                    ForEach(UserProfile.Sex.allCases) { option in
                        FQChip(title: option.label, selected: draft.sex == option) { draft.sex = option }
                    }
                }
            }
            HStack(alignment: .top, spacing: 10) {
                FQField(label: "Age", focused: focus == .age) {
                    TextField("", text: $draft.age, prompt: prompt("24"))
                        .numericKeyboard()
                        .focused($focus, equals: .age)
                }
                FQField(label: "Weight · lb", focused: focus == .weight) {
                    TextField("", text: $draft.weight, prompt: prompt("165"))
                        .numericKeyboard(decimal: true)
                        .focused($focus, equals: .weight)
                }
            }
            HStack(alignment: .top, spacing: 10) {
                FQField(label: "Height · ft", focused: focus == .feet) {
                    TextField("", text: $draft.heightFeet, prompt: prompt("5"))
                        .numericKeyboard()
                        .focused($focus, equals: .feet)
                }
                FQField(label: "Height · in", focused: focus == .inches) {
                    TextField("", text: $draft.heightInches, prompt: prompt("10"))
                        .numericKeyboard(decimal: true)
                        .focused($focus, equals: .inches)
                }
            }
            footer("Continue") {
                focus = nil
                advance(unless: draft.bodyProblem)
            }
        }
        .aeroCard()
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            intro("Your goal", "This sets how your calories compare with what you burn.")
            VStack(spacing: 8) {
                ForEach(UserProfile.Goal.allCases) { option in
                    GoalRow(goal: option, selected: draft.goal == option) { draft.goal = option }
                }
            }
            question("Lifting experience") {
                FlowLayout(spacing: 8, lineSpacing: 2) {
                    ForEach(UserProfile.Experience.allCases) { option in
                        FQChip(title: option.label, selected: draft.experience == option) { draft.experience = option }
                    }
                }
            }
            HStack(spacing: 4) {
                Text("Training days a week").caption(13, color: Theme.ink)
                Spacer(minLength: 8)
                dayButton("minus", label: "One day fewer", by: -1)
                Text(String(draft.daysPerWeek))
                    .heading(20)
                    .frame(minWidth: 28)
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(draft.daysPerWeek) training days a week")
                dayButton("plus", label: "One day more", by: 1)
            }
            footer("Continue") { advance(unless: draft.goalProblem) }
        }
        .aeroCard()
    }

    private var trainingStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            intro("Your training", "Both are optional. They shape which exercises suit you.")
            question("Injuries to work around", hint: "Leave empty if nothing hurts.") {
                FlowLayout(spacing: 8, lineSpacing: 2) {
                    ForEach(UserProfile.Injury.allCases) { option in
                        FQChip(title: option.label, selected: draft.injuries.contains(option)) { draft.injuries.toggle(option) }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Equipment you can use").caption(13, color: Theme.ink)
                    Spacer(minLength: 8)
                    Button { draft.toggleAllEquipment() } label: {
                        Text(draft.hasAllEquipment ? "Clear all" : "Select all")
                            .heading(14, color: Theme.link)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel(draft.hasAllEquipment ? "Clear all equipment" : "Select all equipment")
                }
                FlowLayout(spacing: 8, lineSpacing: 2) {
                    ForEach(UserProfile.Equipment.allCases) { option in
                        FQChip(title: option.label, selected: draft.equipment.contains(option)) { draft.equipment.toggle(option) }
                    }
                }
                Text("Leave empty for bodyweight only.").caption()
            }
            footer("Continue") { advance(unless: nil) }
        }
        .aeroCard()
    }

    private var dietStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            intro("What you eat", "Meal ideas will stick to these. This step is optional too.")
            question("Dietary restrictions", hint: "Leave empty if you eat everything.") {
                FlowLayout(spacing: 8, lineSpacing: 2) {
                    ForEach(UserProfile.Diet.allCases) { option in
                        FQChip(title: option.label, selected: draft.diet.contains(option)) { draft.diet.toggle(option) }
                    }
                }
            }
            footer("See my targets") { advance(unless: draft.profile == nil ? "Go back and finish the earlier steps." : nil) }
        }
        .aeroCard()
    }

    @ViewBuilder
    private var targetsStep: some View {
        if let profile = draft.profile {
            let targets = TargetCalculator.targets(for: profile)
            let maintenance = Int((TargetCalculator.maintenance(for: profile) / 10).rounded() * 10)
            VStack(alignment: .leading, spacing: 16) {
                CardTitle(title: "Daily targets", trailing: "Estimate")
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(String(targets.kcal)).heading(48)
                    Text("kcal a day").caption(15)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(targets.kcal) kilocalories a day, estimate")
                HStack(spacing: 8) {
                    SpecCell(value: "\(targets.protein) g", label: "Protein")
                    SpecCell(value: "\(targets.carbs) g", label: "Carbs")
                    SpecCell(value: "\(targets.fat) g", label: "Fat")
                }
                Text("You burn about \(String(maintenance)) kcal a day, going by your age, height, weight and \(profile.daysPerWeek) training \(profile.daysPerWeek == 1 ? "day" : "days") a week (Mifflin-St Jeor formula). Your goal, \(profile.goal.label.lowercased()), sets the target from there.")
                    .copy(14)
                Text("These are estimates, not medical advice.").caption()
                footer(saving ? "Saving…" : editing ? "Save" : "Start FitQuest") { save(profile) }
                    .disabled(saving)
            }
            .aeroCard()
        }
    }

    // MARK: Pieces

    private func intro(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).heading(22).accessibilityAddTraits(.isHeader)
            Text(detail).copy(15)
        }
    }

    private func question(_ label: String, hint: String? = nil, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).caption(13, color: Theme.ink)
            content()
            if let hint { Text(hint).caption() }
        }
    }

    /// Any problem with the step, then the button that ends it.
    private func footer(_ title: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let problem {
                Label(problem, systemImage: "exclamationmark.circle.fill")
                    .font(Theme.caption(14))
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            FQButton(title: title, wide: true, action: action)
        }
    }

    private func dayButton(_ symbol: String, label: String, by change: Int) -> some View {
        let next = draft.daysPerWeek + change
        return FQIconButton(label: label, symbol: symbol) { draft.daysPerWeek = next }
            .disabled(!UserProfile.daysRange.contains(next))
            .opacity(UserProfile.daysRange.contains(next) ? 1 : 0.4)
    }

    private func prompt(_ text: String) -> Text {
        Text(text).foregroundStyle(Theme.muted.opacity(0.7))
    }

    // MARK: Moves

    private func advance(unless issue: String?) {
        if let issue {
            problem = issue
        } else if let next = Step(rawValue: step.rawValue + 1) {
            problem = nil
            withAnimation(.easeOut(duration: 0.2)) { step = next }
        }
    }

    /// One step back; from the first step, out of the flow.
    private func back() {
        focus = nil
        problem = nil
        if let previous = Step(rawValue: step.rawValue - 1) {
            withAnimation(.easeOut(duration: 0.2)) { step = previous }
        } else if editing {
            model.dismiss()
        } else {
            model.signOut()
        }
    }

    private func save(_ profile: UserProfile) {
        guard !saving else { return }
        problem = nil
        saving = true
        Task {
            do {
                try await model.completeOnboarding(profile)
                if editing {
                    model.dismiss()
                    model.flash("Profile saved · targets updated")
                }
            } catch {
                problem = "Couldn’t save your profile. Check your connection and try again."
            }
            saving = false
        }
    }
}

/// One goal as a tappable row: what it is called and what it means for eating.
private struct GoalRow: View {
    let goal: UserProfile.Goal
    let selected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(goal.label).heading(16)
                    Text(goal.detail).caption(13)
                }
                Spacer(minLength: 8)
                FQCheck(on: selected, size: 22)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 60)
            .background(shape.fill(selected ? Theme.well : .white))
            .overlay(shape.strokeBorder(selected ? Theme.azure : Theme.aqua.opacity(0.6), lineWidth: selected ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(goal.label). \(goal.detail)")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

private extension Set {
    mutating func toggle(_ member: Element) {
        if contains(member) { remove(member) } else { insert(member) }
    }
}
