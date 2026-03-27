import UIKit

final class MealHistoryViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyStateLabel: UILabel!

    private let api = NutritionAPIService.shared

    private var meals: [MealHistoryItem] = [] {
        didSet {
            tableView.reloadData()
            emptyStateLabel.isHidden = !meals.isEmpty
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 72
        tableView.tableFooterView = UIView()

        emptyStateLabel.text = "Aucun repas enregistré pour le moment.\nAppuie sur + pour ajouter ton premier repas."
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.textColor = .secondaryLabel
        emptyStateLabel.isHidden = true

        fetchHistory()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchHistory()
    }

    private func fetchHistory() {
        Task {
            do {
                let history = try await api.fetchHistory()

                await MainActor.run {
                    self.meals = history.sorted { mealDate(from: $0) > mealDate(from: $1) }
                }
            } catch {
                await MainActor.run {
                    self.meals = []
                    self.emptyStateLabel.isHidden = false
                    self.showSimpleAlert(
                        title: "Historique indisponible",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

  
    @IBAction func addMealTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let composer = storyboard.instantiateViewController(withIdentifier: "AjouterRepasViewController") as! AjouterRepasViewController
        composer.onMealSaved = { [weak self] _ in
            self?.fetchHistory()
        }
        navigationController?.pushViewController(composer, animated: true)
    }

    private func mealDate(from meal: MealHistoryItem) -> Date {
        ISO8601DateFormatter().date(from: meal.mealTakenAt) ?? Date.distantPast
    }
}

extension MealHistoryViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        meals.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let meal = meals[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "MealCell", for: indexPath)

        var config = cell.defaultContentConfiguration()

        let date = ISO8601DateFormatter().date(from: meal.mealTakenAt) ?? Date()
        let formattedDate = Date.mealDisplayFormatter.string(from: date)

        config.text = formattedDate
        config.secondaryText = "\(meal.items.count) plat(s) • \(meal.totals.calories.compactNutritionText) kcal • Impact \(meal.glycemicImpact.level)"
        config.textProperties.numberOfLines = 1
        config.secondaryTextProperties.numberOfLines = 2

        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let meal = meals[indexPath.row]

        let sheet = UIAlertController(
            title: "Repas",
            message: "Que veux-tu faire ?",
            preferredStyle: .actionSheet
        )

        sheet.addAction(UIAlertAction(title: "Voir le détail", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let summaryVC = storyboard.instantiateViewController(withIdentifier: "MealSummaryViewController") as! MealSummaryViewController
            summaryVC.meal = meal
            self.navigationController?.pushViewController(summaryVC, animated: true)
        }))

        sheet.addAction(UIAlertAction(title: "Modifier", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let composer = storyboard.instantiateViewController(withIdentifier: "AjouterRepasViewController") as! AjouterRepasViewController
            composer.mealToEdit = meal
            composer.onMealSaved = { [weak self] _ in
                self?.fetchHistory()
            }
            self.navigationController?.pushViewController(composer, animated: true)
        }))

        sheet.addAction(UIAlertAction(title: "Annuler", style: .cancel))

        if let popover = sheet.popoverPresentationController,
           let cell = tableView.cellForRow(at: indexPath) {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }

        present(sheet, animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let meal = meals[indexPath.row]

        let deleteAction = UIContextualAction(style: .destructive, title: "Supprimer") { [weak self] _, _, completion in
            guard let self else {
                completion(false)
                return
            }

            Task {
                do {
                    try await self.api.deleteMeal(mealID: meal.id)

                    await MainActor.run {
                        self.meals.remove(at: indexPath.row)
                        completion(true)
                    }
                } catch {
                    await MainActor.run {
                        completion(false)
                        self.showSimpleAlert(
                            title: "Suppression impossible",
                            message: error.localizedDescription
                        )
                    }
                }
            }
        }

        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}
