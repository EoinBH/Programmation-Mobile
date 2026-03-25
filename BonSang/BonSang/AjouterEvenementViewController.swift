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
    enum EventType {
        case meal(MealData)
        case activity(ActivityData)
    }

    struct MealData {
        let image: UIImage
        let carbs: Int
        let proteins: Int
        let calories: Int
    }

    struct ActivityData {
        let iconName: String
        let duration: Int
        let intensity: String
    }

    struct Event {
        let type: EventType
        let date: Date
        let note: String
    }

    var events: [Event] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = self
        tableView.delegate = self
    }

    // MARK: - TableView
    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        return events.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "repasCell",
                                                     for: indexPath) as! MealCell
        let event = events[indexPath.row]

        let dateText = DateFormatter.localizedString(
            from: event.date,
            dateStyle: .short,
            timeStyle: .short
        )

        cell.dateLabel.text = dateText
        cell.titleLabel.text = event.note.isEmpty ? "Événement" : event.note

        switch event.type {

        case .meal(let meal):

            cell.mealImageView.image = meal.image
            cell.mealImageView.tintColor = nil
            cell.mealImageView.contentMode = .scaleAspectFill

            cell.nutritionLabel.text =
            "\(meal.carbs)g gluc • \(meal.proteins)g prot • \(meal.calories) kcal"

        case .activity(let activity):

            cell.mealImageView.image = UIImage(systemName: activity.iconName)
            cell.mealImageView.tintColor = .systemBlue
            cell.mealImageView.contentMode = .scaleAspectFit

            cell.nutritionLabel.text =
            "\(activity.duration) min • Intensité: \(activity.intensity)"
        }
        return cell
    }

    // MARK: - Button Action
    @IBAction func ajouterEvenementTouche(_ sender: UIButton) {

        let alert = UIAlertController(title: "Ajouter",
                                          message: "Choisissez un type",
                                          preferredStyle: .actionSheet)

            alert.addAction(UIAlertAction(title: "Repas", style: .default) { _ in
                self.addMealFlow()
            })

            alert.addAction(UIAlertAction(title: "Activité", style: .default) { _ in
                self.presentActivityForm()
            })

            alert.addAction(UIAlertAction(title: "Annuler", style: .cancel))

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

            let newEvent = Event(
                type: .meal(MealData(
                    image: image,
                    carbs: carbs,
                    proteins: proteins,
                    calories: calories
                )),
                date: Date(),
                note: note
            )

            self.events.append(newEvent)
            self.tableView.reloadData()
        })

        self.present(alert, animated: true)
    }
    
    func presentActivityForm() {

        let alert = UIAlertController(title: "Activité",
                                      message: "Détails",
                                      preferredStyle: .alert)

        alert.addTextField { $0.placeholder = "Type (course, vélo...)" }
        alert.addTextField { $0.placeholder = "Durée (minutes)" }
        alert.addTextField { $0.placeholder = "Intensité" }
        alert.addTextField { $0.placeholder = "Description" }

        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel))

        alert.addAction(UIAlertAction(title: "Ajouter", style: .default) { _ in

            let type = alert.textFields?[0].text ?? ""
            let duration = Int(alert.textFields?[1].text ?? "") ?? 0
            let intensity = alert.textFields?[2].text ?? ""
            let note = alert.textFields?[3].text ?? ""

            let newEvent = Event(
                type: .activity(ActivityData(
                    iconName: self.iconForActivity(type),
                    duration: duration,
                    intensity: intensity
                )),
                date: Date(),
                note: note
            )

            self.events.append(newEvent)
            self.tableView.reloadData()
        })

        present(alert, animated: true)
    }
    
    func addMealFlow() {

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
    
    func iconForActivity(_ type: String) -> String {
        switch type.lowercased() {
        case "course": return "figure.run"
        case "vélo": return "bicycle"
        case "natation": return "figure.pool.swim"
        case "marche": return "figure.walk"
        default: return "flame"
        }
    }
}
