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
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {

        print("Login window closed")
        
        loginButton.isHidden = true
        
        fetchGlucose()
    }
    
}


