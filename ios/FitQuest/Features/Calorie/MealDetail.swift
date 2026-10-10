import SwiftUI

struct MealDetail: View {
    let meal: Meal
    let day: Day

    @Environment(AppModel.self) private var model

    var body: some View {
        FQScrim(onClose: close) {
            VStack(alignment: .leading, spacing: 0) {
                PhotoPlaceholder(label: "Meal photo", ratio: 4.0 / 3.0)
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(meal.slot.label) · \(day.dayOfMonth) \(day.monthShort) · \(meal.time)").mono()
                        Text(meal.name).display(20, tracking: 1)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        SpecCell(value: "\(meal.macros.kcal)", label: "KCAL", padding: 12)
                        SpecCell(value: "\(meal.macros.protein)g", label: "PROTEIN", padding: 12)
                        SpecCell(value: "\(meal.macros.carbs)g", label: "CARBS", padding: 12)
                        SpecCell(value: "\(meal.macros.fat)g", label: "FAT", padding: 12)
                    }
                    Text("Estimate from \(meal.source == .photo ? "meal photo" : "typed entry"). Tap a value in the log flow to correct it.")
                        .serif(14, color: Theme.muted)
                    FQButton(title: "Close", action: close)
                }
                .padding(20)
            }
        }
    }

    private func close() {
        model.overlay = nil
    }
}
