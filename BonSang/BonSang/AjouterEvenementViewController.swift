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
    struct MealData: Codable {
        let imageData: Data
        let carbs: Int
        let proteins: Int
        let calories: Int
    }

    struct ActivityData: Codable {
        let iconName: String
        let duration: Int
        let intensity: String
    }

    enum EventType: Codable {
        case meal(MealData)
        case activity(ActivityData)

        private enum CodingKeys: String, CodingKey {
            case type, meal, activity
        }

        private enum EventKind: String, Codable {
            case meal, activity
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .meal(let meal):
                try container.encode(EventKind.meal, forKey: .type)
                try container.encode(meal, forKey: .meal)
            case .activity(let activity):
                try container.encode(EventKind.activity, forKey: .type)
                try container.encode(activity, forKey: .activity)
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(EventKind.self, forKey: .type)

            switch type {
            case .meal:
                let meal = try container.decode(MealData.self, forKey: .meal)
                self = .meal(meal)
            case .activity:
                let activity = try container.decode(ActivityData.self, forKey: .activity)
                self = .activity(activity)
            }
        }
    }

    struct Event: Codable {
        let type: EventType
        let date: Date
        let note: String
    }

    var events: [Event] = []

    // MARK: - Save
    func saveEvents() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(events) {
            UserDefaults.standard.set(data, forKey: "events")
        }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = self
        tableView.delegate = self
        
        loadEvents()
    }

    func loadEvents() {
        if let data = UserDefaults.standard.data(forKey: "events") {
            let decoder = JSONDecoder()
            if let savedEvents = try? decoder.decode([Event].self, from: data) {
                self.events = savedEvents
            }
        }
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

            cell.mealImageView.image = UIImage(data: meal.imageData)
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

            if let imageData = image.jpegData(compressionQuality: 0.8) {
                let newEvent = Event(
                    type: .meal(MealData(
                        imageData: imageData,
                        carbs: carbs,
                        proteins: proteins,
                        calories: calories
                    )),
                    date: Date(),
                    note: note
                )

                self.events.append(newEvent)
                self.saveEvents()
                self.tableView.reloadData()
            }
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
            self.saveEvents()
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
    
    // MARK: - Icons
    func iconForActivity(_ type: String) -> String {
        switch type.lowercased() {
        case "course": return "figure.run"
        case "vélo": return "bicycle"
        case "natation": return "figure.pool.swim"
        case "marche": return "figure.walk"
        default: return "flame"
        }
    }
    
    // MARK: - Swipe Actions

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {

        let deleteAction = UIContextualAction(style: .destructive, title: "Supprimer") { _, _, completion in
            
            let alert = UIAlertController(
                title: "Supprimer",
                message: "Voulez-vous supprimer cet événement ?",
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { _ in
                completion(false)
            })

            alert.addAction(UIAlertAction(title: "Supprimer", style: .destructive) { _ in
                
                self.events.remove(at: indexPath.row)
                self.saveEvents()
                tableView.deleteRows(at: [indexPath], with: .automatic)
                
                completion(true)
            })

            self.present(alert, animated: true)
        }

        let config = UISwipeActionsConfiguration(actions: [deleteAction])
        config.performsFirstActionWithFullSwipe = false // important !

        return config
    }
}
