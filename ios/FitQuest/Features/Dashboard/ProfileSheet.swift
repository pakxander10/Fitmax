import SwiftUI

struct ProfileSheet: View {
    @Environment(AppModel.self) private var model

    // Previews and render tests have nobody signed in, so they show the sample person.
    private var account: Account { model.account ?? SampleData.account }
    private var profile: UserProfile { model.profile ?? SampleData.profile }

    /// Height and weight come from onboarding; the rest from the latest body scan, in inches.
    private var biometrics: [(String, String)] {
        func inches(_ field: Biometrics.Field) -> String {
            model.biometrics?.value(of: field).map { UserProfile.figure($0 / UserProfile.cmPerInch) } ?? "–"
        }
        return [
            (profile.heightText, "Height"), (profile.weightText, "Weight lb"), (inches(.neck), "Neck in"),
            (inches(.chest), "Chest in"), (inches(.waist), "Waist in"), (inches(.hips), "Hips in"),
        ]
    }

    private var scanSummary: String {
        guard let scan = model.biometrics else {
            return "Measurements and a body-fat estimate appear here after your first scan."
        }
        let fat = scan.bodyFatPct.map { "Body fat about \(UserProfile.figure($0))%" } ?? "Body fat not estimated"
        return "\(fat) · estimates from a photo, not tape-measure readings."
    }

    private var facts: [(String, String)] {
        let targets = model.targets
        return [
            ("Goal", profile.goalSummary),
            ("Experience", profile.experience.label),
            ("Injuries", profile.injurySummary),
            ("Equipment", profile.equipmentSummary),
            ("Diet", profile.dietSummary),
            ("Targets", "\(targets.kcal) kcal a day · estimate\nP \(targets.protein) · C \(targets.carbs) · F \(targets.fat) g"),
        ]
    }

    var body: some View {
        @Bindable var model = model
        let game = model.game
        FQOverlay(title: "Profile", onBack: model.dismiss) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    FQAvatar(initials: account.initials, size: 72)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.name).heading(24).lineLimit(2).minimumScaleFactor(0.7)
                        Text("Pet level \(game.level) · \(game.xp.formatted(.number.grouping(.automatic))) XP").caption(13)
                        Label(
                            model.hidesProfileFromNonFriends ? "Visible to friends only" : "Visible to everyone at your gym",
                            systemImage: model.hidesProfileFromNonFriends ? "lock.fill" : "eye"
                        )
                        .font(Theme.caption(12))
                        .foregroundStyle(Theme.muted)
                    }
                }
                .aeroCard()

                VStack(alignment: .leading, spacing: 12) {
                    CardTitle(
                        title: "Biometrics",
                        trailing: model.biometrics.map { "Scanned \($0.measuredAt.formatted(date: .abbreviated, time: .omitted))" } ?? "No scan yet"
                    )
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(biometrics, id: \.1) { SpecCell(value: $0.0, label: $0.1) }
                    }
                    Text(scanSummary)
                        .caption()
                        .fixedSize(horizontal: false, vertical: true)
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

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $model.hidesProfileFromNonFriends) {
                        Text("Hide my profile from non-friends").heading(16)
                    }
                    .tint(Theme.lime)
                    Text(model.hidesProfileFromNonFriends
                        ? "Only friends can see your profile, gym activity and what you listen to. Others at your gym see you counted as a private listener, and can find you by name to send a friend request."
                        : "Anyone at your gym can see your profile, gym activity and what you listen to.")
                        .copy(13, color: Theme.muted)
                }
                .aeroCard()

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        FQButton(title: "New scan") { model.present(.bodyScan) }
                        FQButton(title: "Edit", variant: .secondary) { model.present(.editProfile) }
                    }
                    Text("All body measurements are estimates from photos. Trends matter more than single readings. This app is not medical advice.")
                        .copy(13, color: Theme.muted)
                }
                .aeroCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Signed in as \(account.email)").copy(14)
                    FQButton(title: "Sign out", variant: .secondary, action: model.signOut)
                }
                .aeroCard()
            }
        }
        .task { await model.loadBiometrics() }
    }
}
