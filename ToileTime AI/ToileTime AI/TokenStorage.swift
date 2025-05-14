import ManagedSettings
import FamilyControls
import Foundation

struct TokenStorage: Codable {
    let apps: [ApplicationToken]
    let categories: [ActivityCategoryToken]
    private static let key = "ScreenTimeTokenStorage"
    private static let appGroupIdentifier = "group.com.kobemax.ToileTimeAI"
    
    //saves app tokens to userDefaults
    static func save(apps: Set<ApplicationToken>,
                     categories: Set<ActivityCategoryToken>) {
        let object = TokenStorage(apps: Array(apps),
                                  categories: Array(categories))
        if let data = try? JSONEncoder().encode(object) {
            let userDefaults = UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
            userDefaults.set(data, forKey: key)
            userDefaults.set(true, forKey: "hasPickedApps")
        }
    }
    //loads app tokens from userDefaults
    static func load() -> (apps: Set<ApplicationToken>,
                           categories: Set<ActivityCategoryToken>) {
        let userDefaults = UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
        
        guard
            let data = userDefaults.data(forKey: key),
            let object = try? JSONDecoder().decode(TokenStorage.self, from: data)
        else { return ([], []) }

        return (Set(object.apps), Set(object.categories))
    }
}
