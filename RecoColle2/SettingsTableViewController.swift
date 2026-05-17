//
//  SettingsTableViewController.swift
//  RecoColle2
//
//  Created by 丸田信一 on 2023/10/05.
//

//import UIKit
import SwiftUI
import CoreData
import StoreKit
import ZIPFoundation
import UniformTypeIdentifiers

class SettingsTableViewController: UITableViewController {
    
    let context = (UIApplication.shared.delegate as! AppDelegate)
            .persistentContainer.viewContext
    
    let fromAppDelegate: AppDelegate = UIApplication.shared.delegate as! AppDelegate
    
    var recordLists : [RecordList2] = []
    var albums : [Albums] = []
    
    @IBOutlet weak var version_detail: UILabel!
    @IBOutlet weak var bannerView: UIView!
    @IBAction func dataImport(_ sender: UIButton) {

        let alert = UIAlertController(
            title: NSLocalizedString("import_title", comment: ""),
            message: NSLocalizedString("import_message", comment: ""),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel_button", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok_button", comment: ""), style: .default) { _ in
            // ZIP 選択
            let picker = UIDocumentPickerViewController(
                forOpeningContentTypes: [.zip],
                asCopy: true
            )
            picker.delegate = self
            picker.allowsMultipleSelection = false
            self.present(picker, animated: true)
        })

        present(alert, animated: true)
    }

    @IBAction func dataExport(_ sender: UIButton) {
        let alert = UIAlertController(
            title: NSLocalizedString("export_title", comment: ""),
            message: NSLocalizedString("export_message", comment: ""),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel_button", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok_button", comment: ""), style: .default) { _ in
            self.performExport()
        })

        present(alert, animated: true)
    }

    private func performExport() {
        guard let exportFolderURL = createExportFolder() else {
            showAlert(
                title: NSLocalizedString("error_title", comment: ""),
                message: NSLocalizedString("export_failed", comment: "")
            )
            return
        }

        let zipURL = exportFolderURL.deletingLastPathComponent()
            .appendingPathComponent("RecoColleBackup.zip")

        do {
            let fileManager = FileManager.default

            if fileManager.fileExists(atPath: zipURL.path) {
                try fileManager.removeItem(at: zipURL)
            }

            try fileManager.zipItem(at: exportFolderURL, to: zipURL)

            let vc = UIActivityViewController(
                activityItems: [zipURL],
                applicationActivities: nil
            )

            vc.completionWithItemsHandler = { _, _, _, _ in
                try? fileManager.removeItem(at: exportFolderURL)
                try? fileManager.removeItem(at: zipURL)
            }

            present(vc, animated: true)

        } catch {
            showAlert(
                title: NSLocalizedString("error_title", comment: ""),
                message: error.localizedDescription
            )
        }
    }

    private func deleteExportFolder() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let backupURL = docs.appendingPathComponent("RecoColleBackup")

        if fm.fileExists(atPath: backupURL.path) {
            try? fm.removeItem(at: backupURL)
        }
    }


    @IBAction func item(_ sender: UIButton) {
        let controller = UIHostingController(rootView: IAPView())
        controller.modalPresentationStyle = .overFullScreen
        present(controller, animated: true)
    }
    
    @IBAction func dataDelete(_ sender: UIButton) {
        
        let alert: UIAlertController = UIAlertController(
            title: NSLocalizedString("delete_title", comment: ""),
            message: NSLocalizedString("delete_message", comment: ""),
            preferredStyle: UIAlertController.Style.alert
        )
        let defaultAction: UIAlertAction = UIAlertAction(
            title: NSLocalizedString("ok_button", comment: ""),
            style: UIAlertAction.Style.default,
            handler: { (action: UIAlertAction!) -> Void in
                SettingsTableViewController.cleanUp()
                NotificationCenter.default.post(name: .recordUpdated, object: nil)
                
                let alert = UIAlertController(
                    title: NSLocalizedString("delete_title", comment: ""),
                    message: NSLocalizedString("delete_completed", comment: ""),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: NSLocalizedString("ok_button", comment: ""), style: .default))
                self.present(alert, animated: true, completion: nil)
            }
        )
        let cancelAction: UIAlertAction = UIAlertAction(
            title: NSLocalizedString("cancel_button", comment: ""),
            style: UIAlertAction.Style.cancel,
            handler: { (action: UIAlertAction!) -> Void in }
        )
        alert.addAction(cancelAction)
        alert.addAction(defaultAction)
        present(alert, animated: true, completion: nil)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
        
        Task {
            await PremiumManager.shared.refresh()
            let isPremium = PremiumManager.shared.isPremium
            
            print("Settings → Premium:", isPremium)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let buttonsView = SettingsButtonsView(controller: self)
        let hostingController = UIHostingController(rootView: buttonsView)

        addChild(hostingController)

        tableView.backgroundView = hostingController.view

        hostingController.didMove(toParent: self)

        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
    }
    
    private var isAdLoaded = false
    
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }

    static func save() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            abort()
        }
        
        appDelegate.saveContext()
    }
    static func newAlbum() -> RecordList2 {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            abort()
        }
        
        let managedContext = appDelegate.persistentContainer.viewContext
        let entity = NSEntityDescription.entity(forEntityName: "RecordList2", in: managedContext)!
        let recordLists = RecordList2(entity: entity, insertInto: managedContext)
        
        return recordLists
    }
    static func newAlbum2() -> Albums {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            abort()
        }
        
        let managedContext = appDelegate.persistentContainer.viewContext
        let entity = NSEntityDescription.entity(forEntityName: "Albums", in: managedContext)!
        let albums = Albums(entity: entity, insertInto: managedContext)
        
        return albums
    }
    
    static func cleanUp() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            abort()
        }
        let viewContext = appDelegate.persistentContainer.viewContext
        for entity in appDelegate.persistentContainer.managedObjectModel.entities {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entity.name!)
            let results = try! viewContext.fetch(fetchRequest)
            for result in results {
                viewContext.delete(result)
            }
        }
        
        if viewContext.hasChanges {
            try! viewContext.save()
        }
    }
    
    static func fetchAlbums(with predicate: NSPredicate?) -> [RecordList2] {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            abort()
        }
        
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "RecordList2")
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "artistName", ascending: true)
        ]
        fetchRequest.includesSubentities = false
        
        do {
            let albums = try managedContext.fetch(fetchRequest) as! [RecordList2]
            return albums
        } catch let error as NSError {
            fatalError("Could not fetch albums. \(error), \(error.userInfo)")
        }
    }
    
    // MARK: - Alert Helper
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok_button", comment: ""), style: .default))
        self.present(alert, animated: true)
    }

    func getData() {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext

        let request = NSFetchRequest<RecordList2>(entityName: "RecordList2")
        request.sortDescriptors = [NSSortDescriptor(key: "artistName", ascending: true)]
        recordLists = (try? context.fetch(request)) ?? []

        let request2 = NSFetchRequest<Albums>(entityName: "Albums")
        request2.sortDescriptors = [NSSortDescriptor(key: "albumName", ascending: true)]
        albums = (try? context.fetch(request2)) ?? []
    }

    private func createRecordsCSVText() -> String {
        getData()

        var csv = "id|artistName|albumTitle|format|releaseCountry|releaseDate|wantsFlg|memo|discogsReleaseId|priceLow|priceUpdatedAt\n"

        for record in recordLists {
            let priceUpdatedAtStr = record.priceUpdatedAt.map {
                ISO8601DateFormatter().string(from: $0)
            } ?? ""
            
            var fields: [String] = []
            fields.append(record.id ?? "")
            fields.append(record.artistName ?? "")
            fields.append(record.albumTitle ?? "")
            fields.append(record.format ?? "")
            fields.append(record.releaseCountry ?? "")
            fields.append(record.releaseDate ?? "")
            fields.append(record.wantsFlg ?? "")
            fields.append(record.memo ?? "")
            fields.append(record.discogsReleaseId ?? "")
            fields.append(String(record.priceLow))
            fields.append(priceUpdatedAtStr)
            fields.append(record.catno ?? "")
            fields.append(record.label ?? "")
            let line = fields.joined(separator: "|")
            
            csv += line + "\n"
        }

        return csv
    }
    
    private func createAlbumsCSVText() -> String {
        getData()

        var csv = "id|albumName|idRecordList2\n"

        for album in albums {
            let line = [
                album.id ?? "",
                album.albumName ?? "",
                album.idRecordList2 ?? ""
            ].joined(separator: "|")

            csv += line + "\n"
        }

        return csv
    }

    private func getImageFileURLs() -> [URL] {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        var urls: [URL] = []

        for record in recordLists {
            if let id = record.id {
                let imageURL = documentsURL.appendingPathComponent("\(id).jpg")
                if fileManager.fileExists(atPath: imageURL.path) {
                    urls.append(imageURL)
                }
            }
        }

        return urls
    }

    private func createExportFolder() -> URL? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        let exportDir = documentsURL.appendingPathComponent("RecoColleBackup", isDirectory: true)

        try? fileManager.removeItem(at: exportDir)

        do {
            try fileManager.createDirectory(at: exportDir, withIntermediateDirectories: true)

            let recordsCSVURL = exportDir.appendingPathComponent("records.csv")
            try createRecordsCSVText().write(to: recordsCSVURL, atomically: true, encoding: .utf8)

            let albumsCSVURL = exportDir.appendingPathComponent("albums.csv")
            try createAlbumsCSVText().write(to: albumsCSVURL, atomically: true, encoding: .utf8)

            for record in recordLists {
                guard let id = record.id, let imageData = record.albumImage else { continue }
                let imageURL = exportDir.appendingPathComponent("\(id).jpg")
                try imageData.write(to: imageURL)
            }

            return exportDir

        } catch {
            print("Export error:", error)
            return nil
        }
    }

    private func importAlbums(from url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            if index == 0 || line.isEmpty { continue }

            let cols = line.components(separatedBy: "|")
            guard cols.count >= 3 else { continue }

            let album = Albums(context: context)
            album.id = cols[0]
            album.albumName = cols[1]
            album.idRecordList2 = cols[2]
        }

        try context.save()
    }

    private func importRecords(from url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            if index == 0 || line.isEmpty { continue }

            let cols = line.components(separatedBy: "|")
            guard cols.count >= 8 else { continue }

            let record = RecordList2(context: context)
            record.id = cols[0]
            record.artistName = cols[1]
            record.albumTitle = cols[2]
            record.format = cols[3]
            record.releaseCountry = cols[4]
            record.releaseDate = cols[5]
            record.wantsFlg = cols[6]
            record.memo = cols[7]

            if cols.count >= 11 {
                record.discogsReleaseId = cols[8].isEmpty ? nil : cols[8]
                record.priceLow = Double(cols[9]) ?? 0
                record.priceUpdatedAt = cols[11].isEmpty ? nil : ISO8601DateFormatter().date(from: cols[11])
            }

            if cols.count >= 13 {
                record.catno = cols[11].isEmpty ? nil : cols[11]
                record.label = cols[12].isEmpty ? nil : cols[12]
            }

            let imageURL = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("\(cols[0]).jpg")

            if let imageData = try? Data(contentsOf: imageURL) {
                record.albumImage = imageData
            }
        }
        try context.save()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .recordUpdated, object: nil)
        }
    }
    
    private func importImages(from folderURL: URL) throws {
        let files = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil
        )

        let docURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        for file in files where file.pathExtension.lowercased() == "jpg" {
            let dest = docURL.appendingPathComponent(file.lastPathComponent)

            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }

            try FileManager.default.copyItem(at: file, to: dest)
        }
    }

    private func importBackup(from folderURL: URL) {
        do {
            try deleteAllData(context: context)
            try importImages(from: folderURL)

            let albumsURL = folderURL.appendingPathComponent("albums.csv")
            let recordsURL = folderURL.appendingPathComponent("records.csv")

            try importAlbums(from: albumsURL)
            try importRecords(from: recordsURL)
            deleteTemporaryImages()

            showAlert(
                title: NSLocalizedString("restore_completed_title", comment: ""),
                message: NSLocalizedString("restore_completed_message", comment: "")
            )

        } catch {
            showAlert(
                title: NSLocalizedString("error_title", comment: ""),
                message: error.localizedDescription
            )
        }
    }

    private func deleteTemporaryImages() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]

        if let files = try? fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension.lowercased() == "jpg" {
                try? fm.removeItem(at: file)
            }
        }
    }

    private func deleteAllData(context: NSManagedObjectContext) throws {
        let recordFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "RecordList2")
        let recordDelete = NSBatchDeleteRequest(fetchRequest: recordFetch)

        let albumFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Albums")
        let albumDelete = NSBatchDeleteRequest(fetchRequest: albumFetch)

        try context.execute(recordDelete)
        try context.execute(albumDelete)

        try context.save()
    }

    private func importZipBackup(from zipURL: URL) {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let unzipDir = docs.appendingPathComponent("RecoColleImport")

        do {
            if fm.fileExists(atPath: unzipDir.path) {
                try fm.removeItem(at: unzipDir)
            }
            try fm.createDirectory(at: unzipDir, withIntermediateDirectories: true)

            try fm.unzipItem(at: zipURL, to: unzipDir)

            let backupDir = unzipDir.appendingPathComponent("RecoColleBackup")
            importBackup(from: backupDir)

            try fm.removeItem(at: unzipDir)

        } catch {
            showAlert(
                title: NSLocalizedString("error_title", comment: ""),
                message: error.localizedDescription
            )
        }
    }
}

import SwiftUI
import StoreKit

struct IAPView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var product: Product? = nil
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String? = nil

    private let productID = "NoAds"

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // ── ヘッダー ──
                    VStack(spacing: 8) {
                        SwiftUI.Image(systemName: "star.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.yellow)
                            .padding(.top, 32)

                        Text("RecoColle Premium")
                            .font(.title.bold())

                        Text(LocalizedStringKey("iap_subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 28)

                    // ── ベネフィットリスト ──
                    VStack(spacing: 0) {
                        BenefitRow(
                            icon: "xmark.circle.fill",
                            color: .red,
                            title: NSLocalizedString("benefit_no_ads_title", comment: ""),
                            description: NSLocalizedString("benefit_no_ads_desc", comment: "")
                        )
                        Divider().padding(.leading, 56)

                        BenefitRow(
                            icon: "text.viewfinder",
                            color: .blue,
                            title: NSLocalizedString("benefit_ocr_title", comment: ""),
                            description: NSLocalizedString("benefit_ocr_desc", comment: "")
                        )
                        Divider().padding(.leading, 56)

                        BenefitRow(
                            icon: "music.note",
                            color: .purple,
                            title: NSLocalizedString("benefit_shazam_title", comment: ""),
                            description: NSLocalizedString("benefit_shazam_desc", comment: "")
                        )
                        Divider().padding(.leading, 56)

                        BenefitRow(
                            icon: "chart.line.uptrend.xyaxis",
                            color: .green,
                            title: NSLocalizedString("benefit_value_title", comment: ""),
                            description: NSLocalizedString("benefit_value_desc", comment: "")
                        )
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)

                    // ── 購入ボタン ──
                    Button {
                        Task { await purchase() }
                    } label: {
                        HStack {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 4)
                            }
                            if let product {
                                Text(
                                    String(
                                        format: NSLocalizedString("buy_button_format", comment: ""),
                                        product.displayPrice
                                    )
                                )
                                .font(.headline)
                            } else {
                                Text(LocalizedStringKey("loading"))
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .disabled(product == nil || isPurchasing)
                    .padding(.horizontal, 20)

                    Text(LocalizedStringKey("iap_one_time_note"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.bottom, 20)

                    // ── リストアボタン ──
                    Button {
                        Task { await restore() }
                    } label: {
                        if isRestoring {
                            ProgressView()
                        } else {
                            Text(LocalizedStringKey("restore_purchases"))
                                .font(.subheadline)
                        }
                    }
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                    }

                    // ── 閉じるボタン ──
                    Button {
                        dismiss()
                    } label: {
                        Text(LocalizedStringKey("close_button"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .task {
            await loadProduct()
        }
    }

    // MARK: - StoreKit

    private func loadProduct() async {
        do {
            let products = try await Product.products(for: [productID])
            product = products.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func purchase() async {
        guard let product else { return }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    PremiumManager.shared.setPremium(true)
                    NotificationCenter.default.post(name: .premiumStatusChanged, object: nil)
                    dismiss()
                }
            case .userCancelled:
                break
            case .pending:
                errorMessage = NSLocalizedString("purchase_pending", comment: "")
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await PremiumManager.shared.refresh()
            if PremiumManager.shared.isPremium {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - ベネフィット行

private struct BenefitRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SwiftUI.Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

extension SettingsTableViewController: UIDocumentPickerDelegate {

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        guard let zipURL = urls.first else { return }

        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("RecoColleTemp", isDirectory: true)

        try? fileManager.removeItem(at: tempDir)
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        do {
            try fileManager.unzipItem(at: zipURL, to: tempDir)

            let backupDir = tempDir.appendingPathComponent("RecoColleBackup", isDirectory: true)
            guard fileManager.fileExists(atPath: backupDir.path) else {
                showAlert(
                    title: NSLocalizedString("import_error_title", comment: ""),
                    message: NSLocalizedString("import_error_folder", comment: "")
                )
                return
            }

            importBackup(from: backupDir)

            try? fileManager.removeItem(at: tempDir)

        } catch {
            showAlert(
                title: NSLocalizedString("import_error_title", comment: ""),
                message: error.localizedDescription
            )
        }
    }
}

extension UTType {
    static var zip: UTType {
        UTType(exportedAs: "com.pkware.zip-archive")
    }
}
