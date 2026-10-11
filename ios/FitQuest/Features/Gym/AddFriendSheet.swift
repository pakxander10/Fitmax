import SwiftUI

/// Everyone on the app who goes to the selected gym and is not a friend yet, with a name search.
struct AddFriendSheet: View {
    @Environment(AppModel.self) private var model

    @State private var query = ""
    /// Who was not a friend when the sheet opened. People added from here stay listed,
    /// marked as friends, instead of vanishing mid-scroll.
    @State private var candidates: [Member]?

    var body: some View {
        let gym = model.gym
        let everyone = candidates ?? model.people(at: gym.id)
        let shown = everyone.filter { $0.matches(query) }
        FQOverlay(title: "Add friend", onBack: model.dismiss) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("People at \(gym.shortName)").heading(18).accessibilityAddTraits(.isHeader)
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.muted)
                        TextField("", text: $query, prompt: Text("Search by name").foregroundStyle(Theme.muted.opacity(0.7)))
                            .font(Theme.copy(16))
                            .foregroundStyle(Theme.ink)
                            .tint(Theme.azure)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .accessibilityLabel("Search people at \(gym.shortName)")
                        if !query.isEmpty {
                            Button { query = "" } label: {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(Theme.muted)
                                    .frame(width: 32, height: 44).contentShape(Rectangle())
                            }
                            .buttonStyle(PressStyle())
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Capsule().fill(.white))
                    .overlay(Capsule().strokeBorder(Theme.aqua.opacity(0.6), lineWidth: 1))
                    Text("Shows members who use FitMax and train at this gym. Switch gyms on the previous page to look elsewhere.")
                        .caption()
                }
                .aeroCard()

                VStack(alignment: .leading, spacing: 0) {
                    if shown.isEmpty {
                        Text(everyone.isEmpty
                            ? "You’re already friends with everyone at \(gym.shortName)."
                            : "No one at \(gym.shortName) matches “\(query.trimmingCharacters(in: .whitespaces))”.")
                            .copy(15)
                            .padding(.vertical, 16)
                    } else {
                        ForEach(shown) { member in
                            MemberRow(member: member, divider: member.id != shown.last?.id)
                        }
                    }
                }
                .aeroCard(vertical: 4)
            }
        }
        .onAppear { candidates = model.people(at: gym.id) }
    }
}
