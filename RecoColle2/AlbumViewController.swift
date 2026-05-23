//
//  AlbumViewController.swift
//  RecoColle2
//
//  Created by 丸田信一 on 2024/02/25.
//

import UIKit
import CoreData


class AlbumViewController: UIViewController {
    
    let fromAppDelegate: AppDelegate = UIApplication.shared.delegate as! AppDelegate

    var sortFlg = true
    var albums : [Albums] = []
    var counts = 0
    var uniqueCount = 0
    var uniqueValues : [String] = []
    var uniqueValues2 : [String] = []
    var column2 : [Int] = []
    var tbl_index:[[Int]] = [[]]
    var recordLists : [RecordList2] = []
    var wkAlbumName = ""
    var albumName: UITextField!
    
    @IBOutlet weak var BannerView: UIView!
    
    @IBAction func addButton(_ sender: UIButton) {
        var alertTextField: UITextField?
        
        let alertController = UIAlertController(
            title: NSLocalizedString("add_new_album_title", comment: ""),
            message: NSLocalizedString("input_album_name", comment: ""),
            preferredStyle: .alert
        )
        alertController.addTextField { textField in
            alertTextField = textField
        }
        
        alertController.addAction(UIAlertAction(title: NSLocalizedString("cancel_button", comment: ""), style: .cancel))
        
        let okAction = UIAlertAction(title: NSLocalizedString("ok_button", comment: ""), style: .default) { _ in
            guard let text = alertTextField?.text, !text.isEmpty else { return }
            
            let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<Albums>(entityName: "Albums")
            fetchRequest.predicate = NSPredicate(format: "albumName == %@", text)
            
            do {
                let existing = try context.fetch(fetchRequest)
                if !existing.isEmpty {
                    let errorAlert = UIAlertController(
                        title: NSLocalizedString("error_title", comment: ""),
                        message: NSLocalizedString("album_exists", comment: ""),
                        preferredStyle: .alert
                    )
                    errorAlert.addAction(UIAlertAction(title: NSLocalizedString("ok_button", comment: ""), style: .default))
                    self.present(errorAlert, animated: true)
                    return
                }
            } catch {
                print("Fetch failed:", error)
            }
            
            self.wkAlbumName = text
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.performSegue(withIdentifier: "toNext", sender: nil)
            }
        }
        
        alertController.addAction(okAction)
        present(alertController, animated: true)
    }

    @objc func addAlbumTapped() {
        addButton(UIButton())
    }
    
    @IBOutlet weak var TableView: UITableView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = false

        Task {
            await PremiumManager.shared.refresh()
            let isPremium = PremiumManager.shared.isPremium
            BannerView.isHidden = isPremium
            if !isPremium { setupAd() }
        }

        getData()
        TableView.reloadData()
    }
    
    @objc func sortTapped(_ sender: UIBarButtonItem) {
        sortFlg.toggle()
        let imageName = sortFlg ? "arrow.up" : "arrow.down"
        sender.image = UIImage(systemName: imageName)
        getData()
        TableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("album_title", comment: "")

        TableView.delegate = self
        TableView.dataSource = self
        TableView.register(AlbumListCell.self, forCellReuseIdentifier: AlbumListCell.identifier)
        TableView.rowHeight = UIDevice.current.userInterfaceIdiom == .pad ? 120 : 100
        TableView.separatorStyle = .none

        // Storyboardの固定幅制約を上書きしてiPadで全幅表示
        TableView.translatesAutoresizingMaskIntoConstraints = false
        TableView.constraints.forEach { TableView.removeConstraint($0) }
        if let superview = TableView.superview {
            NSLayoutConstraint.activate([
                TableView.topAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.topAnchor),
                TableView.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
                TableView.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
                TableView.bottomAnchor.constraint(equalTo: BannerView.topAnchor),
            ])
        }

        let addBtn = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addAlbumTapped)
        )

        let sortButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.up"),
            style: .plain,
            target: self,
            action: #selector(sortTapped)
        )

        navigationItem.leftBarButtonItem = sortButton
        navigationItem.rightBarButtonItem = addBtn
    }
    
    @objc func premiumUpdated() {
        BannerView.isHidden = true
    }

    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok_button", comment: ""), style: .default))
        present(alert, animated: true)
    }

    private var isAdLoaded = false

    private func setupAd() {
        guard !isAdLoaded else { return }
        isAdLoaded = true

        let IMOBILE_BANNER_PID = "81561"
        let IMOBILE_BANNER_MID = "567770"
        let IMOBILE_BANNER_SID = "1857230"

        ImobileSdkAds.setTestMode(fromAppDelegate.globalTestMode)
        ImobileSdkAds.register(
            withPublisherID: IMOBILE_BANNER_PID,
            mediaID: IMOBILE_BANNER_MID,
            spotID: IMOBILE_BANNER_SID
        )

        DispatchQueue.global().async {
            ImobileSdkAds.start(bySpotID: IMOBILE_BANNER_SID)
        }

        let adView = UIView()
        adView.translatesAutoresizingMaskIntoConstraints = false
        BannerView.addSubview(adView)
        NSLayoutConstraint.activate([
            adView.centerXAnchor.constraint(equalTo: BannerView.centerXAnchor),
            adView.centerYAnchor.constraint(equalTo: BannerView.centerYAnchor),
            adView.widthAnchor.constraint(equalToConstant: 320),
            adView.heightAnchor.constraint(equalToConstant: 50),
        ])
        ImobileSdkAds.showBySpotID(forAdMobMediation: IMOBILE_BANNER_SID, view: adView)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toNext" {
            let nextVC = segue.destination as! AlbumDetailAddViewController
            nextVC.albumName = wkAlbumName
        } else if segue.identifier == "toAlbumRack" {
            let nextView = segue.destination as! AlbumRackViewController
            nextView.albumName = wkAlbumName
            nextView.flg = "update"
        }
    }

    func getData() {
        let request = NSFetchRequest<Albums>(entityName: "Albums")
        let sortDescripter1 = NSSortDescriptor(key: "albumName", ascending: sortFlg)
        request.sortDescriptors = [sortDescripter1]
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        do {
            albums = try context.fetch(request)
            counts = albums.count
            getAfter()
        } catch {
            print("読み込み失敗！")
        }
    }

    func getAfter() {
        var column1 : [String] = []
        column2 = []
        uniqueValues2 = []
        var index = 0
        var index2 = 0
        var wk_artistName = ""
        tbl_index = [[]]
        for myData in albums {
            let wk_tbl_artistName = myData.value(forKey: "albumName") as! String
            column1.append(String(wk_tbl_artistName))
            if index2 == 0 { wk_artistName = String(wk_tbl_artistName) }
            if wk_artistName != String(wk_tbl_artistName) {
                index = index + 1
                wk_artistName = String(wk_tbl_artistName)
                tbl_index.append([])
            }
            tbl_index[index].append(index2)
            index2 = index2 + 1
        }
        var wk_elt : String = ""
        var cnt = 0
        for elt in column1 {
            if wk_elt == "" { wk_elt = elt }
            if wk_elt == elt { cnt = cnt + 1 }
            else { column2.append(cnt); wk_elt = elt; cnt = 1 }
        }
        column2.append(cnt)
        let orderedSet = NSOrderedSet(array: column1)
        uniqueValues = orderedSet.array as! [String]
        for wk in uniqueValues {
            let aaa = wk as String
            let bbb = aaa.prefix(1)
            uniqueValues2.append(String(bbb))
        }
        uniqueCount = uniqueValues2.count
    }
}

extension AlbumViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return uniqueCount
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UIDevice.current.userInterfaceIdiom == .pad ? 120 : 100
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = TableView.dequeueReusableCell(withIdentifier: AlbumListCell.identifier, for: indexPath) as! AlbumListCell
        let album = albums[tbl_index[indexPath.section][indexPath.row]]
        cell.nameLabel.text = album.albumName
        cell.countLabel.text = "(\(tbl_index[indexPath.section].count))"

        let request = NSFetchRequest<RecordList2>(entityName: "RecordList2")
        request.predicate = NSPredicate(format: "id == %@", album.idRecordList2!)
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        do {
            recordLists = try context.fetch(request)
        } catch {
            print("読み込み失敗！")
        }

        if let first = recordLists.first, let imageData = first.albumImage, let img = UIImage(data: imageData as Data) {
            cell.albumImageView.image = img
        } else {
            cell.albumImageView.image = UIImage(systemName: "music.note.list")
            cell.albumImageView.tintColor = .secondaryLabel
        }

        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let album = albums[tbl_index[indexPath.section][indexPath.row]]
        wkAlbumName = album.albumName!
        performSegue(withIdentifier: "toAlbumRack", sender: self)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }

    func deleteAlbum(indexPath: IndexPath) {
        let record = albums[tbl_index[indexPath.section][indexPath.row]]
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let request = NSFetchRequest<Albums>(entityName: "Albums")
        request.predicate = NSPredicate(format: "albumName == %@", record.albumName!)
        do {
            let results = try context.fetch(request)
            for result in results { context.delete(result) }
            if context.hasChanges { try context.save() }
        } catch {
            print("Delete failed:", error)
        }
        getData()
        TableView.reloadData()
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {

        let deleteAction = UIContextualAction(
            style: .destructive,
            title: NSLocalizedString("delete_action", comment: "")
        ) { [weak self] _, _, completionHandler in
            self?.deleteAlbum(indexPath: indexPath)
            completionHandler(true)
        }

        let renameAction = UIContextualAction(
            style: .normal,
            title: NSLocalizedString("rename_action", comment: "")
        ) { [weak self] _, _, completionHandler in
            self?.showRenameAlert(indexPath: indexPath)
            completionHandler(true)
        }
        renameAction.backgroundColor = .systemBlue

        return UISwipeActionsConfiguration(actions: [deleteAction, renameAction])
    }

    func showRenameAlert(indexPath: IndexPath) {
        let album = albums[tbl_index[indexPath.section][indexPath.row]]
        let oldName = album.albumName!

        let alert = UIAlertController(
            title: NSLocalizedString("rename_album_title", comment: ""),
            message: NSLocalizedString("input_new_album_name", comment: ""),
            preferredStyle: .alert
        )
        alert.addTextField { $0.text = oldName }
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel_button", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok_button", comment: ""), style: .default) { _ in
            guard let newName = alert.textFields?.first?.text, !newName.isEmpty else { return }
            self.renameAlbum(oldName: oldName, newName: newName)
        })
        present(alert, animated: true)
    }

    func renameAlbum(oldName: String, newName: String) {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext

        let checkRequest = NSFetchRequest<Albums>(entityName: "Albums")
        checkRequest.predicate = NSPredicate(format: "albumName == %@", newName)
        do {
            let existing = try context.fetch(checkRequest)
            if !existing.isEmpty {
                showAlert(
                    title: NSLocalizedString("error_title", comment: ""),
                    message: NSLocalizedString("album_exists", comment: "")
                )
                return
            }
        } catch {
            print("Fetch failed:", error)
        }

        let request = NSFetchRequest<Albums>(entityName: "Albums")
        request.predicate = NSPredicate(format: "albumName == %@", oldName)
        do {
            let results = try context.fetch(request)
            for album in results { album.albumName = newName }
            if context.hasChanges { try context.save() }
            getData()
            TableView.reloadData()
        } catch {
            print("Rename failed:", error)
        }
    }
}

// MARK: - AlbumListCell

class AlbumListCell: UITableViewCell {
    static let identifier = "AlbumListCell"

    let albumImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 4
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    let countLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(albumImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(countLabel)

        let imgSize: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 96 : 80

        NSLayoutConstraint.activate([
            albumImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            albumImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            albumImageView.widthAnchor.constraint(equalToConstant: imgSize),
            albumImageView.heightAnchor.constraint(equalToConstant: imgSize),

            nameLabel.leadingAnchor.constraint(equalTo: albumImageView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),

            countLabel.leadingAnchor.constraint(equalTo: albumImageView.trailingAnchor, constant: 12),
            countLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}
