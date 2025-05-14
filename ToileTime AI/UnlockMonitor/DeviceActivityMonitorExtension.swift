import DeviceActivity
import ManagedSettings
import FamilyControls

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let store = ManagedSettingsStore()
    private static let appGroupIdentifier = "group.com.kobemax.ToileTimeAI"
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        print("DeviceActivityMonitor: intervalDidStart for \(activity.rawValue)")
        
        if activity.rawValue == "unlock" {
            print("Unlocking apps via DeviceActivityMonitor")
            unlockAllApps()
        }
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        
        print("DeviceActivityMonitor: intervalDidEnd for \(activity.rawValue)")
        
        if activity.rawValue == "unlock" {
            print("Relocking apps via DeviceActivityMonitor")
            relockAllApps()
        }
    }
    
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        
        print("DeviceActivityMonitor: intervalWillEndWarning for \(activity.rawValue)")
        
        if activity.rawValue == "unlock" {
            print("Warning: Timer about to expire")
        }
    }
    
    private func unlockAllApps() {
        print("Executing unlockAllApps")
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        print("Apps unlocked successfully")
    }
    
    private func relockAllApps() {
        print("Executing relockAllApps")
        let saved = TokenStorage.load()
        
        print("Loaded tokens: \(saved.apps.count) apps, \(saved.categories.count) categories")
        
        if !saved.apps.isEmpty {
            store.shield.applications = saved.apps
            print("Relocked \(saved.apps.count) apps")
        }
        if !saved.categories.isEmpty {
            store.shield.applicationCategories = .specific(saved.categories)
            print("Relocked \(saved.categories.count) categories")
        }
    }
}

extension ManagedSettingsStore.Name {
    static let unlock = Self("unlock")
}

import ManagedSettings
import FamilyControls
import Foundation

struct TokenStorage: Codable {
    let apps: [ApplicationToken]
    let categories: [ActivityCategoryToken]
    
    private static let key = "ScreenTimeTokenStorage"
    private static let appGroupIdentifier = "group.com.kobemax.ToileTimeAI"
    
    static func save(apps: Set<ApplicationToken>,
                    categories: Set<ActivityCategoryToken>) {
        let object = TokenStorage(apps: Array(apps),
                                categories: Array(categories))
        if let data = try? JSONEncoder().encode(object) {
            let userDefaults = UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
            userDefaults.set(data, forKey: key)
            userDefaults.set(true, forKey: "hasPickedApps")
            userDefaults.synchronize()
        }
    }
    
    static func load() -> (apps: Set<ApplicationToken>,
                          categories: Set<ActivityCategoryToken>) {
        let userDefaults = UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
        
        guard
            let data = userDefaults.data(forKey: key),
            let object = try? JSONDecoder().decode(TokenStorage.self, from: data)
        else {
            print("Failed to load tokens from UserDefaults")
            return ([], [])
        }
        
        print("Successfully loaded tokens: \(object.apps.count) apps, \(object.categories.count) categories")
        return (Set(object.apps), Set(object.categories))
    }
}
