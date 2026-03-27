import UIKit

final class MealSummaryViewController: UIViewController {

    @IBOutlet weak var mealDateLabel: UILabel!
    @IBOutlet weak var glycemicImpactLabel: UILabel!

    @IBOutlet weak var caloriesValueLabel: UILabel!
    @IBOutlet weak var carbsValueLabel: UILabel!
    @IBOutlet weak var netCarbsValueLabel: UILabel!
    @IBOutlet weak var proteinValueLabel: UILabel!
    @IBOutlet weak var fatValueLabel: UILabel!
    @IBOutlet weak var fiberValueLabel: UILabel!
    @IBOutlet weak var sugarValueLabel: UILabel!

    @IBOutlet weak var foodsTableView: UITableView!

    var meal: MealHistoryItem?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Résumé nutritionnel"
        view.backgroundColor = .systemBackground

        foodsTableView.dataSource = self
        foodsTableView.delegate = self
        foodsTableView.rowHeight = UITableView.automaticDimension
        foodsTableView.estimatedRowHeight = 100
        foodsTableView.isScrollEnabled = false
        foodsTableView.tableFooterView = UIView()

        configureUI()
    }

    private func configureUI() {
        guard let meal else { return }

        let date = ISO8601DateFormatter().date(from: meal.mealTakenAt) ?? Date()
        mealDateLabel.text = Date.mealDisplayFormatter.string(from: date)

        glycemicImpactLabel.text = "Impact glycémique : \(meal.glycemicImpact.message) (score \(meal.glycemicImpact.score.compactNutritionText))"

        switch meal.glycemicImpact.level.lowercased() {
        case "élevé":
            glycemicImpactLabel.textColor = .systemRed
        case "modéré":
            glycemicImpactLabel.textColor = .systemOrange
        default:
            glycemicImpactLabel.textColor = .systemBlue
        }

        caloriesValueLabel.text = meal.totals.calories.compactNutritionText
        carbsValueLabel.text = "\(meal.totals.carbohydratesTotalG.compactNutritionText) g"
        netCarbsValueLabel.text = "\(meal.totals.netCarbsG.compactNutritionText) g"
        proteinValueLabel.text = "\(meal.totals.proteinG.compactNutritionText) g"
        fatValueLabel.text = "\(meal.totals.fatTotalG.compactNutritionText) g"
        fiberValueLabel.text = "\(meal.totals.fiberG.compactNutritionText) g"
        sugarValueLabel.text = "\(meal.totals.sugarG.compactNutritionText) g"

        foodsTableView.reloadData()
    }
}

extension MealSummaryViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        meal?.items.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let item = meal?.items[indexPath.row] else {
            return UITableViewCell()
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "FoodSummaryCell", for: indexPath)

        var config = cell.defaultContentConfiguration()
        config.text = item.description?.capitalizedSentence ?? "Plat inconnu"

        if item.found {
            let calories = item.calories?.compactNutritionText ?? "0"
            let carbs = item.carbohydratesTotalG?.compactNutritionText ?? "0"
            let protein = item.proteinG?.compactNutritionText ?? "0"
            let fat = item.fatTotalG?.compactNutritionText ?? "0"
            let grams = item.grams?.gramsText ?? "--"

            config.secondaryText = "\(grams) • Calories \(calories) • Glucides \(carbs) g • Protéines \(protein) g • Lipides \(fat) g"
        } else {
            config.secondaryText = item.error ?? "Impossible de récupérer la composition nutritionnelle."
        }

        config.textProperties.numberOfLines = 0
        config.secondaryTextProperties.numberOfLines = 0
        cell.contentConfiguration = config

        return cell
    }
}
