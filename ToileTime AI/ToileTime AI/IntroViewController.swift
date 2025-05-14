import UIKit
import SwiftUI
import FamilyControls
import DeviceActivity
import ManagedSettings
import Combine

@available(iOS 16.0, *)
class IntroViewController: UIViewController {

    private var activitySelection = FamilyActivitySelection()
    private var pickerHost: UIHostingController<FamilyActivityPicker>?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        //if user has already picked apps, go to homescreen
        if UserDefaults.standard.bool(forKey: "hasPickedApps") {
            DispatchQueue.main.async { [weak self] in
                self?.navigateToHome()
            }
        }
    }
    //requests screen time authorization
    @IBAction func requestScreenTimeAuthorization(_ sender: UIButton) {
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                DispatchQueue.main.async { [weak self] in
                    self?.presentFamilyActivityPicker()
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.showAlert(title: "Failed",
                              message: "Screen‑Time access denied. Enable it in Settings.")
                }
            }
        }
    }
    //shows pop up screen for restricted apps
    private func presentFamilyActivityPicker() {
        let binding = Binding<FamilyActivitySelection>(
            get: { self.activitySelection },
            set: { self.activitySelection = $0 }
        )
        let pickerView = FamilyActivityPicker(selection: binding)

        let done = UIButton(type: .system)
        done.setTitle("Done", for: .normal)
        done.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        done.setTitleColor(.systemBlue, for: .normal)
        done.layer.cornerRadius = 8
        done.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        done.addTarget(self,
                       action: #selector(dismissAndNavigate),
                       for: .touchUpInside)

        pickerHost = UIHostingController(rootView: pickerView)
        if let host = pickerHost {
            host.view.addSubview(done)
            done.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                done.topAnchor.constraint(equalTo: host.view.safeAreaLayoutGuide.topAnchor, constant: 16),
                done.trailingAnchor.constraint(equalTo: host.view.trailingAnchor, constant: -16)
            ])
            
            present(host, animated: true)
        }
    }

    // Go to home screen after picking apps
    @objc private func dismissAndNavigate() {
        pickerHost?.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            if self.persistSelection() {
                self.navigateToHome()
            }
        }
    }
    
    //save apps to local storage and also lock them
    private func persistSelection() -> Bool {
        let store = ManagedSettingsStore()

        let apps = activitySelection.applicationTokens
        let categories = activitySelection.categoryTokens

        guard !apps.isEmpty || !categories.isEmpty else {
            showAlert(title: "Nothing Selected",
                     message: "Pick at least one app or category.")
            return false
        }

        TokenStorage.save(apps: apps, categories: categories)
        if !apps.isEmpty {
            store.shield.applications = apps
        }
        if !categories.isEmpty {
            store.shield.applicationCategories = .specific(categories)
        }
        
        UserDefaults.standard.set(true, forKey: "hasPickedApps")
        
        print("Saved apps:", apps, "\n Saved categories:", categories)
        return true
    }

    // go to homescreen
    private func navigateToHome() {
        DispatchQueue.main.async { [weak self] in
            let homeSB = UIStoryboard(name: "Home", bundle: nil)
            if let homeVC = homeSB.instantiateViewController(withIdentifier: "HomeVC") as? UIViewController {
                
                if let nav = self?.navigationController {
                    nav.setViewControllers([homeVC], animated: true)
                } else {
                    homeVC.modalPresentationStyle = .fullScreen
                    self?.present(homeVC, animated: true)
                }
            }
        }
    }
    
    //helper method to show alert
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
