import SwiftUI

/// Everyone at the gym who is playing a song now or played it this week.
struct SongListenersSheet: View {
    let song: Song

    @Environment(AppModel.self) private var model

    var body: some View {
        let audience = model.audience(of: song)
        FQOverlay(title: "Listeners", onBack: model.dismiss) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title).heading(22).accessibilityAddTraits(.isHeader)
                        Text(song.artist).caption(13)
                        Text("\(audience.total) listeners at \(model.gym.shortName) this week").caption()
                    }
                    Spacer(minLength: 0)
                    if let url = song.spotifyURL {
                        Link(destination: url) { FQIconGlyph(symbol: "play.fill") }
                            .accessibilityLabel("Play \(song.title) on Spotify")
                    }
                }
                .aeroCard()

                group("Listening now", audience.now, empty: "No one is playing this right now.")
                group("Listened this week", audience.earlier, empty: "No one else played this earlier in the week.")

                if audience.hiddenCount > 0 {
                    Label(
                        "\(audience.hiddenCount) more \(audience.hiddenCount == 1 ? "listener has" : "listeners have") a private profile",
                        systemImage: "lock.fill"
                    )
                    .font(Theme.caption(13))
                    .foregroundStyle(Theme.muted)
                    .aeroCard(vertical: 12)
                }
            }
        }
    }

    private func group(_ title: String, _ members: [Member], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            CardTitle(title: title, trailing: members.isEmpty ? nil : "\(members.count)").padding(.vertical, 12)
            if members.isEmpty {
                Text(empty).copy(15).padding(.bottom, 14)
            } else {
                ForEach(members) { MemberRow(member: $0, divider: $0.id != members.last?.id) }
            }
        }
        .aeroCard(vertical: 4)
    }
}
