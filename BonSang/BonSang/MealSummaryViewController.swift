import UIKit

final class MealSummaryViewController: UIViewController {
    var meal: MealHistoryItem
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    init(meal: MealHistoryItem) {
        self.meal = meal
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Résumé nutritionnel"
        view.backgroundColor = NutritionPalette.background
        configureLayout()
        buildContent()
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
    }

    private func buildContent() {
        stackView.addArrangedSubview(makeHeroCard())
        stackView.addArrangedSubview(makeTotalsCard())
        stackView.addArrangedSubview(makeFoodsCard())
    }

    private func makeHeroCard() -> UIView {
        let card = CardView()
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 10

        let title = UILabel()
        title.font = .preferredFont(forTextStyle: .title2)
        title.numberOfLines = 0
        title.text = "Repas enregistré"

        let dateLabel = UILabel()
        dateLabel.font = .preferredFont(forTextStyle: .subheadline)
        dateLabel.textColor = .secondaryLabel
        let date = ISO8601DateFormatter().date(from: meal.mealTakenAt) ?? Date()
        dateLabel.text = Date.mealDisplayFormatter.string(from: date)

        let glycemic = UILabel()
        glycemic.font = .preferredFont(forTextStyle: .headline)
        glycemic.numberOfLines = 0
        glycemic.text = "Impact glycémique : \(meal.glycemicImpact.message) (score \(meal.glycemicImpact.score.compactNutritionText))"
        glycemic.textColor = meal.glycemicImpact.level == "élevé" ? NutritionPalette.danger : (meal.glycemicImpact.level == "modéré" ? NutritionPalette.warning : NutritionPalette.tint)

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(dateLabel)
        stack.addArrangedSubview(glycemic)
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])

        return card
    }

    private func makeTotalsCard() -> UIView {
        let card = CardView()
        let outerStack = UIStackView()
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.axis = .vertical
        outerStack.spacing = 12

        let title = UILabel()
        title.text = "Totaux du repas"
        title.font = .preferredFont(forTextStyle: .headline)

        outerStack.addArrangedSubview(title)
        outerStack.addArrangedSubview(metricRow("Calories", value: meal.totals.calories.compactNutritionText))
        outerStack.addArrangedSubview(metricRow("Glucides", value: "\(meal.totals.carbohydratesTotalG.compactNutritionText) g"))
        outerStack.addArrangedSubview(metricRow("Glucides nets", value: "\(meal.totals.netCarbsG.compactNutritionText) g"))
        outerStack.addArrangedSubview(metricRow("Protéines", value: "\(meal.totals.proteinG.compactNutritionText) g"))
        outerStack.addArrangedSubview(metricRow("Lipides", value: "\(meal.totals.fatTotalG.compactNutritionText) g"))
        outerStack.addArrangedSubview(metricRow("Fibres", value: "\(meal.totals.fiberG.compactNutritionText) g"))
        outerStack.addArrangedSubview(metricRow("Sucres", value: "\(meal.totals.sugarG.compactNutritionText) g"))

        card.addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            outerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            outerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            outerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])
        return card
    }

    private func makeFoodsCard() -> UIView {
        let card = CardView()
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12

        let title = UILabel()
        title.text = "Détail par plat"
        title.font = .preferredFont(forTextStyle: .headline)
        stack.addArrangedSubview(title)

        meal.items.forEach { item in
            stack.addArrangedSubview(foodItemView(item))
        }

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])
        return card
    }

    private func metricRow(_ title: String, value: String) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .body)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.textAlignment = .right
        valueLabel.font = .preferredFont(forTextStyle: .headline)

        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(valueLabel)
        return row
    }

    private func foodItemView(_ item: AnalyzedFoodItem) -> UIView {
        let box = UIView()
        box.backgroundColor = UIColor.tertiarySystemGroupedBackground
        box.layer.cornerRadius = 14

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 6

        let name = UILabel()
        name.font = .preferredFont(forTextStyle: .headline)
        name.numberOfLines = 0
        name.text = item.description?.capitalizedSentence ?? "Plat inconnu"

        let grams = UILabel()
        grams.font = .preferredFont(forTextStyle: .subheadline)
        grams.textColor = .secondaryLabel
        grams.text = item.grams.map { $0.gramsText } ?? "--"

        let details = UILabel()
        details.font = .preferredFont(forTextStyle: .footnote)
        details.numberOfLines = 0
        if item.found {
            details.text = "Calories \(item.calories?.compactNutritionText ?? "0") • Glucides \(item.carbohydratesTotalG?.compactNutritionText ?? "0") g • Protéines \(item.proteinG?.compactNutritionText ?? "0") g • Lipides \(item.fatTotalG?.compactNutritionText ?? "0") g"
        } else {
            details.text = item.error ?? "Impossible de récupérer la composition nutritionnelle."
            details.textColor = NutritionPalette.danger
        }

        stack.addArrangedSubview(name)
        stack.addArrangedSubview(grams)
        stack.addArrangedSubview(details)
        box.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: box.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -14)
        ])

        return box
    }
}
