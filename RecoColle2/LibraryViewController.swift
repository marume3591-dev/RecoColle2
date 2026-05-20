//  LibraryViewController.swift
//  RecoColle2

import UIKit
import CoreData

class LibraryViewController: UIViewController {

    private let context = (UIApplication.shared.delegate as! AppDelegate)
        .persistentContainer.viewContext
    private let fromAppDelegate = UIApplication.shared.delegate as! AppDelegate

    // MARK: - Properties
    private var allRecords: [RecordList2] = []
    private var sortFlg = true
    private var albums: [Albums] = []
    private var uniqueValues2: [String] = []
    private var tbl_index: [[Int]] = [[]]
    private var wkAlbumName = ""
    private var isAdLoaded = false
    private var librarySortFlg = true

    // MARK: - UI

    private let segmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Library", "Album"])
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    private lazy var collectionView: UICollectionView = {
        let spacing: CGFloat = 2
        let columns: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 8 : 3
        let width = (UIScreen.main.bounds.width - spacing * (columns - 1)) / columns
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: width, height: width)
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .systemBackground
        return cv
    }()

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.isHidden = true
        tv.rowHeight = UIDevice.current.userInterfaceIdiom == .pad ? 160 : 100
        return tv
    }()

    private let bannerView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .clear
        return v
    }()

    private var bannerHeightConstraint: NSLayoutConstraint!

    // スクロールトップボタン
    private let scrollTopButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        button.setImage(UIImage(systemName: "arrow.up", withConfiguration: config), for: .normal)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.85)
        button.tintColor = .white
        button.layer.cornerRadius = 22
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.25
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.alpha = 0
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = NSLocalizedString("library_title", comment: "")
        tabBarItem = UITabBarItem(
            title: NSLocalizedString("library_title", comment: ""),
            image: UIImage(systemName: "photo.on.rectangle"),
            selectedImage: UIImage(systemName: "photo.on.rectangle.fill")
        )
        setupLayout()
        setupSegment()
        setupCollectionView()
        setupTableView()
        setupNavigationBar()
        setupSegmentStyle()
        setupScrollTopButton()
    }

    private func setupSegmentStyle() {
        segmentedControl.backgroundColor = .secondarySystemBackground
        segmentedControl.selectedSegmentTintColor = .systemBlue
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.secondaryLabel], for: .normal)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = false
        let isLibrary = segmentedControl.selectedSegmentIndex == 0
        collectionView.isHidden = !isLibrary
        tableView.isHidden = isLibrary
        updateNavBar()

        Task {
            await PremiumManager.shared.refresh()
            let isPremium = PremiumManager.shared.isPremium
            bannerHeightConstraint.constant = isPremium ? 0 : 50
            bannerView.isHidden = isPremium
            if !isPremium { setupAd() }
        }

        loadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.bringSubviewToFront(scrollTopButton)
    }

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(segmentedControl)
        view.addSubview(collectionView)
        view.addSubview(tableView)
        view.addSubview(bannerView)

        bannerHeightConstraint = bannerView.heightAnchor.constraint(equalToConstant: 50)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            collectionView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bannerView.topAnchor),

            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            tableView.bottomAnchor.constraint(equalTo: bannerView.topAnchor),
            tableView.widthAnchor.constraint(lessThanOrEqualToConstant: 600),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor),

            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bannerHeightConstraint,
        ])
    }

    // MARK: - ScrollTopButton

    private func setupScrollTopButton() {
        view.addSubview(scrollTopButton)
        view.bringSubviewToFront(scrollTopButton)
        NSLayoutConstraint.activate([
            scrollTopButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollTopButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            scrollTopButton.widthAnchor.constraint(equalToConstant: 44),
            scrollTopButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        scrollTopButton.addTarget(self, action: #selector(scrollToTop), for: .touchUpInside)
    }

    @objc private func scrollToTop() {
        if segmentedControl.selectedSegmentIndex == 0 {
            collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: true)
        } else {
            tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        }
    }

    private func updateScrollTopButtonVisibility(offsetY: CGFloat) {
        let shouldShow = offsetY > 200
        let currentlyVisible = scrollTopButton.alpha > 0.5
        if shouldShow && !currentlyVisible {
            scrollTopButton.alpha = 1
        } else if !shouldShow && currentlyVisible {
            scrollTopButton.alpha = 0
        }
    }

    // MARK: - NavigationBar

    private func setupNavigationBar() { updateNavBar() }

    private func updateNavBar() {
        let isAlbum = segmentedControl.selectedSegmentIndex == 1
        let sortBtn = UIBarButtonItem(
            image: UIImage(systemName: sortFlg ? "arrow.up" : "arrow.down"),
            style: .plain, target: self, action: #selector(sortTapped(_:))
        )
        if isAlbum {
            let addBtn = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addAlbumTapped))
            navigationItem.rightBarButtonItem = addBtn
            navigationItem.leftBarButtonItem = sortBtn
        } else {
            navigationItem.rightBarButtonItem = nil
            navigationItem.leftBarButtonItem = sortBtn
        }
    }

    // MARK: - Segment

    private func setupSegment() {
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
    }

    @objc private func segmentChanged() {
        let isLibrary = segmentedControl.selectedSegmentIndex == 0
        collectionView.isHidden = !isLibrary
        tableView.isHidden = isLibrary
        title = isLibrary
            ? NSLocalizedString("library_title", comment: "")
            : NSLocalizedString("album_title", comment: "")
        updateNavBar()
        // セグメント切替時はボタンを非表示
        scrollTopButton.alpha = 0
        loadData()
    }

    // MARK: - Data

    private func loadData() {
        if segmentedControl.selectedSegmentIndex == 0 {
            loadLibraryData()
        } else {
            loadAlbumData()
        }
    }

    private func loadLibraryData() {
        let request = NSFetchRequest<RecordList2>(entityName: "RecordList2")
        let sort1 = NSSortDescriptor(key: "artistName", ascending: librarySortFlg)
        let sort2 = NSSortDescriptor(key: "releaseDate", ascending: librarySortFlg)
        request.sortDescriptors = [sort1, sort2]
        request.predicate = NSPredicate(format: "wantsFlg == %@", "false")
        do {
            allRecords = try context.fetch(request)
            collectionView.reloadData()
        } catch { print("Library fetch failed:", error) }
    }

    private func loadAlbumData() {
        let request = NSFetchRequest<Albums>(entityName: "Albums")
        request.sortDescriptors = [NSSortDescriptor(key: "albumName", ascending: sortFlg)]
        do {
            albums = try context.fetch(request)
            buildAlbumIndex()
            tableView.reloadData()
        } catch { print("Album fetch failed:", error) }
    }

    private func buildAlbumIndex() {
        var column1: [String] = []
        tbl_index = [[]]
        uniqueValues2 = []
        var index = 0, index2 = 0, wkName = ""
        for myData in albums {
            let name = myData.value(forKey: "albumName") as! String
            column1.append(name)
            if index2 == 0 { wkName = name }
            if wkName != name { index += 1; wkName = name; tbl_index.append([]) }
            tbl_index[index].append(index2)
            index2 += 1
        }
        let orderedSet = NSOrderedSet(array: column1)
        let uniqueValues = orderedSet.array as! [String]
        uniqueValues2 = uniqueValues.map { String($0.prefix(1)) }
    }

    // MARK: - Album Actions

    @objc private func addAlbumTapped() {
        var alertTextField: UITextField?
        let alert = UIAlertController(
            title: NSLocalizedString("add_new_album_title", comment: ""),
            message: NSLocalizedString("input_album_name", comment: ""),
            preferredStyle: .alert
        )
        alert.addTextField { alertTextField = $0 }
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel_button", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok_button", comment: ""), style: .default) { _ in
            guard let text = alertTextField?.text, !text.isEmpty else { return }
            let req = NSFetchRequest<Albums>(entityName: "Albums")
            req.predicate = NSPredicate(format: "albumName == %@", text)
            if let existing = try? self.context.fetch(req), !existing.isEmpty {
                self.showAlert(
                    title: NSLocalizedString("error_title", comment: ""),
                    message: NSLocalizedString("album_exists", comment: "")
                )
                return
            }
            self.wkAlbumName = text
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "AlbumDetailAddViewController") as! AlbumDetailAddViewController
                vc.albumName = self.wkAlbumName
                self.navigationController?.pushViewController(vc, animated: true)
            }
        })
        present(alert, animated: true)
    }

    @objc private func sortTapped(_ sender: UIBarButtonItem) {
        if segmentedControl.selectedSegmentIndex == 1 {
            sortFlg.toggle()
            sender.image = UIImage(systemName: sortFlg ? "arrow.up" : "arrow.down")
            loadAlbumData()
        } else {
            librarySortFlg.toggle()
            sender.image = UIImage(systemName: librarySortFlg ? "arrow.up" : "arrow.down")
            loadLibraryData()
        }
    }

    // MARK: - Album CRUD

    private func deleteAlbum(indexPath: IndexPath) {
        let record = albums[tbl_index[indexPath.section][indexPath.row]]
        let req = NSFetchRequest<Albums>(entityName: "Albums")
        req.predicate = NSPredicate(format: "albumName == %@", record.albumName!)
        do {
            let results = try context.fetch(req)
            results.forEach { context.delete($0) }
            if context.hasChanges { try context.save() }
        } catch { print("Delete failed:", error) }
        loadAlbumData()
    }

    private func showRenameAlert(indexPath: IndexPath) {
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

    private func renameAlbum(oldName: String, newName: String) {
        let checkReq = NSFetchRequest<Albums>(entityName: "Albums")
        checkReq.predicate = NSPredicate(format: "albumName == %@", newName)
        do {
            if !(try context.fetch(checkReq)).isEmpty {
                showAlert(
                    title: NSLocalizedString("error_title", comment: ""),
                    message: NSLocalizedString("album_exists", comment: "")
                )
                return
            }
            let req = NSFetchRequest<Albums>(entityName: "Albums")
            req.predicate = NSPredicate(format: "albumName == %@", oldName)
            let results = try context.fetch(req)
            results.forEach { $0.albumName = newName }
            if context.hasChanges { try context.save() }
            loadAlbumData()
        } catch { print("Rename failed:", error) }
    }

    // MARK: - Helpers

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok_button", comment: ""), style: .default))
        present(alert, animated: true)
    }

    // MARK: - Setup

    private func setupCollectionView() {
        collectionView.register(LibraryCell.self, forCellWithReuseIdentifier: "LibraryCell")
        collectionView.delegate = self
        collectionView.dataSource = self
    }

    private func setupTableView() {
        tableView.register(AlbumTableViewCell.self, forCellReuseIdentifier: "AlbumCell")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
    }

    // MARK: - Ad

    private func setupAd() {
        guard !isAdLoaded else { return }
        isAdLoaded = true
        let pid = "81561", mid = "567770", sid = "1857230"
        ImobileSdkAds.setTestMode(fromAppDelegate.globalTestMode)
        ImobileSdkAds.register(withPublisherID: pid, mediaID: mid, spotID: sid)
        DispatchQueue.global().async { ImobileSdkAds.start(bySpotID: sid) }
        let adSize = CGSize(width: 320, height: 50)
        let x = (UIScreen.main.bounds.width - adSize.width) / 2
        let adView = UIView(frame: CGRect(x: x, y: 0, width: adSize.width, height: adSize.height))
        bannerView.addSubview(adView)
        ImobileSdkAds.showBySpotID(forAdMobMediation: sid, view: adView)
    }
}

// MARK: - UICollectionView

extension LibraryViewController: UICollectionViewDelegate, UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        allRecords.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LibraryCell", for: indexPath) as! LibraryCell
        let record = allRecords[indexPath.item]
        if let data = record.albumImage, let img = UIImage(data: data as Data) {
            cell.imageView.image = img
        } else {
            cell.imageView.image = UIImage(systemName: "music.note")
            cell.imageView.tintColor = .secondaryLabel
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let record = allRecords[indexPath.item]
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(
            withIdentifier: "AddViewController2"
        ) as! AddViewController2
        vc.mode = .edit
        vc.record = record
        navigationController?.pushViewController(vc, animated: true)
    }

    // コレクションビューのスクロール検知
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // tableView のスクロールと区別
        if scrollView == collectionView || scrollView == tableView {
            updateScrollTopButtonVisibility(offsetY: scrollView.contentOffset.y)
        }
    }
}

// MARK: - UITableView（Album）

extension LibraryViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { uniqueValues2.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 100 }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { .leastNormalMagnitude }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AlbumCell", for: indexPath) as! AlbumTableViewCell
        let album = albums[tbl_index[indexPath.section][indexPath.row]]
        cell.configure(
            albumName: album.albumName ?? "",
            count: tbl_index[indexPath.section].count,
            context: context,
            idRecordList2: album.idRecordList2 ?? ""
        )
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let album = albums[tbl_index[indexPath.section][indexPath.row]]
        wkAlbumName = album.albumName!
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "AlbumRackViewController") as! AlbumRackViewController
        vc.albumName = wkAlbumName
        vc.flg = "update"
        navigationController?.pushViewController(vc, animated: true)
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { true }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(
            style: .destructive,
            title: NSLocalizedString("delete_action", comment: "")
        ) { [weak self] _, _, done in
            self?.deleteAlbum(indexPath: indexPath)
            done(true)
        }
        let renameAction = UIContextualAction(
            style: .normal,
            title: NSLocalizedString("rename_action", comment: "")
        ) { [weak self] _, _, done in
            self?.showRenameAlert(indexPath: indexPath)
            done(true)
        }
        renameAction.backgroundColor = .systemBlue
        return UISwipeActionsConfiguration(actions: [deleteAction, renameAction])
    }
}

// MARK: - LibraryCell

class LibraryCell: UICollectionViewCell {
    let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - AlbumTableViewCell

class AlbumTableViewCell: UITableViewCell {

    private let thumbImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 4
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let countLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(thumbImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(countLabel)
        NSLayoutConstraint.activate([
            thumbImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            thumbImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbImageView.widthAnchor.constraint(equalToConstant: UIDevice.current.userInterfaceIdiom == .pad ? 140 : 84),
            thumbImageView.heightAnchor.constraint(equalToConstant: UIDevice.current.userInterfaceIdiom == .pad ? 140 : 84),
            nameLabel.leadingAnchor.constraint(equalTo: thumbImageView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            countLabel.leadingAnchor.constraint(equalTo: thumbImageView.trailingAnchor, constant: 12),
            countLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(albumName: String, count: Int, context: NSManagedObjectContext, idRecordList2: String) {
        nameLabel.text = albumName
        countLabel.text = "(\(count))"
        let req = NSFetchRequest<RecordList2>(entityName: "RecordList2")
        req.predicate = NSPredicate(format: "id == %@", idRecordList2)
        if let result = try? context.fetch(req),
           let first = result.first,
           let data = first.albumImage,
           let img = UIImage(data: data as Data) {
            thumbImageView.image = img
        } else {
            thumbImageView.image = UIImage(systemName: "music.note.list")
            thumbImageView.tintColor = .secondaryLabel
        }
    }
}
