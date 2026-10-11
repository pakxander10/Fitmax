import SwiftUI

struct GymPage: View {
    @Environment(AppModel.self) private var model

    @State private var pickerOpen: Bool

    /// `pickerOpen` starts the gym dropdown open, for previews and render tests.
    init(pickerOpen: Bool = false) {
        _pickerOpen = State(initialValue: pickerOpen)
    }

    var body: some View {
        let friends = model.friends(at: model.gymID)
        let songs = SampleData.songs[model.gymID] ?? []
        VStack(alignment: .leading, spacing: 16) {
            header

            VStack(alignment: .leading, spacing: 0) {
                CardTitle(title: "Trending songs", trailing: "This week").padding(.vertical, 12)
                ForEach(songs) { SongRow(song: $0, position: (songs.firstIndex(of: $0) ?? 0) + 1) }
                Text("Tap a song to see everyone listening · play opens Spotify").caption().padding(.vertical, 10)
            }
            .aeroCard(vertical: 4)

            VStack(alignment: .leading, spacing: 14) {
                CardTitle(title: "Your friends", trailing: "\(model.friendsHere(at: model.gymID)) here now")
                if friends.isEmpty {
                    Text("No friends at this gym yet. Tap Add friend to find people who train here.").copy(15)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 4), spacing: 16) {
                    ForEach(friends) { friend in
                        VStack(spacing: 6) {
                            FQAvatar(initials: friend.initials, size: 60, active: friend.atGym)
                            Text(friend.firstName).caption(12, color: friend.atGym ? Theme.ink : Theme.muted)
                        }
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 0.45) { model.present(.member(friend)) }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(friend.name), \(friend.atGym ? "at the gym" : "not at the gym")")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { model.present(.member(friend)) }
                    }
                }
                HStack(spacing: 8) {
                    Circle().strokeBorder(Theme.lime, lineWidth: 3).frame(width: 14, height: 14)
                    Text("At the gym · hold a profile to open it").caption()
                }
            }
            .aeroCard()
        }
        .overlayPreferenceValue(GymPickerAnchor.self) { anchor in
            if pickerOpen, let anchor {
                GeometryReader { proxy in picker(below: proxy[anchor]) }
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: pickerOpen)
        .onChange(of: model.page) { pickerOpen = false }
    }

    /// Which gym this is (tap to switch) and the way to find more friends there.
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Your gym").caption(13, color: Theme.onSky.opacity(0.9))
                    Button { pickerOpen.toggle() } label: {
                        HStack(spacing: 8) {
                            Text(model.gym.shortName)
                                .heading(22, color: Theme.onSky)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.onSky)
                                .rotationEffect(.degrees(pickerOpen ? 180 : 0))
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .anchorPreference(key: GymPickerAnchor.self, value: .bounds) { $0 }
                    .accessibilityLabel("Gym, \(model.gym.name)")
                    .accessibilityHint(pickerOpen ? "Closes the gym list" : "Shows your gyms")
                }
                .skyShadow()
                Spacer(minLength: 0)
                FQButton(title: "Add friend", compact: true) { model.present(.addFriend) }
            }
            Text("Spotify connected · \(SampleData.gyms.count) gyms").caption(13, color: Theme.onSky.opacity(0.95)).skyShadow()
        }
    }

    /// The list that drops from the gym name. Our own view rather than a system `Menu`: a menu
    /// animates its label as it closes, and the gym name changing underneath made the title jump.
    private func picker(below anchor: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { pickerOpen = false }
                .accessibilityLabel("Close gym list")
                .accessibilityAddTraits(.isButton)
            VStack(spacing: 0) {
                ForEach(SampleData.gyms) { gym in
                    let selected = gym.id == model.gymID
                    Button {
                        model.gymID = gym.id
                        pickerOpen = false
                    } label: {
                        HStack(spacing: 10) {
                            Text(gym.name).copy(16, color: Theme.ink).lineLimit(1)
                            Spacer(minLength: 8)
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.success)
                                .opacity(selected ? 1 : 0)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 50)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    if gym.id != SampleData.gyms.last?.id { Hairline().padding(.horizontal, 16) }
                }
            }
            .frame(width: 290)
            // Solid, unlike the cards: it floats over text and must stay readable.
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white)
                    .shadow(color: Theme.azure.opacity(0.4), radius: 16, y: 8)
            }
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.aqua.opacity(0.5), lineWidth: 1))
            .offset(x: anchor.minX, y: anchor.maxY + 4)
        }
    }
}

private struct GymPickerAnchor: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

private struct SongRow: View {
    let song: Song
    let position: Int

    @Environment(AppModel.self) private var model

    var body: some View {
        let audience = model.audience(of: song)
        let faces = Array((audience.now + audience.earlier).prefix(3))
        FQRow {
            Button { model.present(.song(song)) } label: {
                HStack(spacing: 12) {
                    Text("#\(position)").heading(14).frame(width: 24, alignment: .leading)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(song.title).copy(color: Theme.ink).lineLimit(1)
                        Text(song.artist).caption().lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 0) {
                        HStack(spacing: -4) {
                            ForEach(faces) { FQAvatar(initials: $0.initials, size: 24) }
                        }
                        if audience.total > faces.count {
                            Text("+\(audience.total - faces.count)").caption(11).padding(.leading, 5)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Number \(position), \(song.title) by \(song.artist), \(audience.total) listeners")
            .accessibilityHint("Shows everyone listening")
            PlayButton(song: song)
        }
    }
}

/// Opens a song in Spotify. If the system refuses to open the link, as it did on device
/// ("Failed to open URL", LaunchServices error 115), the page opens in the in-app browser instead.
struct PlayButton: View {
    let song: Song

    @Environment(\.openURL) private var openURL
    @State private var page: URL?

    var body: some View {
        if let url = song.spotifyURL {
            Button {
                openURL(url) { opened in
                    if !opened { page = url }
                }
            } label: {
                FQIconGlyph(symbol: "play.fill")
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Play \(song.title) on Spotify")
            .webSheet($page)
        }
    }
}

extension Song {
    var spotifyURL: URL? {
        let query = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        return query.flatMap { URL(string: "https://open.spotify.com/search/\($0)") }
    }
}

/// One person in a list: who they are, what you may know about them, and a way to add them.
struct MemberRow: View {
    let member: Member
    var divider = true

    @Environment(AppModel.self) private var model

    var body: some View {
        let friend = model.isFriend(member)
        let open = model.canView(member)
        FQRow(divider: divider) {
            Button { model.present(.member(member)) } label: {
                HStack(spacing: 12) {
                    FQAvatar(initials: member.initials, size: 44, active: open && member.atGym)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(member.name).copy(color: Theme.ink).lineLimit(1)
                        Text(subtitle(friend: friend, open: open)).caption().lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .disabled(!open)
            .accessibilityHint(open ? "Opens their profile" : "")
            if friend {
                Label("Friends", systemImage: "checkmark")
                    .font(Theme.caption(13))
                    .foregroundStyle(Theme.success)
            } else if model.hasRequested(member) {
                Text("Requested").caption(13)
            } else {
                FQButton(title: member.isPrivate ? "Request" : "Add", variant: member.isPrivate ? .secondary : .primary, compact: true) {
                    model.addFriend(member)
                }
                .accessibilityLabel(member.isPrivate ? "Send \(member.name) a friend request" : "Add \(member.name) as a friend")
            }
        }
    }

    private func subtitle(friend: Bool, open: Bool) -> String {
        guard open else { return "Private profile" }
        let place = member.atGym ? "at the gym now" : "\(member.streak)-day streak"
        return "Pet level \(member.level) · \(place)"
    }
}
