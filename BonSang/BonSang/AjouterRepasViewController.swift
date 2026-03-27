import UIKit

final class AjouterRepasViewController: UIViewController {

    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var searchButton: UIButton!

    @IBOutlet weak var resultsTableView: UITableView!
    @IBOutlet weak var selectedFoodsTableView: UITableView!

    @IBOutlet weak var emptyStateLabel: UILabel!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var saveMealButton: UIButton!

    var mealToEdit: MealHistoryItem?
    var onMealSaved: ((MealHistoryItem) -> Void)?

    private let api = NutritionAPIService.shared

    private var searchResults: [FoodSearchResult] = [] {
        didSet { resultsTableView.reloadData() }
    }

    private var selectedFoods: [MealFoodDraft] = [] {
        didSet {
            selectedFoodsTableView.reloadData()
            emptyStateLabel.isHidden = !selectedFoods.isEmpty
            saveMealButton.isEnabled = !selectedFoods.isEmpty
            saveMealButton.alpha = selectedFoods.isEmpty ? 0.55 : 1
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = mealToEdit == nil ? "Ajouter un repas" : "Modifier le repas"
        view.backgroundColor = .systemBackground

        resultsTableView.dataSource = self
        resultsTableView.delegate = self
        selectedFoodsTableView.dataSource = self
        selectedFoodsTableView.delegate = self

        resultsTableView.rowHeight = UITableView.automaticDimension
        resultsTableView.estimatedRowHeight = 72
        selectedFoodsTableView.rowHeight = UITableView.automaticDimension
        selectedFoodsTableView.estimatedRowHeight = 72

        resultsTableView.isScrollEnabled = false
        selectedFoodsTableView.isScrollEnabled = false

        resultsTableView.tableFooterView = UIView()
        selectedFoodsTableView.tableFooterView = UIView()

        searchTextField.delegate = self

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        emptyStateLabel.text = "Aucun plat ajouté pour le moment."
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.textColor = .secondaryLabel

        datePicker.datePickerMode = .dateAndTime
        datePicker.locale = Locale(identifier: "fr_FR")

        saveMealButton.setTitle(mealToEdit == nil ? "Analyser et enregistrer" : "Enregistrer les modifications", for: .normal)
        saveMealButton.isEnabled = false
        saveMealButton.alpha = 0.55

        populateIfEditing()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func populateIfEditing() {
        guard let mealToEdit else {
            datePicker.date = Date()
            return
        }

        selectedFoods = mealToEdit.items.compactMap {
            guard let fdcId = $0.fdcId,
                  let description = $0.description,
                  let grams = $0.grams else { return nil }
            return MealFoodDraft(fdcId: fdcId, description: description, grams: grams)
        }

        datePicker.date = ISO8601DateFormatter().date(from: mealToEdit.mealTakenAt) ?? Date()
    }

    @IBAction func searchTapped(_ sender: UIButton) {
        view.endEditing(true)

        guard let text = searchTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            showSimpleAlert(title: "Recherche vide", message: "Entre le nom d’un plat avant de lancer la recherche.")
            return
        }

        Task { @MainActor in
            let loading = presentLoadingAlert()

            do {
                let response = try await api.searchFoods(query: text)

                loading.dismiss(animated: true) { [weak self] in
                    guard let self else { return }
                    self.searchResults = response.results
                }

            } catch {
                loading.dismiss(animated: true) { [weak self] in
                    self?.showSimpleAlert(title: "Recherche impossible", message: error.localizedDescription)
                }
            }
        }
    }

    @IBAction func saveMealTapped(_ sender: UIButton) {
        view.endEditing(true)

        guard !selectedFoods.isEmpty else {
            showSimpleAlert(title: "Repas incomplet", message: "Ajoute au moins un plat avant de valider.")
            return
        }

        Task { @MainActor in
            let loading = presentLoadingAlert(title: mealToEdit == nil ? "Analyse du repas..." : "Mise à jour du repas...")

            do {
                let savedMeal: MealHistoryItem
                if let mealToEdit {
                    savedMeal = try await api.updateMeal(mealID: mealToEdit.id, foods: selectedFoods, mealTakenAt: datePicker.date)
                } else {
                    savedMeal = try await api.analyzeMeal(foods: selectedFoods, mealTakenAt: datePicker.date)
                }

                loading.dismiss(animated: true) { [weak self] in
                    guard let self else { return }
                    self.onMealSaved?(savedMeal)

                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    let summaryVC = storyboard.instantiateViewController(withIdentifier: "MealSummaryViewController") as! MealSummaryViewController
                    summaryVC.meal = savedMeal
                    self.navigationController?.pushViewController(summaryVC, animated: true)
                }

            } catch {
                loading.dismiss(animated: true) { [weak self] in
                    self?.showSimpleAlert(title: "Enregistrement impossible", message: error.localizedDescription)
                }
            }
        }
    }

    private func addFoodToMeal(_ result: FoodSearchResult) {
        let alert = UIAlertController(title: result.description, message: "Entre le grammage du plat sélectionné.", preferredStyle: .alert)
        alert.addTextField {
            $0.placeholder = "Grammage en g"
            $0.keyboardType = .decimalPad
        }

        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel))
        alert.addAction(UIAlertAction(title: "Ajouter", style: .default, handler: { [weak self, weak alert] _ in
            guard let self,
                  let rawValue = alert?.textFields?.first?.text?.replacingOccurrences(of: ",", with: "."),
                  let grams = Double(rawValue),
                  grams > 0 else {
                self?.showSimpleAlert(title: "Grammage invalide", message: "Entre une valeur positive, par exemple 120.")
                return
            }

            if let existingIndex = self.selectedFoods.firstIndex(where: { $0.fdcId == result.fdcId }) {
                self.selectedFoods[existingIndex].grams = grams
            } else {
                self.selectedFoods.append(MealFoodDraft(fdcId: result.fdcId, description: result.description, grams: grams))
            }
        }))

        present(alert, animated: true)
    }

    private func editFood(at index: Int) {
        let draft = selectedFoods[index]
        let alert = UIAlertController(title: draft.description, message: "Modifie le grammage.", preferredStyle: .alert)
        alert.addTextField {
            $0.text = String(format: "%.0f", draft.grams)
            $0.keyboardType = .decimalPad
        }

        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel))
        alert.addAction(UIAlertAction(title: "Mettre à jour", style: .default, handler: { [weak self, weak alert] _ in
            guard let self,
                  let rawValue = alert?.textFields?.first?.text?.replacingOccurrences(of: ",", with: "."),
                  let grams = Double(rawValue),
                  grams > 0 else {
                self?.showSimpleAlert(title: "Grammage invalide", message: "Entre une valeur positive.")
                return
            }
            self.selectedFoods[index].grams = grams
        }))

        present(alert, animated: true)
    }
}

extension AjouterRepasViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == resultsTableView {
            return max(searchResults.count, 1)
        }
        return max(selectedFoods.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == resultsTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "resultCell", for: indexPath)
            var config = cell.defaultContentConfiguration()

            if searchResults.isEmpty {
                config.text = "Aucun résultat pour le moment"
                config.secondaryText = "Lance une recherche pour afficher les correspondances."
                cell.selectionStyle = .none
                cell.accessoryType = .none
            } else {
                let result = searchResults[indexPath.row]
                config.text = result.description.capitalizedSentence
                config.secondaryText = [result.dataType, result.brandName].compactMap { $0 }.joined(separator: " • ")
                cell.selectionStyle = .default
                cell.accessoryType = .disclosureIndicator
            }

            config.textProperties.numberOfLines = 0
            config.secondaryTextProperties.numberOfLines = 0
            cell.contentConfiguration = config
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "selectedCell", for: indexPath)
        var config = cell.defaultContentConfiguration()

        if selectedFoods.isEmpty {
            config.text = "Ton repas est vide"
            config.secondaryText = "Ajoute au moins un plat depuis la recherche ci-dessus."
            cell.selectionStyle = .none
            cell.accessoryType = .none
        } else {
            let item = selectedFoods[indexPath.row]
            config.text = item.description.capitalizedSentence
            config.secondaryText = "\(item.grams.gramsText) • toucher pour modifier"
            cell.selectionStyle = .default
            cell.accessoryType = .none
        }

        config.textProperties.numberOfLines = 0
        config.secondaryTextProperties.numberOfLines = 0
        cell.contentConfiguration = config
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        view.endEditing(true)
        tableView.deselectRow(at: indexPath, animated: true)

        if tableView == resultsTableView {
            guard !searchResults.isEmpty else { return }
            addFoodToMeal(searchResults[indexPath.row])
        } else {
            guard !selectedFoods.isEmpty else { return }
            editFood(at: indexPath.row)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard tableView == selectedFoodsTableView, !selectedFoods.isEmpty else { return nil }

        let deleteAction = UIContextualAction(style: .destructive, title: "Supprimer") { [weak self] _, _, completion in
            self?.selectedFoods.remove(at: indexPath.row)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

extension AjouterRepasViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        searchTapped(searchButton)
        return true
    }
}
