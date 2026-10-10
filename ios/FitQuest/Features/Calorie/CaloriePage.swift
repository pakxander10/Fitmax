import SwiftUI

struct CaloriePage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            FQHead(
                index: "01 · CALORIE",
                title: "Recommended meals",
                meta: "Fits your remaining \(max(0, model.remainingKcal)) kcal. Peanut-free, per your profile."
            )
            VStack(spacing: 0) {
                ForEach(SampleData.recommendations) { RecommendationRow(recommendation: $0) }
            }
            VStack(alignment: .leading, spacing: 24) {
                Text("Previous logs").display(20, tracking: 1).accessibilityAddTraits(.isHeader)
                ForEach(model.loggedDays, id: \.self) { DayLog(day: $0) }
            }
        }
    }
}

private struct RecommendationRow: View {
    let recommendation: MealRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(recommendation.name).display(18, tracking: 1)
                Spacer(minLength: 0)
                Text("\(recommendation.kcal) KCAL").mono().fixedSize()
            }
            FlowLayout(spacing: 16) {
                if let recipe = Self.searchURL("\(recommendation.name) recipe") {
                    Link(destination: recipe) { Text("Recipe →").mono(color: Theme.link) }
                }
                if let map = Self.mapURL(recommendation.name) {
                    Link(destination: map) {
                        Text("\(recommendation.place) · \(recommendation.distance) →").mono(color: Theme.link)
                    }
                }
                Text("\(recommendation.protein) G PROTEIN").mono()
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Hairline() }
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

private struct DayLog: View {
    let day: Day
    @Environment(AppModel.self) private var model

    var body: some View {
        let meals = model.logs[day] ?? []
        VStack(spacing: 0) {
            HStack {
                Text("\(day.relativeLabel(to: model.today)) · \(day.weekdayShort) \(day.dayOfMonth) \(day.monthShort)")
                    .mono(color: Theme.ink)
                Spacer(minLength: 8)
                Text("\(String(meals.map(\.macros).total.kcal)) KCAL").mono()
            }
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) { Hairline(color: Theme.hairlineStrong) }

            ForEach(meals) { meal in
                Button {
                    model.overlay = .meal(meal, day)
                } label: {
                    FQRow {
                        Text(meal.time).mono().frame(width: 44, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(meal.name).serif(color: Theme.ink).multilineTextAlignment(.leading)
                            Text(meal.slot.label).mono()
                        }
                        Spacer(minLength: 0)
                        Text("\(meal.macros.kcal)").mono(color: Theme.ink)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
            }
        }
    }
}
