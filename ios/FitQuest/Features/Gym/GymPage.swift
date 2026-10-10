import SwiftUI

struct GymPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let friends = SampleData.friends.filter { $0.gymID == model.gymID }
        VStack(alignment: .leading, spacing: 40) {
            VStack(alignment: .leading, spacing: 12) {
                Text("04 · YOUR GYM").mono()
                Menu {
                    ForEach(SampleData.gyms) { gym in
                        Button(gym.name) { model.gymID = gym.id }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text(model.gym.shortName).display(26)
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .light)).foregroundStyle(Theme.ink)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Gym, \(model.gym.name)")
                Text("SPOTIFY CONNECTED · \(SampleData.gyms.count) GYMS").mono()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Trending songs").display(20, tracking: 1).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("THIS WEEK").mono()
                }
                VStack(spacing: 0) {
                    ForEach(Array((SampleData.songs[model.gymID] ?? []).enumerated()), id: \.element.id) { position, song in
                        SongRow(position: position + 1, song: song)
                    }
                }
                Text("PLAY OPENS SPOTIFY").mono()
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Your friends").display(20, tracking: 1).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("\(friends.filter(\.atGym).count) HERE NOW").mono()
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 4), spacing: 20) {
                    ForEach(friends) { friend in
                        VStack(spacing: 8) {
                            FQAvatar(
                                initials: friend.initials, size: 60,
                                border: friend.atGym ? Theme.success : Theme.hairlineStrong,
                                borderWidth: friend.atGym ? 2 : 1
                            )
                            Text(friend.firstName).mono(10, tracking: 1, color: friend.atGym ? Theme.ink : Theme.muted)
                        }
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 0.45) { model.overlay = .friend(friend) }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(friend.name), \(friend.atGym ? "at the gym" : "not at the gym")")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { model.overlay = .friend(friend) }
                    }
                }
                HStack(spacing: 10) {
                    Circle().strokeBorder(Theme.success, lineWidth: 2).frame(width: 14, height: 14)
                    Text("AT THE GYM · HOLD A PROFILE TO OPEN IT").mono()
                }
                .padding(.top, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { Hairline() }
            }
        }
    }
}

private struct SongRow: View {
    let position: Int
    let song: Song

    var body: some View {
        FQRow {
            Text("#\(position)").mono(tracking: 1, color: Theme.ink).frame(width: 24, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title).serif(color: Theme.ink).lineLimit(1)
                Text(song.artist).mono().lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 0) {
                HStack(spacing: -6) {
                    ForEach(song.listeners, id: \.self) { initials in
                        FQAvatar(initials: initials, size: 22, fill: Theme.surfaceElevated, border: Theme.canvas)
                    }
                }
                if song.more > 0 {
                    Text("+\(song.more)").mono(9, tracking: 1).padding(.leading, 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(song.listeners.count + song.more) listening now")
            if let url = spotifyURL {
                Link(destination: url) { FQIconGlyph(symbol: "play") }
                    .accessibilityLabel("Play \(song.title) on Spotify")
            }
        }
    }

    private var spotifyURL: URL? {
        let query = "\(song.title) \(song.artist)".addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        return query.flatMap { URL(string: "https://open.spotify.com/search/\($0)") }
    }
}
