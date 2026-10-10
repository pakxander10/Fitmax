import SwiftUI

struct FriendProfile: View {
    let friend: Friend
    @Environment(AppModel.self) private var model

    private var facts: [(String, String)] {
        let gym = SampleData.gyms.first { $0.id == friend.gymID }
        return [
            ("GYM", gym?.name ?? "—"),
            ("THIS WEEK", "\(friend.week) workouts"),
            ("LISTENING", friend.song ?? "Nothing right now"),
            ("PET", friend.pet),
        ]
    }

    var body: some View {
        FQOverlay(title: "Friend", onBack: { model.overlay = nil }) {
            VStack(alignment: .leading, spacing: 32) {
                HStack(spacing: 20) {
                    FQAvatar(
                        initials: friend.initials, size: 80,
                        border: friend.atGym ? Theme.success : Theme.hairlineStrong,
                        borderWidth: friend.atGym ? 2 : 1
                    )
                    VStack(alignment: .leading, spacing: 6) {
                        Text(friend.name).display(28)
                        Text(friend.since.map { "WORKING OUT · SINCE \($0)" } ?? "NOT AT THE GYM")
                            .mono(color: friend.atGym ? Theme.success : Theme.muted)
                    }
                }
                HStack(alignment: .top, spacing: 16) {
                    SpecCell(value: friend.rank.rawValue, label: "HUNTER RANK")
                    SpecCell(value: "\(friend.level)", label: "LEVEL")
                    SpecCell(value: "\(friend.streak)", label: "DAY STREAK")
                }
                VStack(spacing: 0) {
                    ForEach(facts, id: \.0) { fact in
                        FQRow(alignment: .firstTextBaseline) {
                            Text(fact.0).mono().frame(width: 96, alignment: .leading)
                            Text(fact.1).serif(color: Theme.ink)
                        }
                    }
                }
                HStack(spacing: 12) {
                    FQButton(title: "Visit pet") { model.flash("PET VISITS · COMING SOON") }
                    FQButton(title: "Message", variant: .ghost) { model.flash("MESSAGES · COMING SOON") }
                }
            }
        }
    }
}
