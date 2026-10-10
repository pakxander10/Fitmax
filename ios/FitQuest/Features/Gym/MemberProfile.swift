import SwiftUI

/// Another member's profile. Friends get pet visits and messages; anyone else gets an Add friend button.
struct MemberProfile: View {
    let member: Member
    @Environment(AppModel.self) private var model

    private var facts: [(String, String)] {
        let gym = SampleData.gyms.first { $0.id == member.gymID }
        return [
            ("Gym", gym?.name ?? "—"),
            ("Listening", member.song ?? "Nothing right now"),
            ("Pet", member.pet),
        ]
    }

    var body: some View {
        let friend = model.isFriend(member)
        FQOverlay(title: friend ? "Friend" : "Member", onBack: model.dismiss) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 16) {
                        FQAvatar(initials: member.initials, size: 72, active: member.atGym)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name).heading(24)
                            Text(member.since.map { "Working out · since \($0)" } ?? "Not at the gym")
                                .caption(13, color: member.atGym ? Theme.success : Theme.muted)
                        }
                    }
                    HStack(alignment: .top, spacing: 8) {
                        SpecCell(value: "\(member.level)", label: "Pet level")
                        SpecCell(value: "\(member.streak)", label: "Day streak")
                        SpecCell(value: member.week, label: "Workouts this week")
                    }
                }
                .aeroCard()

                VStack(spacing: 0) {
                    ForEach(facts, id: \.0) { fact in
                        FQRow(alignment: .firstTextBaseline, divider: fact.0 != facts.last?.0) {
                            Text(fact.0).caption(13).frame(width: 88, alignment: .leading)
                            Text(fact.1).copy(color: Theme.ink)
                        }
                    }
                }
                .aeroCard(vertical: 4)

                HStack(spacing: 12) {
                    if friend {
                        FQButton(title: "Visit pet") { model.flash("Pet visits · coming soon") }
                        FQButton(title: "Message", variant: .secondary) { model.flash("Messages · coming soon") }
                    } else {
                        FQButton(title: "Add friend") { model.addFriend(member) }
                    }
                }
                .aeroCard()
            }
        }
    }
}
