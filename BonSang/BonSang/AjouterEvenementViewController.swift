//
//  AjouterEvenementViewController.swift
//  BonSang
//
//  Created by Brereton Hurley Eoin on 18/03/2026.
//

import UIKit

class AjouterEvenementViewController: UIViewController,
                              UITableViewDataSource,
                              UITableViewDelegate,
                              UIImagePickerControllerDelegate,
                              UINavigationControllerDelegate {

    // MARK: - Outlets
    
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - Model
    struct Meal {
        let image: UIImage
        let date: Date
        let carbs: Int
        let proteins: Int
        let calories: Int
        let note: String
    }

    var meals: [Meal] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = self
        tableView.delegate = self
    }

    // MARK: - TableView
    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        return meals.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "repasCell",
                                                 for: indexPath) as! MealCell

        let meal = meals[indexPath.row]

        let dateText = DateFormatter.localizedString(
            from: meal.date,
            dateStyle: .short,
            timeStyle: .short
        )

        cell.titleLabel.text = meal.note.isEmpty ? "Repas" : meal.note
        cell.dateLabel.text = dateText

        cell.nutritionLabel.text = "\(meal.carbs)g gluc • \(meal.proteins)g prot • \(meal.calories) kcal"

        cell.mealImageView.image = meal.image

        // style image
        cell.mealImageView.layer.cornerRadius = 10
        cell.mealImageView.clipsToBounds = true
        cell.mealImageView.contentMode = .scaleAspectFill

        return cell
    }

    // MARK: - Button Action
    @IBAction func ajouterEvenementTouche(_ sender: UIButton) {

        let alert = UIAlertController(title: "Ajouter une photo",
                                      message: nil,
                                      preferredStyle: .actionSheet)

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: "Caméra",
                                         style: .default) { _ in
                self.openPicker(source: .camera)
            })
        }

        alert.addAction(UIAlertAction(title: "Galerie",
                                     style: .default) { _ in
            self.openPicker(source: .photoLibrary)
        })

        alert.addAction(UIAlertAction(title: "Annuler",
                                     style: .cancel))

        present(alert, animated: true)
    }

    // MARK: - Image Picker
    func openPicker(source: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.sourceType = source
        picker.delegate = self
        present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        if let image = info[.originalImage] as? UIImage {

            picker.dismiss(animated: true) {
                self.presentMealForm(with: image)
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    func presentMealForm(with image: UIImage) {

        let alert = UIAlertController(title: "Infos du repas",
                                      message: "Ajoutez les détails",
                                      preferredStyle: .alert)

        alert.addTextField { $0.placeholder = "Glucides (g)" }
        alert.addTextField { $0.placeholder = "Protéines (g)" }
        alert.addTextField { $0.placeholder = "Calories" }
        alert.addTextField { $0.placeholder = "Description" }

        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel))

        alert.addAction(UIAlertAction(title: "Ajouter", style: .default) { _ in

            let carbs = Int(alert.textFields?[0].text ?? "") ?? 0
            let proteins = Int(alert.textFields?[1].text ?? "") ?? 0
            let calories = Int(alert.textFields?[2].text ?? "") ?? 0
            let note = alert.textFields?[3].text ?? ""

            let newMeal = Meal(
                image: image,
                date: Date(),
                carbs: carbs,
                proteins: proteins,
                calories: calories,
                note: note
            )

            self.meals.append(newMeal)
            self.tableView.reloadData()
        })

        self.present(alert, animated: true)
    }
}
