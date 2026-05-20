import UIKit
import CoreData
import SwiftUI
import AppTrackingTransparency
import AdSupport


class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchControllerDelegate, UISearchBarDelegate  {
    
    let fromAppDelegate: AppDelegate = UIApplication.shared.delegate as! AppDelegate
    var sectionArtists: [String] = []
    var sectionRecords: [[RecordList2]] = []
    
    var noimage = UIImage(named:"noimage")!
    var addButtonItem: UIBarButtonItem!
    var wantsFlg = "false"
    var sortFlg = true
    var recordLists : [RecordList2] = []
    var priceCache: [String: String] = [:]
    private var hasAppeared = false
    private var hasVersionChecked = false

    private let indexStackView = UIStackView()
    private var indexLabels: [UILabel] = []
    private var isFetchingPrices = false
    // ─── 1. プロパティ追加（クラス上部、他のプロパティと並べる） ───
    private lazy var scrollToTopButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        button.tintColor = .systemBlue
        button.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        button.layer.cornerRadius = 28
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.2
        button.layer.shadowRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        button.alpha = 0
        button.addTarget(self, action: #selector(scrollToTop), for: .touchUpInside)
        return button
    }()


    // ─── 2. メソッド追加（extensionの外、ViewController本体に） ───
    private func setupScrollToTopButton() {
        view.addSubview(scrollToTopButton)
        NSLayoutConstraint.activate([
            scrollToTopButton.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            scrollToTopButton.bottomAnchor.constraint(
                equalTo: bannerView.topAnchor, constant: -16),
            scrollToTopButton.widthAnchor.constraint(equalToConstant: 56),
            scrollToTopButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    @objc private func scrollToTop() {
        guard !sectionArtists.isEmpty else { return }
        myTableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
    }
    
    @IBAction func discogsButtonTapped(_ sender: UIButton) {
        openDiscogs()
    }
    @objc func openDiscogs() {
        guard let url = URL(string: "https://www.discogs.com"),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    @IBOutlet weak var recordCount: UILabel!
    @IBOutlet weak var myTableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var bannerView: UIView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    var word = ""
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasAppeared = true
        importPendingRecordsIfNeeded {
            self.getData()
            self.myTableView.reloadData()
        }
        navigationController?.isNavigationBarHidden = false
        searchBar.text = nil

        Task {
            await PremiumManager.shared.refresh()
            let isPremium = PremiumManager.shared.isPremium
            bannerView.isHidden = isPremium
            if !isPremium { setupAd() }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ReviewManager.shared.resetCountIfVersionChanged()
        let shouldRequest = UserDefaults.standard.bool(forKey: "shouldRequestReview")
        let lastVersion = UserDefaults.standard.string(forKey: "lastReviewedVersion") ?? ""
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let count = UserDefaults.standard.integer(forKey: "recordCount")
        print("🔍 shouldRequest: \(shouldRequest), lastVersion: \(lastVersion), currentVersion: \(currentVersion), count: \(count)")

        if ReviewManager.shared.shouldShowReviewAlert() {
            showReviewAlert()
        }
        // Widget対応の案内（一度だけ）
        let widgetAnnouncedKey = "widgetAnnouncementShown"
        if !UserDefaults.standard.bool(forKey: widgetAnnouncedKey) {
            UserDefaults.standard.set(true, forKey: widgetAnnouncedKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.showToast(message: NSLocalizedString("widget_announcement", comment: ""))
            }
        }
        
        guard !hasVersionChecked else { return }
        hasVersionChecked = true
        
        let apple_id = "6474089598"
        AppVersionCompare.toAppStoreVersion(appId: apple_id) { (type) in
            switch type {
            case .latest:
                print("new version")
            case .old:
                DispatchQueue.main.async {
                    let alert = UIAlertController(
                        title: NSLocalizedString("update_available_title", comment: ""),
                        message: NSLocalizedString("update_available_message", comment: ""),
                        preferredStyle: .alert
                    )
                    let defaultAction = UIAlertAction(
                        title: NSLocalizedString("update_button_title", comment: ""),
                        style: .default
                    ) { _ in
                        let url = URL(string: "https://apps.apple.com/app/id6474089598")!
                        if UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    }
                    let cancelAction = UIAlertAction(
                        title: NSLocalizedString("later_button", comment: ""),
                        style: .default,
                        handler: nil
                    )
                    alert.addAction(defaultAction)
                    alert.addAction(cancelAction)
                    self.present(alert, animated: true, completion: nil)
                }
            case .error:
                print("error")
            }
        }
        // 初回のみ＋ボタンをパルス
        if !UserDefaults.standard.bool(forKey: "addButtonPulsed") {
            UserDefaults.standard.set(true, forKey: "addButtonPulsed")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                // サンプルデータがある場合は削除を促すトースト
                let hasSample = self.recordLists.contains { $0.memo == "__sample__" }
                if hasSample {
                    self.showToast(message: NSLocalizedString("sample_hint_toast", comment: ""))
                } else {
                    self.showToast(message: NSLocalizedString("first_record_toast", comment: ""))
                }
            }
        }
    }
    
    func showToast(message: String) {
        let toast = UILabel()
        toast.text = message
        toast.textColor = .white
        toast.textAlignment = .center
        toast.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        toast.numberOfLines = 0

        let container = UIView()
        container.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.9)
        container.layer.cornerRadius = 12
        container.clipsToBounds = true
        container.alpha = 0
        toast.translatesAutoresizingMaskIntoConstraints = false
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(toast)
        view.addSubview(container)

        NSLayoutConstraint.activate([
            toast.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            toast.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
            toast.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            toast.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])

        UIView.animate(withDuration: 0.3, animations: { container.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.4, delay: 10.0, animations: { container.alpha = 0 }) { _ in
                container.removeFromSuperview()
            }
        }
    }
    
    func showReviewAlert() {
        let alert = UIAlertController(
            title: NSLocalizedString("review_title", comment: ""),
            message: NSLocalizedString("review_message", comment: ""),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("not_now_button", comment: ""), style: .cancel) { _ in
            ReviewManager.shared.snooze(days: 7) // 7日間スヌーズ
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("review_button", comment: ""), style: .default, handler: { _ in
            ReviewManager.shared.requestReview()
            ReviewManager.shared.markAsRequested()
        }))
        present(alert, animated: true)
    }

    func importPendingRecordsIfNeeded(completion: (() -> Void)? = nil) {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.marume3591.RecoColle2") else {
            completion?()
            return
        }

        let fileURL = containerURL.appendingPathComponent("pending_records.json")

        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let records = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              !records.isEmpty else {
            completion?()
            return
        }

        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext

        context.perform {
            for record in records {
                let newRecord = RecordList2(context: context)
                newRecord.artistName = record["artistName"] as? String
                newRecord.albumTitle = record["albumTitle"] as? String
                newRecord.format = record["format"] as? String
                newRecord.releaseDate = record["releaseDate"] as? String
                newRecord.releaseCountry = record["releaseCountry"] as? String
                newRecord.wantsFlg = record["wantsFlg"] as? String ?? "false"
                newRecord.id = record["id"] as? String ?? UUID().uuidString
                newRecord.memo = record["memo"] as? String
                newRecord.catno = record["catno"] as? String
                newRecord.label = record["label"] as? String
                newRecord.discogsReleaseId = record["discogsReleaseId"] as? String

                if let imageBase64 = record["albumImage"] as? String,
                   let imageData = Data(base64Encoded: imageBase64) {
                    newRecord.albumImage = imageData
                }
            }

            do {
                try context.save()
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                print("❌ pending_records取り込み失敗:", error)
            }

            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(premiumUpdated), name: .premiumStatusChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(recordUpdated), name: .recordUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showRecordDetail(_:)), name: .showRecordDetail, object: nil)
        
        myTableView.dataSource = self
        myTableView.delegate = self
        myTableView.register(RecordCell.self, forCellReuseIdentifier: RecordCell.identifier)
        myTableView.rowHeight = UITableView.automaticDimension
        myTableView.estimatedRowHeight = 110
        myTableView.separatorStyle = .none
        myTableView.backgroundColor = .systemGroupedBackground
        myTableView.sectionHeaderHeight = 24

        configureRefreshControl()
        searchBar.delegate = self
        self.searchBar.autocapitalizationType = .none
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGR.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tapGR)
        addButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addButtonPressed(_:)))
        segmentedControl.backgroundColor = .secondarySystemBackground
        segmentedControl.selectedSegmentTintColor = .systemBlue
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.secondaryLabel], for: .normal)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)

        myTableView.sectionIndexColor = .systemBlue
        myTableView.sectionIndexBackgroundColor = .clear
        myTableView.sectionIndexTrackingBackgroundColor = .clear
        
        let discogsAction = UIAction(
            title: NSLocalizedString("open_discogs_menu", comment: ""),
            image: UIImage(systemName: "safari")
        ) { _ in self.openDiscogs() }

        let valueAction = UIAction(
            title: NSLocalizedString("collection_value_menu", comment: ""),
            image: UIImage(systemName: "chart.bar")
        ) { _ in self.openCollectionValue() }
        let statsAction = UIAction(
            title: NSLocalizedString("collection_stats_menu", comment: ""),
            image: UIImage(systemName: "chart.pie")
        ) { _ in self.openCollectionStats() }


        let menu = UIMenu(title: "", children: [discogsAction, valueAction, statsAction])
        let menuButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), primaryAction: nil, menu: menu)

        navigationItem.leftBarButtonItem = menuButton
        //navigationItem.rightBarButtonItem = addButtonItem
        let barcodeItem = UIBarButtonItem(
            image: UIImage(systemName: "barcode.viewfinder"),
            style: .plain,
            target: self,
            action: #selector(openBarcode)
        )

        let catNoItem = UIBarButtonItem(
            image: UIImage(systemName: "number.square"),
            style: .plain,
            target: self,
            action: #selector(openCatNo)
        )

        let ocrItem = UIBarButtonItem(
            image: UIImage(systemName: "text.viewfinder"),
            style: .plain,
            target: self,
            action: #selector(openOCR)
        )

        let shazamItem = UIBarButtonItem(
            image: UIImage(systemName: "music.note"),
            style: .plain,
            target: self,
            action: #selector(openShazam)
        )

        navigationItem.rightBarButtonItems = [
            addButtonItem,
            shazamItem,
            ocrItem,
            catNoItem,
            barcodeItem
        ]

        for constraint in searchBar.constraints {
            if constraint.firstAttribute == .height {
                constraint.constant = 44
                break
            }
        }
        
        // 空状態ビューの設定
        let emptyView = UIView()
        let emptyLabel = UILabel()
        emptyLabel.text = NSLocalizedString("empty_collection_message", comment: "")
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.font = UIFont.systemFont(ofSize: 15)
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: emptyView.centerYAnchor)
        ])
        myTableView.backgroundView = emptyView
        setupScrollToTopButton()
    }
    @objc func openBarcode() {
        let vc = AddViewController2()
        vc.launchMode = .barcode
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc func openCatNo() {
        guard PremiumManager.shared.isPremiumUser() else {
            showPaywall()
            return
        }
        let vc = AddViewController2()
        vc.launchMode = .catno
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc func openOCR() {
        guard PremiumManager.shared.isPremiumUser() else {
            showPaywall()
            return
        }
        let vc = AddViewController2()
        vc.launchMode = .ocr
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc func openShazam() {
        guard PremiumManager.shared.isPremiumUser() else {
            showPaywall()
            return
        }
        let vc = AddViewController2()
        vc.launchMode = .shazam
        navigationController?.pushViewController(vc, animated: true)
    }

    // ViewController に追加
    private func showPaywall() {
        let alert = UIAlertController(
            title: NSLocalizedString("unlock_premium_title", comment: ""),
            message: NSLocalizedString("unlock_premium_message", comment: ""),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("upgrade_button", comment: ""), style: .default) { _ in
            let vc = UIHostingController(rootView: IAPView())
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: true)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel_button", comment: ""), style: .cancel))
        present(alert, animated: true)
    }
    
    @objc func showRecordDetail(_ notification: Notification) {
        guard let record = notification.object as? RecordList2 else { return }
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let editorVC = storyboard.instantiateViewController(withIdentifier: "AddViewController2") as? AddViewController2 else { return }
        editorVC.mode = .edit
        editorVC.record = record
        navigationController?.pushViewController(editorVC, animated: true)
    }
    
    @objc func openCollectionValue() {
        guard PremiumManager.shared.isPremiumUser() else {
            let alert = UIAlertController(
                title: NSLocalizedString("collection_value_title", comment: ""),
                message: NSLocalizedString("collection_value_message", comment: ""),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("upgrade_button", comment: ""), style: .default) { _ in
                let vc = UIHostingController(rootView: IAPView())
                vc.modalPresentationStyle = .overFullScreen
                self.present(vc, animated: true)
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("cancel_button", comment: ""), style: .cancel))
            present(alert, animated: true)
            return
        }
        let vc = UIHostingController(rootView: CollectionValueView())
        navigationController?.pushViewController(vc, animated: true)
    }
    @objc func openCollectionStats() {
        guard PremiumManager.shared.isPremiumUser() else {
            let alert = UIAlertController(
                title: NSLocalizedString("collection_stats_menu", comment: ""),
                message: NSLocalizedString("collection_stats_premium_message", comment: ""),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("upgrade_button", comment: ""), style: .default) { _ in
                let vc = UIHostingController(rootView: IAPView())
                vc.modalPresentationStyle = .overFullScreen
                self.present(vc, animated: true)
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("cancel_button", comment: ""), style: .cancel))
            present(alert, animated: true)
            return
        }
        let vc = UIHostingController(rootView: CollectionStatsView())
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func appDidBecomeActive() {
        guard hasAppeared else { return }
        importPendingRecordsIfNeeded {
            self.getData()
            self.myTableView.reloadData()
        }
    }

    @objc func recordUpdated(_ notification: Notification) {
        getData()
        myTableView.reloadData()
        
        guard let userInfo = notification.userInfo,
              let artistName = userInfo["artistName"] as? String,
              let albumTitle = userInfo["albumTitle"] as? String else { return }
        
        for (sectionIndex, records) in sectionRecords.enumerated() {
            for (rowIndex, record) in records.enumerated() {
                if record.artistName == artistName && record.albumTitle == albumTitle {
                    let indexPath = IndexPath(row: rowIndex, section: sectionIndex)
                    // アニメーションなしで一瞬で移動
                    self.myTableView.scrollToRow(at: indexPath, at: .middle, animated: false)
                    return
                }
            }
        }
    }
    
    @objc func premiumUpdated() {
        bannerView.isHidden = true
    }

    private var isAdLoaded = false

    func setupAd() {
        guard !isAdLoaded else { return }
        isAdLoaded = true
        let IMOBILE_BANNER_PID = "81561"
        let IMOBILE_BANNER_MID = "567770"
        let IMOBILE_BANNER_SID = "1846313"
        ImobileSdkAds.setTestMode(fromAppDelegate.globalTestMode)
        ImobileSdkAds.register(withPublisherID: IMOBILE_BANNER_PID, mediaID: IMOBILE_BANNER_MID, spotID: IMOBILE_BANNER_SID)
        DispatchQueue.global().async { ImobileSdkAds.start(bySpotID: IMOBILE_BANNER_SID) }
        let imobileAdSize = CGSize(width: 320, height: 50)
        let screenSize = UIScreen.main.bounds.size
        let imobileAdPosX: CGFloat = (screenSize.width - imobileAdSize.width) / 2
        let imobileAdView = UIView(frame: CGRect(x: imobileAdPosX, y: 0, width: imobileAdSize.width, height: imobileAdSize.height))
        bannerView.addSubview(imobileAdView)
        ImobileSdkAds.showBySpotID(forAdMobMediation: IMOBILE_BANNER_SID, view: imobileAdView)
    }

    @objc func addButtonPressed(_ sender: UIBarButtonItem) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let addVC2 = storyboard.instantiateViewController(withIdentifier: "AddViewController2") as? AddViewController2 else { return }
        navigationController?.pushViewController(addVC2, animated: true)
    }

    @objc func dismissKeyboard() { self.view.endEditing(true) }

    override func didReceiveMemoryWarning() { super.didReceiveMemoryWarning() }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sectionRecords[section].count
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionArtists.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RecordCell.identifier, for: indexPath) as! RecordCell
        let record = sectionRecords[indexPath.section][indexPath.row]
        let hasImage = record.albumImage.flatMap { UIImage(data: $0) } != nil
        let image: UIImage? = record.albumImage.flatMap { UIImage(data: $0) } ?? noimage
        let infoText: String = {
            let parts = [record.format, record.releaseCountry].compactMap { $0 }.filter { !$0.isEmpty }
            return parts.joined(separator: " ・ ")
        }()
        let priceText: String? = record.discogsReleaseId.flatMap { priceCache[$0] } ?? " "
        cell.configure(
            title: record.albumTitle ?? "",
            artist: record.artistName ?? "",
            info: infoText,
            releaseYear: record.releaseDate,
            price: priceText,
            image: image,
            isNoImage: !hasImage  // ← 追加
        )
        // サンプルバッジ
        if record.memo == "__sample__" {
            let badge = UILabel()
            badge.text = NSLocalizedString("sample_badge", comment: "")
            badge.font = UIFont.systemFont(ofSize: 10, weight: .bold)
            badge.textColor = .white
            badge.backgroundColor = .systemOrange
            badge.layer.cornerRadius = 4
            badge.clipsToBounds = true
            badge.textAlignment = .center
            badge.tag = 9001
            badge.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(badge)
            NSLayoutConstraint.activate([
                badge.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                badge.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -12),
                badge.widthAnchor.constraint(equalToConstant: 56),
                badge.heightAnchor.constraint(equalToConstant: 18)
            ])
        } else {
            cell.contentView.viewWithTag(9001)?.removeFromSuperview()
        }
        
        if #available(iOS 13.0, *) {
            if cell.interactions.isEmpty {
                let interaction = UIContextMenuInteraction(delegate: self)
                cell.addInteraction(interaction)
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionArtists[section]
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let record = sectionRecords[indexPath.section][indexPath.row]
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let editorVC = storyboard.instantiateViewController(withIdentifier: "AddViewController2") as? AddViewController2 else { return }
        editorVC.mode = .edit
        editorVC.record = record
        navigationController?.pushViewController(editorVC, animated: true)
    }

    @IBAction func segmentButton(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0: wantsFlg = "false"
        case 1: wantsFlg = "true"
        default: break
        }
        searchBar.text = nil
        getData()
        myTableView.reloadData()
    }

    func getData() {
        let request = NSFetchRequest<RecordList2>(entityName: "RecordList2")
        let predicate = NSPredicate(format: "wantsFlg == %@", wantsFlg)
        let sort1 = NSSortDescriptor(
            key: "artistName",
            ascending: sortFlg,
            selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))
        )
        let sort2 = NSSortDescriptor(key: "releaseDate", ascending: sortFlg)
        request.predicate = predicate
        request.sortDescriptors = [sort1, sort2]
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        do {
            recordLists = try context.fetch(request)
            getAfter()
            for record in recordLists {
                guard let releaseId = record.discogsReleaseId else { continue }
                if record.priceUpdatedAt != nil {
                    priceCache[releaseId] = formatPrice(low: record.priceLow)
                }
            }
            fetchAllPrices()
        } catch {
            print("読み込み失敗！")
        }
        updateSegmentTitles()
        myTableView.backgroundView?.isHidden = !recordLists.isEmpty

    }

    func fetchAllPrices() {
        guard !isFetchingPrices else { return }
        isFetchingPrices = true
        let targets = recordLists.filter { $0.discogsReleaseId != nil }
        Task {
            await DiscogsService().updateExchangeRateIfNeeded()
            for record in targets {
                guard let releaseId = record.discogsReleaseId else { continue }
                if priceCache[releaseId] != nil { continue }
                if record.priceUpdatedAt != nil {
                    priceCache[releaseId] = formatPrice(low: record.priceLow)
                    continue
                }
                let stats = try? await DiscogsService().fetchPriceStats(releaseId: releaseId)
                if let stats = stats {
                    priceCache[releaseId] = formatPrice(low: stats.lowest ?? 0)
                    await MainActor.run {
                        record.priceLow = stats.lowest ?? 0
                        record.priceUpdatedAt = Date()
                        try? self.fromAppDelegate.persistentContainer.viewContext.save()
                    }
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            await MainActor.run {
                self.isFetchingPrices = false
                self.myTableView.reloadData()
            }
        }
    }

    private func updateSegmentTitles() {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let requestCollection = NSFetchRequest<RecordList2>(entityName: "RecordList2")
        requestCollection.predicate = NSPredicate(format: "wantsFlg == %@", "false")
        let requestWants = NSFetchRequest<RecordList2>(entityName: "RecordList2")
        requestWants.predicate = NSPredicate(format: "wantsFlg == %@", "true")
        do {
            let collectionCount = try context.count(for: requestCollection)
            let wantsCount = try context.count(for: requestWants)
            segmentedControl.setTitle("Collection \(collectionCount)", forSegmentAt: 0)
            segmentedControl.setTitle("Wants \(wantsCount)", forSegmentAt: 1)
        } catch {
            print("Count error")
        }
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let record = sectionRecords[indexPath.section][indexPath.row]
        if record.memo == "__sample__" {
            let alert = UIAlertController(
                title: NSLocalizedString("sample_delete_title", comment: ""),
                message: NSLocalizedString("sample_delete_message", comment: ""),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("sample_delete_confirm", comment: ""), style: .destructive) { _ in
                let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
                context.delete(record)
                try? context.save()
                self.getData()
                tableView.reloadData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.showToast(message: NSLocalizedString("first_record_toast", comment: ""))
                }
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("cancel_button", comment: ""), style: .cancel))
            present(alert, animated: true)
            return
        }
        if editingStyle == .delete {
            let record = sectionRecords[indexPath.section][indexPath.row]
            let albumId = record.id ?? ""
            context.delete(record)
            do { try context.save() } catch { print("Delete error:", error) }
            let request = NSFetchRequest<Albums>(entityName: "Albums")
            request.predicate = NSPredicate(format: "idRecordList2 == %@", albumId)
            do {
                let results = try context.fetch(request)
                for result in results { context.delete(result) }
                if context.hasChanges { try context.save() }
            } catch { print("Albums delete error:", error) }
            getData()
            tableView.reloadData()
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        if let word = searchBar.text {
            let predicate: NSPredicate
            if word.isEmpty {
                predicate = NSPredicate(format: "wantsFlg == %@", wantsFlg)
            } else {
                let wantsFlgPredicate = NSPredicate(format: "wantsFlg == %@", wantsFlg)
                let serchBarPredicate = NSPredicate(format: "artistName BEGINSWITH[cd] %@", word)
                predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [wantsFlgPredicate, serchBarPredicate])
            }
            let request = NSFetchRequest<RecordList2>(entityName: "RecordList2")
            request.predicate = predicate
            request.sortDescriptors = [
                NSSortDescriptor(
                    key: "artistName",
                    ascending: sortFlg,
                    selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))
                ),
                NSSortDescriptor(key: "releaseDate", ascending: sortFlg)
            ]
            let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
            do {
                recordLists = try context.fetch(request)
                let counts = try context.fetch(request).count
                recordCount?.text = "(\(counts))"
                getAfter()
            } catch { print("読み込み失敗！") }
            myTableView.reloadData()
        }
    }

    func getAfter() {
        sectionArtists.removeAll()
        sectionRecords.removeAll()
        let grouped = Dictionary(grouping: recordLists) { record -> String in
            record.artistName ?? "Unknown"
        }
        sectionArtists = grouped.keys.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        for artist in sectionArtists {
            let records = grouped[artist]?.sorted {
                let year1 = $0.releaseDate ?? ""
                let year2 = $1.releaseDate ?? ""
                if year1 != year2 { return year1 < year2 }
                return ($0.albumTitle ?? "") < ($1.albumTitle ?? "")
            } ?? []
            sectionRecords.append(records)
        }
    }

    func configureRefreshControl() {
        myTableView.refreshControl = UIRefreshControl()
        myTableView.refreshControl?.addTarget(self, action: #selector(handleRefreshControl), for: .valueChanged)
    }

    @objc func handleRefreshControl() {
        searchBar.text = nil
        getData()
        DispatchQueue.main.async {
            self.myTableView.reloadData()
            self.myTableView.refreshControl?.endRefreshing()
        }
    }

    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        let letters = sectionArtists.map { String($0.prefix(1)).uppercased() }
        return Array(Set(letters)).sorted()
    }

    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return sectionArtists.firstIndex(where: { String($0.prefix(1)).uppercased() == title }) ?? 0
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateIndexHighlight()

        let shouldShow = scrollView.contentOffset.y > 300
        UIView.animate(withDuration: 0.2) {
            self.scrollToTopButton.alpha = shouldShow ? 1 : 0
        }
    }
    
    private func updateIndexHighlight() {
        guard let firstVisible = myTableView.indexPathsForVisibleRows?.first else { return }
        let currentSection = firstVisible.section
        guard currentSection < sectionArtists.count else { return }
        let currentLetter = String(sectionArtists[currentSection].prefix(1))
        for label in indexLabels {
            if label.text == currentLetter {
                label.textColor = .systemBlue
                label.font = .systemFont(ofSize: 12, weight: .bold)
                if traitCollection.userInterfaceStyle == .dark {
                    label.layer.shadowColor = UIColor.systemBlue.cgColor
                    label.layer.shadowOpacity = 0.9
                    label.layer.shadowRadius = 4
                }
            } else {
                label.textColor = .secondaryLabel
                label.font = .systemFont(ofSize: 11)
                label.layer.shadowOpacity = 0
            }
        }
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let predicate: NSPredicate
        if searchText.isEmpty {
            predicate = NSPredicate(format: "wantsFlg == %@", wantsFlg)
        } else {
            let wantsFlgPredicate = NSPredicate(format: "wantsFlg == %@", wantsFlg)
            let searchPredicate = NSPredicate(format: "artistName BEGINSWITH[cd] %@", searchText)
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [wantsFlgPredicate, searchPredicate])
        }
        let request = NSFetchRequest<RecordList2>(entityName: "RecordList2")
        request.predicate = predicate
        request.sortDescriptors = [
            NSSortDescriptor(
                key: "artistName",
                ascending: sortFlg,
                selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))
            ),
            NSSortDescriptor(key: "releaseDate", ascending: sortFlg)
        ]
        let context = fromAppDelegate.persistentContainer.viewContext
        do {
            recordLists = try context.fetch(request)
            getAfter()
            myTableView.reloadData()
        } catch { print("検索失敗") }
    }
}

struct ViewController_Previews: PreviewProvider {
    static var previews: some View {
        Text("Hello, World!")
    }
}

extension Notification.Name {
    static let recordUpdated = Notification.Name("recordUpdated")
    static let showRecordDetail = Notification.Name("showRecordDetail")
}

@available(iOS 13.0, *)
extension ViewController: UIContextMenuInteractionDelegate {

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPath(forInteraction: interaction) else { return nil }
        let record = sectionRecords[indexPath.section][indexPath.row]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { _ in
            let openAction = UIAction(
                title: NSLocalizedString("open_action", comment: ""),
                image: UIImage(systemName: "arrow.right")
            ) { _ in
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let addVC = storyboard.instantiateViewController(withIdentifier: "AddViewController2") as! AddViewController2
                addVC.mode = .edit
                addVC.record = record
                self.navigationController?.pushViewController(addVC, animated: true)
            }
            
            // ↓ここを追加
            let snsAction = UIAction(
                title: NSLocalizedString("sns_menu_title", comment: ""),
                image: UIImage(systemName: "sparkles")
            ) { _ in
                let vc = UIHostingController(rootView: SNSPostHintView(record: record))
                self.navigationController?.pushViewController(vc, animated: true)
            }
            
            // ↓childrenにsnsActionを追加するだけ
            return UIMenu(title: "", children: [openAction, snsAction])
        })
    }
    
    func indexPath(forInteraction interaction: UIContextMenuInteraction) -> IndexPath? {
        let location = interaction.location(in: myTableView)
        return myTableView.indexPathForRow(at: location)
    }

    func formatPrice(low: Double) -> String {
        let targetCurrency = Locale.current.currency?.identifier ?? "USD"
        func convert(_ value: Double) -> String {
            if targetCurrency == "USD" { return String(format: "USD %.2f", value) }
            if let rate = ExchangeRateCache.shared.rate(from: "USD", to: targetCurrency) {
                let converted = value * rate
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.currencyCode = targetCurrency
                formatter.maximumFractionDigits = targetCurrency == "JPY" ? 0 : 2
                return formatter.string(from: NSNumber(value: converted)) ?? String(format: "\(targetCurrency) %.2f", converted)
            }
            return String(format: "USD %.2f", value)
        }
        var parts: [String] = []
        if low > 0 { parts.append("Min \(convert(low))") }
        return parts.isEmpty ? "" : parts.joined(separator: " / ")
    }
}
