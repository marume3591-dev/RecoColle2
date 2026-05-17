//
//  SceneDelegate.swift
//  RecoColle2Debug2
//
//  Created by 丸田信一 on 2026/02/11.
//

import UIKit
import SwiftUI
import AppTrackingTransparency
import AdSupport

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // URLからレコードIDを取得
        if let url = connectionOptions.urlContexts.first?.url,
           url.scheme == "recocolle2",
           url.host == "record",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let recordId = components.queryItems?.first(where: { $0.name == "id" })?.value {
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
                let request = RecordList2.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", recordId)
                guard let record = try? context.fetch(request).first else { return }
                NotificationCenter.default.post(name: .showRecordDetail, object: record)
            }
        }

        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        if !hasCompletedOnboarding {
            // 初回起動：オンボーディングを表示
            let onboardingVC = UIHostingController(rootView: OnboardingFlowView {
                // 「コレクションを見る」タップ時
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                self.insertSampleRecordIfNeeded()
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                if let rootVC = storyboard.instantiateInitialViewController() {
                    self.window?.rootViewController = rootVC
                    self.window?.makeKeyAndVisible()
                }
            })
            let newWindow = UIWindow(windowScene: windowScene)
            newWindow.rootViewController = onboardingVC
            newWindow.makeKeyAndVisible()
            self.window = newWindow
        }
        // 2回目以降はStoryboardのInitial ViewControllerがそのまま使われる
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        print("🔗 URL受信: \(URLContexts.first?.url.absoluteString ?? "なし")")
        guard let url = URLContexts.first?.url,
              url.scheme == "recocolle2",
              url.host == "record",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let recordId = components.queryItems?.first(where: { $0.name == "id" })?.value else {
            print("❌ URL解析失敗")
            return
        }
        print("✅ recordId: \(recordId)")
        guard let url = URLContexts.first?.url,
              url.scheme == "recocolle2",
              url.host == "record",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let recordId = components.queryItems?.first(where: { $0.name == "id" })?.value else { return }
        
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let request = RecordList2.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", recordId)
        
        guard let record = try? context.fetch(request).first else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NotificationCenter.default.post(name: .showRecordDetail, object: record)
        }
    }
    
    private func insertSampleRecordIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "sampleRecordInserted") else { return }
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let sample = RecordList2(context: context)
        sample.id = UUID().uuidString
        sample.artistName = "Miles Davis"
        sample.albumTitle = "Kind of Blue"
        sample.format = "LP, Vinyl"
        sample.releaseCountry = "US"
        sample.releaseDate = "1959"
        sample.label = "Columbia"
        sample.catno = "CS 8163"
        sample.wantsFlg = "false"
        sample.memo = "__sample__"
        try? context.save()
        UserDefaults.standard.set(true, forKey: "sampleRecordInserted")
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if #available(iOS 14, *) {
                ATTrackingManager.requestTrackingAuthorization(completionHandler: { status in
                    switch status {
                    case .authorized:
                        print("IDFA: \(ASIdentifierManager.shared().advertisingIdentifier)")
                        print("success")
                    case .denied, .restricted, .notDetermined:
                        print("failure")
                    @unknown default:
                        fatalError()
                    }
                })
            }
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }
}
