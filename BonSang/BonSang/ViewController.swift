//
//  ViewController.swift
//  BonSang
//
//  Created by Eoin Brereton Hurley on 01/03/2026.
//

import UIKit

class ViewController: UIViewController {

    var glucoseRecords: [GlucoseRecord] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        fetchGlucose()
    }

    // MARK: - Fetch Glucose Data

    func fetchGlucose() {

        let urlString = "https://india-unfightable-overbearingly.ngrok-free.dev/dexcom/egvs"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in

            if let error = error {
                print("Network error:", error)
                return
            }

            guard let data = data else {
                print("No data received")
                return
            }

            do {
                let decoded = try JSONDecoder().decode(DexcomResponse.self, from: data)

                DispatchQueue.main.async {
                    self.glucoseRecords = decoded.records
                    print("Fetched \(self.glucoseRecords.count) glucose values")

                    self.drawGraph()
                }

            } catch {
                print("Decode error:", error)
            }

        }.resume()
    }

    // MARK: - Draw Graph

    func drawGraph() {

        print("Drawing graph with \(glucoseRecords.count) points")

        // Remove previous graph layers
        view.layer.sublayers?.removeAll(where: { $0.name == "graphLayer" })

        guard glucoseRecords.count > 1 else {
            print("Not enough data to draw graph")
            return
        }

        let sorted = glucoseRecords.sorted {
            $0.systemTime < $1.systemTime
        }

        let values = sorted.map { $0.value }

        guard let minValue = values.min(),
              let maxValue = values.max() else { return }

        let path = UIBezierPath()

        let graphHeight: CGFloat = 250
        let graphWidth = view.bounds.width - 40

        let startX: CGFloat = 20
        let bottomY = view.bounds.height - 120

        let valueRange = maxValue - minValue == 0 ? 1 : maxValue - minValue

        for (index, value) in values.enumerated() {

            let xPosition = startX + CGFloat(index) * (graphWidth / CGFloat(values.count - 1))

            let normalized = (value - minValue) / valueRange
            let yPosition = bottomY - CGFloat(normalized) * graphHeight

            let point = CGPoint(x: xPosition, y: yPosition)

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = UIColor.systemBlue.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 3
        shapeLayer.name = "graphLayer"

        view.layer.addSublayer(shapeLayer)
    }
}


