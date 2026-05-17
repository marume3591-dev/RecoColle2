import Foundation
import StoreKit

@MainActor
final class PremiumManager {

    static let shared = PremiumManager()
    private init() {}

    private(set) var isPremium: Bool = false

    // 現在の状態を返す（UIKit用）
    func isPremiumUser() -> Bool {
        return isPremium
    }

    // 購入成功時に呼ぶ
    func setPremium(_ value: Bool) {
        isPremium = value
        UserDefaults.standard.set(value, forKey: "NoAds")
        print("Premium set → \(value)")
    }

    // App Store と同期（起動時・復元時）
    func refresh() async {
        print("Refresh start")

        let result = await Transaction.currentEntitlement(for: "NoAds")
        print("Refresh end")

        if case .verified = result {
            isPremium = true
            UserDefaults.standard.set(true, forKey: "NoAds")
            print("Refresh → Premium TRUE")
        } else {
            isPremium = false
            UserDefaults.standard.set(false, forKey: "NoAds")
            print("Refresh → Premium FALSE")
        }
    }

    // UserDefaults から仮状態を読み込む（即時反映用）
    func loadFromDefaults() {
        isPremium = UserDefaults.standard.bool(forKey: "NoAds")
        print("LoadFromDefaults → \(isPremium)")
    }
    
}

extension Notification.Name {
    static let premiumStatusChanged = Notification.Name("premiumStatusChanged")
}
