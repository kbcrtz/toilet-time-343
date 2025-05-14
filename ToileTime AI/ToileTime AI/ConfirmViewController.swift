import UIKit
import ManagedSettings
import FamilyControls
import DeviceActivity

class ConfirmViewController: UIViewController {
    private var isAuthorized = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //check if screen time permissions are authorized
        checkAuthorization()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    //check if authorized
    private func checkAuthorization() {
        let authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        isAuthorized = (authorizationStatus == .approved)
        print("Authorization status: \(isAuthorized ? "Authorized" : "Not authorized")")
    }
    
    @IBAction func timerButtonTapped(_ sender: UIButton) {
        print("Timer button tapped with tag: \(sender.tag)")
        
        if !isAuthorized {
            print("Not authorized, requesting authorization...")
            requestAuthorization { [weak self] success in
                if success {
                    print("Authorization successful")
                    self?.isAuthorized = true
                    self?.proceedToTimer(minutes: sender.tag)
                } else {
                    print("Authorization failed")
                    self?.showAuthorizationError()
                }
            }
        } else {
            print("Already authorized, proceeding to timer")
            proceedToTimer(minutes: sender.tag)
        }
    }
    
    private func requestAuthorization(completion: @escaping (Bool) -> Void) {
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                DispatchQueue.main.async {
                    completion(true)
                }
            } catch {
                print("Authorization failed: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    //navigate to timer screen with desired time
    private func proceedToTimer(minutes: Int) {
        print("Proceeding to timer with \(minutes) minutes")
        
        let tokens = TokenStorage.load()
        if tokens.apps.isEmpty && tokens.categories.isEmpty {
            print("No apps or categories selected")
            showNoAppsSelectedError()
            return
        }
        
        print("Found \(tokens.apps.count) apps and \(tokens.categories.count) categories")
        
        guard let timerVC = storyboard?
            .instantiateViewController(withIdentifier: "TimerVC")
            as? TimerViewController else {
                print("Failed to instantiate TimerVC")
                return
        }
        
        //set the minutes in the next screen
        timerVC.minutes = minutes
        
        //navigate to the screen
        timerVC.modalPresentationStyle = .fullScreen
        present(timerVC, animated: true)
    }
    
    //show error if no access to screen time
    private func showAuthorizationError() {
        let alert = UIAlertController(
            title: "Authorization Required",
            message: "Screen Time authorization is required to control app access. Please enable it in Settings.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    //if no apps selected, alert user !!!
    private func showNoAppsSelectedError() {
        let alert = UIAlertController(
            title: "No Apps Selected",
            message: "Please select apps to control before starting a timer.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Go Back", style: .default) { [weak self] _ in
            self?.navigationController?.popToRootViewController(animated: true)
        })
        present(alert, animated: true)
    }
}
