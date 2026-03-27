import UIKit

extension Double {
    var gramsText: String { String(format: "%.0f g", self) }
    var compactNutritionText: String { String(format: "%.1f", self) }
}

extension Date {
    static let mealDisplayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }()
}

extension String {
    var capitalizedSentence: String {
        prefix(1).uppercased() + dropFirst()
    }
}

enum NutritionPalette {
    static let background = UIColor.systemGroupedBackground
    static let card = UIColor.secondarySystemGroupedBackground
    static let tint = UIColor.systemGreen
    static let warning = UIColor.systemOrange
    static let danger = UIColor.systemRed
}

final class CardView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = NutritionPalette.card
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.withAlphaComponent(0.12).cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 6)
    }
}

extension UIViewController {
    func showSimpleAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func presentLoadingAlert(title: String = "Chargement...") -> UIAlertController {
        let alert = UIAlertController(title: title, message: "\n\n", preferredStyle: .alert)
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()
        alert.view.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            indicator.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20)
        ])
        present(alert, animated: true)
        return alert
    }
}
