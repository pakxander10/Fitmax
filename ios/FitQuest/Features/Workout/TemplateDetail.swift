import SwiftUI

/// One saved workout: what is in it, and every past session of it.
struct TemplateDetail: View {
    let templateID: String

    @Environment(AppModel.self) private var model

    var body: some View {
        let template = model.templates.first { $0.id == templateID }
        FQOverlay(title: template?.name ?? "Workout", onBack: model.dismiss) {
            if let template {
                content(template)
            } else {
                Text("This workout was removed.").copy().aeroCard()
            }
        }
    }

    private func content(_ template: WorkoutTemplate) -> some View {
        let sessions = model.sessions(for: template.id)
        let done = template.exercises.filter(model.isDone).count
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    SpecCell(value: "\(template.exercises.count)", label: "Exercises")
                    SpecCell(value: "\(sessions.count)", label: "Sessions")
                    SpecCell(value: sessions.map(\.volume).max().map(Self.pounds) ?? "—", label: "Best volume lb")
                }
                FQButton(title: done == 0 ? "Start workout" : done == template.exercises.count ? "Review workout" : "Continue workout") {
                    model.startWorkout(template.id)
                }
                .disabled(template.exercises.isEmpty)
            }
            .aeroCard()

            VStack(alignment: .leading, spacing: 0) {
                CardTitle(title: "Exercises", trailing: done > 0 ? "\(done)/\(template.exercises.count) done today" : nil)
                    .padding(.vertical, 12)
                ForEach(template.exercises) { exercise in
                    ExerciseRow(exercise: exercise, templateID: template.id, divider: exercise.id != template.exercises.last?.id) { EmptyView() }
                }
            }
            .aeroCard(vertical: 4)

            VStack(alignment: .leading, spacing: 0) {
                CardTitle(title: "Previous sessions", trailing: sessions.isEmpty ? nil : "Newest first")
                    .padding(.vertical, 12)
                if sessions.isEmpty {
                    Text("No sessions yet. Finish this workout and it shows up here.")
                        .copy(14)
                        .padding(.bottom, 12)
                } else {
                    ForEach(sessions) { session in
                        SessionRow(session: session, divider: session.id != sessions.last?.id)
                    }
                }
            }
            .aeroCard(vertical: 4)
        }
    }

    static func pounds(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }
}

private struct SessionRow: View {
    let session: WorkoutSession
    let divider: Bool

    @Environment(AppModel.self) private var model

    private var summary: String {
        let sets = "\(session.sets) sets"
        return session.minutes.map { "\($0) min · \(sets)" } ?? sets
    }

    var body: some View {
        FQRow(alignment: .top, divider: divider) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(session.day.weekdayShort) \(session.day.dayOfMonth) \(session.day.monthShort)").heading(15)
                Text(session.day.relativeLabel(to: model.today)).caption()
            }
            .frame(width: 92, alignment: .leading)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(TemplateDetail.pounds(session.volume)) lb").heading(15)
                Text(summary).caption()
                if !session.highlight.isEmpty {
                    Text("Top set · \(session.highlight)").caption()
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
