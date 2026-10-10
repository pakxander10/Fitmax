import SwiftUI

struct CaloriePage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let recommendations = SampleData.recommendations
        VStack(alignment: .leading, spacing: 16) {
            FQHead(
                index: "Calorie",
                title: "Recommended meals",
                meta: "Fits your remaining \(max(0, model.remainingKcal)) kcal. Peanut-free, per your profile."
            )
            VStack(spacing: 0) {
                ForEach(recommendations) { recommendation in
                    RecommendationRow(recommendation: recommendation, divider: recommendation.id != recommendations.last?.id)
                }
            }
            .aeroCard(vertical: 4)

            ForEach(model.loggedDays, id: \.self) { DayLog(day: $0) }
        }
    }
}

private struct RecommendationRow: View {
    let recommendation: MealRecommendation
    let divider: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(recommendation.name).heading(16)
                Spacer(minLength: 0)
                Text("\(recommendation.kcal) kcal").caption(13, color: Theme.ink).fixedSize()
            }
            FlowLayout(spacing: 14, lineSpacing: 4) {
                if let recipe = Self.searchURL("\(recommendation.name) recipe") {
                    Link(destination: recipe) { Text("Recipe ›").caption(13, color: Theme.link) }
                }
                if let map = Self.mapURL(recommendation.name) {
                    Link(destination: map) {
                        Text("\(recommendation.place) · \(recommendation.distance) ›").caption(13, color: Theme.link)
                    }
                }
                Text("\(recommendation.protein) g protein").caption(13)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { if divider { Hairline() } }
    }

    private static func searchURL(_ query: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }

    private static func mapURL(_ query: String) -> URL? {
        guard let path = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        return URL(string: "https://www.google.com/maps/search/\(path)")
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
