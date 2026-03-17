//
//  ViewController.swift
//  BonSang
//
//  Created by Eoin Brereton Hurley on 01/03/2026.
//

import UIKit
import SafariServices

class ViewController: UIViewController, SFSafariViewControllerDelegate {

    @IBOutlet weak var loginButton: UIButton!
    
    var glucoseRecords: [GlucoseRecord] = []
    
    var glucoseTimer: Timer?
    
    var safariVC: SFSafariViewController?

    struct AuthStatus: Decodable {
        let authenticated: Bool
    }
    
    func checkAuthStatus() {

        let urlString = "https://india-unfightable-overbearingly.ngrok-free.dev/auth/status"

        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in

            if let error = error {
                print("Auth check failed:", error)
                return
            }

            guard let data = data else { return }

            do {

                let status = try JSONDecoder().decode(AuthStatus.self, from: data)

                DispatchQueue.main.async {

                    if status.authenticated {
                        print("User already logged in")

                        self.loginButton.isHidden = true
                        self.fetchGlucose()

                    } else {

                        print("User not authenticated")

                        self.loginButton.isHidden = false
                    }

                }

            } catch {
                print("Decode error:", error)
            }

        }.resume()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        checkAuthStatus()
        //fetchGlucose()
    }
    
    @IBAction func loginButtonTapped(_ sender: UIButton) {
        loginWithDexcom()
    }
    
    func loginWithDexcom() {

        let urlString = "https://india-unfightable-overbearingly.ngrok-free.dev/auth/dexcom"

        guard let url = URL(string: urlString) else { return }

        safariVC = SFSafariViewController(url: url)
        safariVC?.delegate = self

        if let safariVC = safariVC {
            present(safariVC, animated: true)
        }
    }
    
    func startGlucoseUpdates() {

        if glucoseTimer != nil {
            return
        }

        glucoseTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            print("Checking for new glucose data...")
            self.fetchGlucose()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        glucoseTimer?.invalidate()
        glucoseTimer = nil
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
                    /*if decoded.records.count != self.glucoseRecords.count {
                        print("New glucose value detected")
                        self.glucoseRecords = decoded.records
                        self.drawGraph()
                    }*/
                    self.glucoseRecords = decoded.records
                    print("Fetched \(self.glucoseRecords.count) glucose values")

                    self.drawGraph()
                    self.startGlucoseUpdates()
                }

            } catch {
                print("Decode error:", error)
            }

        }.resume()
    }

    @IBOutlet weak var mmolLabel: UILabel!
    
    @IBOutlet weak var mgdlLabel: UILabel!
    
    func addPoint(at point: CGPoint) {
        let radius: CGFloat = 4

        let circlePath = UIBezierPath(
            arcCenter: point,
            radius: radius,
            startAngle: 0,
            endAngle: CGFloat.pi * 2,
            clockwise: true
        )

        let circleLayer = CAShapeLayer()
        circleLayer.path = circlePath.cgPath
        
        // Style du point
        circleLayer.fillColor = UIColor.black.cgColor
        circleLayer.strokeColor = UIColor.black.cgColor
        circleLayer.lineWidth = 2

        circleLayer.name = "graphLayer"

        view.layer.addSublayer(circleLayer)
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
        
        if let latestRecord = sorted.last {
            let mgdlValue = latestRecord.value
            let mmolValue = mgdlValue / 18.0

            mmolLabel.text = String(format: "%.1f mmol/L", mmolValue)
            mgdlLabel.text = String(format: "%.0f mg/dL", mgdlValue)
        }
        
//        let values = sorted.map { $0.value }
//
//        guard let minValue = values.min(),
//              let maxValue = values.max() else { return }
        let values = sorted.map { $0.value }

        // Axe Y fixe : 0 à 22 mmol/L → 0 à 396 mg/dL
        let minValue: Double = 0
        let maxValue: Double = 396

        let path = UIBezierPath()

        let graphHeight: CGFloat = 250
        let graphWidth = view.bounds.width - 40

        let startX: CGFloat = 20
        let bottomY = view.bounds.height - 120

        //let valueRange = maxValue - minValue == 0 ? 1 : maxValue - minValue
        let valueRange = maxValue - minValue

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

            // Ajout du point visuel
            addPoint(at: point)
        }

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = UIColor.black.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 2
        shapeLayer.name = "graphLayer"

        view.layer.addSublayer(shapeLayer)
    }
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {

        print("Login window closed")
        
        loginButton.isHidden = true
        
        fetchGlucose()
    }
    
}


