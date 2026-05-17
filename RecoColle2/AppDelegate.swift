//
//  AppDelegate.swift
//  RecoColle2
//
//  Created by 丸田信一 on 2022/11/23.
//

import UIKit
import CoreData
import WidgetKit


@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var globalTestMode = false
    var orientationLock: UIInterfaceOrientationMask = .all
    
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return orientationLock
    }
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // ① 即時反映（UserDefaults）
        PremiumManager.shared.loadFromDefaults()
        
        // ② App Store と同期（非同期）
        Task {
            await PremiumManager.shared.refresh()
        }
        
        migrateCatnoFromMemo()
        saveTodayRecordForWidget()
        
        return true
    }
    private func migrateCatnoFromMemo() {
        let migrationKey = "catnoMigrationCompleted"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        
        let context = persistentContainer.viewContext
        let request = RecordList2.fetchRequest()
        
        guard let records = try? context.fetch(request) else { return }
        
        for record in records {
            guard let memo = record.memo, !memo.isEmpty else { continue }
            
            // "CATNO: XXXXX" を抽出
            let lines = memo.components(separatedBy: .newlines)
            var catnoValue: String? = nil
            var remainingLines: [String] = []
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.uppercased().hasPrefix("CATNO:") {
                    let value = trimmed
                        .dropFirst("CATNO:".count)
                        .trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty {
                        catnoValue = value
                    }
                } else {
                    remainingLines.append(line)
                }
            }
            
            if let catno = catnoValue {
                record.catno = catno
                // memoからCATNO行を除去
                let newMemo = remainingLines
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                record.memo = newMemo.isEmpty ? nil : newMemo
            }
        }
        
        try? context.save()
        UserDefaults.standard.set(true, forKey: migrationKey)
        print("✅ CATNO移行完了")
    }
    
    // MARK: UISceneSession Lifecycle
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}
    
    // MARK: - Core Data stack
    //    lazy var persistentContainer: NSPersistentContainer = {
    //        let container = NSPersistentContainer(name: "DataModel")
    //        container.loadPersistentStores { _, error in
    //            if let error = error {
    //                print(error.localizedDescription)
    //            }
    //        }
    //        // importの通知対応
    //        container.viewContext.automaticallyMergesChangesFromParent = true
    //
    //        return container
    //    }()
    //    lazy var persistentContainer: NSPersistentContainer = {
    //            let container = NSCustomPersistentContainer(name: "DataModel")
    //
    //            container.loadPersistentStores(completionHandler: { (storeDescription, error) in
    //                if let error = error as NSError? {
    //                    print(error.localizedDescription)
    //                }
    //            })
    //            return container
    //        }()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSCustomPersistentContainer(name: "DataModel")
        
        // 旧データ（App Group）のパス ※実際のSQLiteはディレクトリの中
        let oldURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.marume3591.RecoColle2")?
            .appendingPathComponent("DataModel.sqlite")
            .appendingPathComponent("DataModel.sqlite")
        
        // 新データのパス
        let newURL = NSCustomPersistentContainer.defaultDirectoryURL()
            .appendingPathComponent("DataModel.sqlite")
        
        // 新パスがディレクトリになっている場合は削除
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: newURL.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            do {
                try FileManager.default.removeItem(at: newURL)
                print("✅ 不正なディレクトリを削除しました")
            } catch {
                print("❌ ディレクトリ削除失敗:", error)
            }
        }
        
        // 移行処理（一度だけ実行）
        let migrationKey = "iCloudMigrationCompleted"
        if !UserDefaults.standard.bool(forKey: migrationKey),
           let oldURL = oldURL,
           FileManager.default.fileExists(atPath: oldURL.path) {
            
            // 移行前に新パスの既存ファイルを削除
            if FileManager.default.fileExists(atPath: newURL.path) {
                do {
                    try FileManager.default.removeItem(at: newURL)
                    print("✅ 新パスの既存ファイルを削除しました")
                } catch {
                    print("❌ 新パスの既存ファイル削除失敗:", error)
                }
            }
            
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: container.managedObjectModel)
            
            do {
                try coordinator.replacePersistentStore(
                    at: newURL,
                    destinationOptions: nil,
                    withPersistentStoreFrom: oldURL,
                    sourceOptions: [NSSQLitePragmasOption: ["journal_mode": "DELETE"]],
                    ofType: NSSQLiteStoreType
                )
                print("✅ データ移行成功")
                UserDefaults.standard.set(true, forKey: migrationKey)
            } catch {
                print("❌ データ移行失敗:", error)
            }
        }
        
        let storeURL = NSCustomPersistentContainer.defaultDirectoryURL()
            .appendingPathComponent("DataModel.sqlite")
        
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.marume3591.RecoColle2"
        )
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        storeDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        
        container.persistentStoreDescriptions = [storeDescription]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print(error.localizedDescription)
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        return container
    }()
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            try? context.save()
        }
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        saveContext()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        saveTodayRecordForWidget()
    }
    
    func saveTodayRecordForWidget() {
        let defaults = UserDefaults(suiteName: "group.com.marume3591.RecoColle2")
        
        let today = DateFormatter.localizedString(
            from: Date(), dateStyle: .short, timeStyle: .none)
        
        if defaults?.string(forKey: "widgetLastUpdated") == today { return }
        
        let context = persistentContainer.viewContext
        let request = RecordList2.fetchRequest()
        request.predicate = NSPredicate(format: "wantsFlg != 'true'")

        guard let records = try? context.fetch(request),
              let record = records.randomElement() else {
            print("❌ レコードが取得できませんでした")
            return
        }
        
        print("✅ Widget用データ保存: \(record.albumTitle ?? "") / \(record.artistName ?? "")")
        
        defaults?.set(record.albumTitle, forKey: "widgetRecordTitle")
        defaults?.set(record.artistName, forKey: "widgetRecordArtist")
        defaults?.set(record.id, forKey: "widgetRecordId")
        defaults?.set(today, forKey: "widgetLastUpdated")
        
        if let imageData = record.albumImage,
           let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.marume3591.RecoColle2") {
            let imageURL = containerURL.appendingPathComponent("widgetArtwork.jpg")
            try? imageData.write(to: imageURL)
            print("✅ ジャケ写保存完了")
        }
        WidgetCenter.shared.reloadAllTimelines()
            print("✅ Widget更新通知を送信")
    }
}

public extension URL {
    /// Returns a URL for the given app group and database pointing to the sqlite database.
    static func storeURL(for appGroup: String, databaseName: String) -> URL {
        guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            fatalError("Shared file container could not be created.")
        }

        return fileContainer.appendingPathComponent("\(databaseName).sqlite")
    }
}


