import SwiftUI

struct CaloriePage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FQHead(index: "Calorie", title: "Recommended meals", meta: meta)
            ideas
                .aeroCard(vertical: 4)
                // Runs again whenever the budget, the diet or the time of day changes what should be asked,
                // but only while this page is the one on screen: every load spends a Gemini request.
                .task(id: IdeasTrigger(request: model.mealRequest, onScreen: model.page == .calorie)) {
                    if model.page == .calorie { await model.refreshRecommendations() }
                }

            if model.loggedDays.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No meals logged yet").heading(18).accessibilityAddTraits(.isHeader)
                    Text("Tap the camera button to log your first meal from a photo or a description.").copy(15)
                }
                .aeroCard()
            }
            ForEach(model.loggedDays, id: \.self) { DayLog(day: $0) }
        }
    }
}

extension CaloriePage {
    private var meta: String {
        guard let request = model.mealRequest else { return "You have \(max(0, model.remainingKcal)) kcal left today." }
        return "\(request.slot.label) ideas of up to \(request.budget) kcal, from your \(model.remainingKcal) kcal left today."
    }

    @ViewBuilder
    private var ideas: some View {
        switch model.recommendations {
        case .idle, .loading:
            HStack(spacing: 12) {
                ProgressView().tint(Theme.azure)
                Text("Finding recipes that fit…").copy(15)
            }
            .padding(.vertical, 20)
            .accessibilityElement(children: .combine)
        case .budgetUsed:
            note("That’s today’s calories", "You are at or near your target, so there is nothing to suggest until tomorrow.")
        case .limitReached:
            note("Daily limit reached", "The recipe service has used up its free requests for now. Try again later.", button: "Try again")
        case .failed:
            note("Couldn’t load meal ideas", "Check your connection and try again.", button: "Try again")
        case .loaded(let meals) where meals.isEmpty:
            note("Nothing fits right now", "No idea came in under your budget.", button: "Try again")
        case .loaded(let meals):
            VStack(alignment: .leading, spacing: 0) {
                ForEach(meals) { RecommendationRow(recommendation: $0) }
                VStack(alignment: .leading, spacing: 8) {
                    if model.usesSampleRecommendations {
                        Label("Sample ideas, not matched to your diet. Add a Spoonacular key to Secrets.plist and rebuild for real ones.", systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.caption(13))
                            .foregroundStyle(Theme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(basis).caption().fixedSize(horizontal: false, vertical: true)
                        FQButton(title: "New ideas", variant: .secondary, compact: true, action: retry)
                    }
                }
                .padding(.vertical, 12)
            }
        }
    }

    /// Where the ideas came from, what they were matched to, and how far to trust them.
    private var basis: String {
        let diet = model.profile?.dietList ?? []
        let matched = diet.isEmpty ? "your calories" : "your calories and diet (\(diet.map(\.label).joined(separator: ", ").lowercased()))"
        var lines: [String]
        switch model.recommendationSource {
        case .recipeDatabase:
            lines = ["Recipes from Spoonacular, filtered for \(matched). Calories are its estimates."]
            if diet.contains(.halal) || diet.contains(.kosher) {
                lines.append("Halal and kosher are only matched by leaving out pork, shellfish and alcohol.")
            }
        case .ai, .sample:
            lines = ["Picked by AI for \(matched). Recipe links are checked before they are shown. Calories are estimates."]
        }
        lines.append("If you have an allergy, check the ingredients yourself.")
        return lines.joined(separator: " ")
    }

    private func note(_ title: String, _ detail: String, button: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).heading(18).accessibilityAddTraits(.isHeader)
            Text(detail).copy(15)
            if let button { FQButton(title: button, variant: .secondary, compact: true, action: retry) }
        }
        .padding(.vertical, 12)
    }

    private func retry() {
        Task { await model.refreshRecommendations(force: true) }
    }
}

private struct IdeasTrigger: Equatable {
    var request: MealRequest?
    var onScreen: Bool
}

private struct RecommendationRow: View {
    let recommendation: MealRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(recommendation.name).heading(16)
                Spacer(minLength: 0)
                Text("\(recommendation.kcal) kcal").caption(13, color: Theme.ink).fixedSize()
            }
            FlowLayout(spacing: 14, lineSpacing: 4) {
                if let link = recommendation.link {
                    Link(destination: link) { Text("Recipe on \(Self.site(link)) ›").caption(13, color: Theme.link) }
                } else if let search = Self.searchURL("\(recommendation.name) recipe") {
                    // No link checked out for this one, so offer a search instead of a guess.
                    Link(destination: search) { Text("Search for a recipe ›").caption(13, color: Theme.link) }
                }
                Text("\(recommendation.protein) g protein").caption(13)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private static func searchURL(_ query: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }

    /// "recipetineats.com" from the link's address.
    private static func site(_ link: URL) -> String {
        let host = link.host ?? "the web"
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

/// One day's logged meals, as its own card.
private struct DayLog: View {
    let day: Day
    @Environment(AppModel.self) private var model

    var body: some View {
        let meals = model.logs[day] ?? []
        VStack(spacing: 0) {
            CardTitle(
                title: "\(day.relativeLabel(to: model.today)) · \(day.weekdayShort) \(day.dayOfMonth) \(day.monthShort)",
                trailing: "\(String(meals.map(\.macros).total.kcal)) kcal"
            )
            .padding(.vertical, 12)

            ForEach(meals) { meal in
                Button {
                    model.present(.meal(meal, day))
                } label: {
                    FQRow(divider: meal.id != meals.last?.id) {
                        Text(meal.time).caption(13).frame(width: 42, alignment: .leading)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(meal.name).copy(color: Theme.ink).multilineTextAlignment(.leading)
                            Text(meal.slot.label).caption()
                        }
                        Spacer(minLength: 0)
                        Text("\(meal.macros.kcal)").heading(15)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
            }
        }
        .aeroCard(vertical: 4)
    }
}
