import UIKit
import ManagedSettings
import FamilyControls
import DeviceActivity
import UserNotifications

class TimerViewController: UIViewController {
    
    @IBOutlet weak var countdownLabel: UILabel!

    var minutes: Int = 0
    private var secondsLeft: Int = 0
    private var timer: Timer?
    
    private let store = ManagedSettingsStore()
    private let saved = TokenStorage.load()
    private let deviceActivityCenter = DeviceActivityCenter()
    
    private let notificationID = "unlockTimer"

    override func viewDidLoad() {
        super.viewDidLoad()
        secondsLeft = minutes * 60
        startUnlockSession()
        startCountdown()
        scheduleLocalNotification()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID])
    }

    private func startUnlockSession() {
        let unlockActivity = DeviceActivityName("unlock")
        let now = Date()
        let endDate = now.addingTimeInterval(TimeInterval(minutes * 60))
        
        print("Current time: \(now)")
        print("End time: \(endDate)")
        
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.hour, .minute, .second], from: now)
        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: endDate)
        let schedule = DeviceActivitySchedule(
            intervalStart: nowComponents,
            intervalEnd: endComponents,
            repeats: false,
            warningTime: DateComponents(second: 30)
        )
        
        do {
            print("Stopping existing monitoring")
            deviceActivityCenter.stopMonitoring([unlockActivity])
            Thread.sleep(forTimeInterval: 0.5)
            
            print("Starting new monitoring session")
            try deviceActivityCenter.startMonitoring(
                unlockActivity,
                during: schedule
            )
            
            print("DeviceActivity monitoring started successfully")
            print("Schedule: \(nowComponents) to \(endComponents)")
            
            let userDefaults = UserDefaults(suiteName: "group.com.kobemax.ToileTimeAI") ?? UserDefaults.standard
            userDefaults.set(endDate, forKey: "unlockEndTime_\(unlockActivity.rawValue)")
            userDefaults.synchronize()
            
            unlockAllApps()
        } catch {
            print("Failed to schedule device activity: \(error)")
            print("Error details: \(error.localizedDescription)")
            startManualTimer()
        }
    }
    private func startManualTimer() {
        print("Using manual timer as fallback")
        unlockAllApps()
        Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
            self?.relockAllApps()
            self?.navigateToHome()
        }
    }
    
    private func unlockAllApps() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }

    private func relockAllApps() {
        if !saved.apps.isEmpty {
            store.shield.applications = saved.apps
        }
        if !saved.categories.isEmpty {
            store.shield.applicationCategories = .specific(saved.categories)
        }
    }
    private func startCountdown() {
        updateLabel()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.secondsLeft -= 1
            self.updateLabel()
            if self.secondsLeft <= 0 {
                self.timer?.invalidate()
                self.navigateToHome()
            }
        }
    }

    private func updateLabel() {
        let m = secondsLeft / 60
        let s = secondsLeft % 60
        countdownLabel.text = String(format: "%02d:%02d", m, s)
    }
    
    private func navigateToHome() {
        let sb = UIStoryboard(name: "Home", bundle: nil)
        let home = sb.instantiateViewController(withIdentifier: "HomeVC")

        home.modalPresentationStyle = .fullScreen
        home.isModalInPresentation = false
        present(home, animated: true)    }
    
    private func scheduleLocalNotification() {
        let center = UNUserNotificationCenter.current()
        
        func addRequest() {
            let content      = UNMutableNotificationContent()
            content.title    = "Time's up!"
            content.body     = "Get off the toilet"
            content.sound    = .default
            
            let trigger      = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(secondsLeft),
                repeats: false
            )
            let request      = UNNotificationRequest(
                identifier: notificationID,
                content:    content,
                trigger:    trigger
            )
            center.add(request)
        }
        
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized:
                addRequest()
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted { addRequest() }
                }
            default:
                break
            }
        }
    }
}
