import SwiftUI

struct MealDetail: View {
    let meal: Meal
    let day: Day

    @Environment(AppModel.self) private var model

    var body: some View {
        FQScrim(onClose: model.dismiss) {
            VStack(alignment: .leading, spacing: 14) {
                PhotoPlaceholder(label: "Meal photo", ratio: 4.0 / 3.0, symbol: "fork.knife")
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(meal.slot.label) · \(day.dayOfMonth) \(day.monthShort) · \(meal.time)").caption()
                    Text(meal.name).heading(20)
                }
                HStack(alignment: .top, spacing: 8) {
                    SpecCell(value: "\(meal.macros.kcal)", label: "kcal")
                    SpecCell(value: "\(meal.macros.protein) g", label: "Protein")
                    SpecCell(value: "\(meal.macros.carbs) g", label: "Carbs")
                    SpecCell(value: "\(meal.macros.fat) g", label: "Fat")
                }
                Text("Estimate from \(meal.source == .photo ? "meal photo" : "typed entry"). Tap a value in the log flow to correct it.")
                    .copy(14, color: Theme.muted)
                FQButton(title: "Close", variant: .secondary, action: model.dismiss)
            }
            .padding(16)
        }
    }
}
