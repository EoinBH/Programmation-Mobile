//
//  AjouterEvenementViewController.swift
//  BonSang
//
//  Created by Brereton Hurley Eoin on 18/03/2026.
//

import UIKit

class AddEventViewController: UIViewController,
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

        let cell = tableView.dequeueReusableCell(withIdentifier: "repas",
                                                 for: indexPath)

        let meal = meals[indexPath.row]

        cell.textLabel?.text = DateFormatter.localizedString(
            from: meal.date,
            dateStyle: .short,
            timeStyle: .short
        )

        cell.imageView?.image = meal.image

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

            let newMeal = Meal(image: image, date: Date())
            meals.append(newMeal)

            tableView.reloadData()
        }

        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
