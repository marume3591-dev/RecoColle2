import UIKit
import StoreKit

class ReviewManager {

    static let shared = ReviewManager()

    private let recordCountKey = "recordCount"
    private let shouldRequestKey = "shouldRequestReview"
    private let lastReviewedVersionKey = "lastReviewedVersion"
    private let snoozedUntilKey = "snoozedUntilDate"

    private init() {}

    func incrementRecordCount() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastVersion = UserDefaults.standard.string(forKey: lastReviewedVersionKey) ?? ""

        let count = UserDefaults.standard.integer(forKey: recordCountKey) + 1
        UserDefaults.standard.set(count, forKey: recordCountKey)

        if count >= 10 && lastVersion != currentVersion {
            UserDefaults.standard.set(true, forKey: shouldRequestKey)
        }
    }
    func resetCountIfVersionChanged() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastVersion = UserDefaults.standard.string(forKey: lastReviewedVersionKey) ?? ""
        if !lastVersion.isEmpty && currentVersion != lastVersion {
            UserDefaults.standard.set(0, forKey: recordCountKey)
        }
    }
    // ⭐️レビュー表示（アラートから呼ぶ）
    func requestReview() {
        DispatchQueue.main.async {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                AppStore.requestReview(in: scene)
            }
        }
    }

    // フラグ取得（ViewController用）
    func shouldShowReviewAlert() -> Bool {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastVersion = UserDefaults.standard.string(forKey: lastReviewedVersionKey) ?? ""
        let shouldRequest = UserDefaults.standard.bool(forKey: shouldRequestKey)
        if let snoozedUntil = UserDefaults.standard.object(forKey: snoozedUntilKey) as? Date,
           Date() < snoozedUntil {
            return false
        }
        return shouldRequest && lastVersion != currentVersion
    }
    
    func snooze(days: Int = 7) {
        let until = Calendar.current.date(byAdding: .day, value: days, to: Date())
        UserDefaults.standard.set(until, forKey: snoozedUntilKey)
    }
    // 表示済みにする
    func markAsRequested() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        UserDefaults.standard.set(currentVersion, forKey: lastReviewedVersionKey)
        UserDefaults.standard.set(false, forKey: shouldRequestKey)
        UserDefaults.standard.set(0, forKey: recordCountKey)
    }
}
