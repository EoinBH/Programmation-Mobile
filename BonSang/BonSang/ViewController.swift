//
//  ViewController.swift
//  BonSang
//
//  Created by Eoin Brereton Hurley on 01/03/2026.
//

import UIKit
import SafariServices

enum GlucoseUnit {
    case mmolL
    case mgdL
}

class ViewController: UIViewController, SFSafariViewControllerDelegate {
    
    // MARK: - OUTLETS
    
    @IBOutlet weak var loginButton: UIButton!
    
    @IBOutlet weak var mmolLabel: UILabel!
    
    @IBOutlet weak var mgdlLabel: UILabel!
    
    @IBOutlet weak var timeRangeSegmentedControl: UISegmentedControl!
    
    @IBOutlet weak var unitSegmentedControl: UISegmentedControl!
    
    
    @IBOutlet weak var graphView: GraphView!
    
    @IBAction func repasButtonTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MealHistoryViewController") as! MealHistoryViewController
        navigationController?.pushViewController(vc, animated: true)
    }
    
    // MARK: - DATA
    var glucoseRecords: [GlucoseRecord] = []
    var glucoseTimer: Timer?
    var safariVC: SFSafariViewController?

    var selectedHours: Int = 3
    var selectedUnit: GlucoseUnit = .mmolL

    struct AuthStatus: Decodable {
        let authenticated: Bool
    }
    
    // MARK: - LIFECYCLE
    
    override func viewDidLoad() {
        super.viewDidLoad()
            
        configureSegmentedControls()
            
        graphView.selectedHours = selectedHours
        graphView.selectedUnit = selectedUnit
            
        checkAuthStatus()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        glucoseTimer?.invalidate()
        glucoseTimer = nil
    }
    
    // MARK: - AUTH
    
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
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {

        print("Login window closed")
        
        loginButton.isHidden = true
        
        fetchGlucose()
    }
    
    // MARK: - SEGMENTED CONTROLS
    
    func configureSegmentedControls() {
        timeRangeSegmentedControl.removeAllSegments()
        ["3h","6h","12h","24h"].enumerated().forEach {
            timeRangeSegmentedControl.insertSegment(withTitle: $0.element, at: $0.offset, animated: false)
        }
        timeRangeSegmentedControl.selectedSegmentIndex = 0
            
        unitSegmentedControl.removeAllSegments()
        ["mmol/L","mg/dL"].enumerated().forEach {
            unitSegmentedControl.insertSegment(withTitle: $0.element, at: $0.offset, animated: false)
        }
        unitSegmentedControl.selectedSegmentIndex = 0
    }
    
    @IBAction func timeRangeChanged(_ sender: UISegmentedControl) {
        selectedHours = [3,6,12,24][sender.selectedSegmentIndex]
        graphView.selectedHours = selectedHours
        fetchGlucose()
    }
    
    @IBAction func unitChanged(_ sender: UISegmentedControl) {
        selectedUnit = sender.selectedSegmentIndex == 0 ? .mmolL : .mgdL
        graphView.selectedUnit = selectedUnit
                
        updateLabels()
        drawGraph()
    }
    
    
    // MARK: - TIMER

    func startGlucoseUpdates() {

        if glucoseTimer != nil {
            return
        }

        glucoseTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            print("Checking for new glucose data...")
            self.fetchGlucose()
        }
    }

    // MARK: - FETCH

    func fetchGlucose() {

        let urlString = "https://india-unfightable-overbearingly.ngrok-free.dev/dexcom/egvs?hours=\(selectedHours)"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
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
                    self.updateLabels()
                    self.startGlucoseUpdates()
                }

            } catch {
                print("Decode error:", error)
            }

        }.resume()
    }

    // MARK: - GRAPH
        
    func drawGraph() {
        let sorted = glucoseRecords.sorted { $0.systemTime < $1.systemTime }
        graphView.glucoseRecords = sorted
    }

    // MARK: - LABELS
        
    func updateLabels() {
        guard let last = glucoseRecords.sorted(by: { $0.systemTime < $1.systemTime }).last else {
            mmolLabel.text = "--"
            mgdlLabel.text = "--"
            return
        }

        let mgdl = last.value
        let mmol = mgdl / 18.0

        mmolLabel.text = String(format: "%.1f mmol/L", mmol)
        mgdlLabel.text = String(format: "%.0f mg/dL", mgdl)
        
        mmolLabel.isHidden = selectedUnit == .mgdL
        mgdlLabel.isHidden = selectedUnit == .mmolL
    }
    
}


