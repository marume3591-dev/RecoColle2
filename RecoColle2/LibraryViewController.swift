//  LibraryViewController.swift
//  RecoColle2

import UIKit
import CoreData

// MARK: - Sort / Filter Models

enum LibrarySortKey: String, CaseIterable {
    case artistAsc   = "アーティスト名 (A→Z)"
    case artistDesc  = "アーティスト名 (Z→A)"
    case titleAsc    = "タイトル (A→Z)"
    case titleDesc   = "タイトル (Z→A)"
    case dateAsc     = "発売日 (古い順)"
    case dateDesc    = "発売日 (新しい順)"
    case formatAsc   = "フォーマット (A→Z)"
    case labelAsc    = "レーベル (A→Z)"
}

enum LibraryWantsFilter: String, CaseIterable {
    case collectionOnly = "コレクションのみ"
    case wantsOnly      = "ウォントリストのみ"
    case all            = "すべて"
}

struct LibraryFilter {
    var format: String?
    var country: String?
    var label: String?
    var wants: LibraryWantsFilter = .collectionOnly

    var isActive: Bool {
        format != nil || country != nil || label != nil || wants != .collectionOnly
    }
}

// MARK: - LibraryViewController

class LibraryViewController: UIViewController {

    private let context = (UIApplication.shared.delegate as! AppDelegate)
        .persistentContainer.viewContext
    private let fromAppDelegate = UIApplication.shared.delegate as! AppDelegate

    // MARK: - Properties
    private var allRecords: [RecordList2] = []      // CoreDataから取得した全件
    private var displayRecords: [RecordList2] = []  // フィルタ・ソート後の表示用

    private var sortFlg = true
    private var albums: [Albums] = []
    private var uniqueValues2: [String] = []
    private var tbl_index: [[Int]] = [[]]
    private var wkAlbumName = ""
    private var isAdLoaded = false

    // ソート・フィルタ状態
    private var currentSort: LibrarySortKey = .artistAsc
    private var currentFilter = LibraryFilter()

    private var sortFilterButton: UIBarButtonItem!

    // MARK: - UI

    private let segmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Library", "Album"])
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    private let collectionViewLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 2
        return layout
    }()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
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
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bannerHeightConstraint,
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCollectionViewLayout()
    }

    private func updateCollectionViewLayout() {
        let spacing: CGFloat = 2
        let columns: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 8 : 3
        let totalWidth = collectionView.bounds.width
        guard totalWidth > 0 else { return }
        let cellWidth = floor((totalWidth - spacing * (columns - 1)) / columns)
        collectionViewLayout.itemSize = CGSize(width: cellWidth, height: cellWidth)
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
            guard !displayRecords.isEmpty else { return }
            collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: true)
        } else {
            tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        }
    }

    private func updateScrollTopButtonVisibility(offsetY: CGFloat) {
        let shouldShow = offsetY > 200
        let currentlyVisible = scrollTopButton.alpha > 0.5
        if shouldShow && !currentlyVisible { scrollTopButton.alpha = 1 }
        else if !shouldShow && currentlyVisible { scrollTopButton.alpha = 0 }
    }

    // MARK: - NavigationBar

    private func setupNavigationBar() { updateNavBar() }

    private func updateNavBar() {
        let isAlbum = segmentedControl.selectedSegmentIndex == 1

        if isAlbum {
            // アルバムタブ：従来の昇順/降順ボタン＋追加ボタン
            let sortBtn = UIBarButtonItem(
                image: UIImage(systemName: sortFlg ? "arrow.up" : "arrow.down"),
                style: .plain, target: self, action: #selector(albumSortTapped(_:))
            )
            let addBtn = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addAlbumTapped))
            navigationItem.rightBarButtonItem = addBtn
            navigationItem.leftBarButtonItem = sortBtn
        } else {
            // ライブラリタブ：ソート＆フィルタボタン
            sortFilterButton = UIBarButtonItem(
                image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
                style: .plain,
                target: self,
                action: #selector(sortFilterTapped)
            )
            navigationItem.rightBarButtonItem = nil
            navigationItem.leftBarButtonItem = sortFilterButton
            updateSortFilterIcon()
        }
    }

    /// フィルタ有効時はアイコンをfilled＋オレンジに
    private func updateSortFilterIcon() {
        guard segmentedControl.selectedSegmentIndex == 0 else { return }
        let isFiltered = currentFilter.isActive
        let iconName = isFiltered
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle"
        sortFilterButton?.image = UIImage(systemName: iconName)
        sortFilterButton?.tintColor = isFiltered ? .systemOrange : nil
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
        // wantsFlgの絞り込みなしで全件取得し、フィルタ・ソートをSwiftで適用
        let request = NSFetchRequest<RecordList2>(entityName: "RecordList2")
        request.sortDescriptors = [NSSortDescriptor(key: "artistName", ascending: true)]
        do {
            allRecords = try context.fetch(request)
            applyFilterAndSort()
        } catch { print("Library fetch failed:", error) }
    }

    /// フィルタ → ソート を適用して displayRecords を更新
    private func applyFilterAndSort() {
        var result = allRecords

        // --- wantsフィルタ ---
        switch currentFilter.wants {
        case .collectionOnly: result = result.filter { $0.wantsFlg == "false" }
        case .wantsOnly:      result = result.filter { $0.wantsFlg == "true" }
        case .all:            break
        }

        // --- フォーマットフィルタ ---
        if let fmt = currentFilter.format {
            result = result.filter { $0.format == fmt }
        }

        // --- 国フィルタ ---
        if let country = currentFilter.country {
            result = result.filter { $0.releaseCountry == country }
        }

        // --- レーベルフィルタ ---
        if let lbl = currentFilter.label {
            result = result.filter { $0.label == lbl }
        }

        // --- ソート ---
        switch currentSort {
        case .artistAsc:
            result.sort { ($0.artistName ?? "").localizedCompare($1.artistName ?? "") == .orderedAscending }
        case .artistDesc:
            result.sort { ($0.artistName ?? "").localizedCompare($1.artistName ?? "") == .orderedDescending }
        case .titleAsc:
            result.sort { ($0.albumTitle ?? "").localizedCompare($1.albumTitle ?? "") == .orderedAscending }
        case .titleDesc:
            result.sort { ($0.albumTitle ?? "").localizedCompare($1.albumTitle ?? "") == .orderedDescending }
        case .dateAsc:
            result.sort { ($0.releaseDate ?? "") < ($1.releaseDate ?? "") }
        case .dateDesc:
            result.sort { ($0.releaseDate ?? "") > ($1.releaseDate ?? "") }
        case .formatAsc:
            result.sort { ($0.format ?? "").localizedCompare($1.format ?? "") == .orderedAscending }
        case .labelAsc:
            result.sort { ($0.label ?? "").localizedCompare($1.label ?? "") == .orderedAscending }
        }

        displayRecords = result
        updateSortFilterIcon()
        collectionView.reloadData()
    }

    // MARK: - フィルタ用ユニーク値

    private func uniqueFormats() -> [String] {
        Array(Set(allRecords.compactMap {
            let v = $0.format; return (v?.isEmpty == false) ? v : nil
        })).sorted()
    }
    private func uniqueCountries() -> [String] {
        Array(Set(allRecords.compactMap {
            let v = $0.releaseCountry; return (v?.isEmpty == false) ? v : nil
        })).sorted()
    }
    private func uniqueLabels() -> [String] {
        Array(Set(allRecords.compactMap {
            let v = $0.label; return (v?.isEmpty == false) ? v : nil
        })).sorted()
    }

    // MARK: - Sort / Filter Actions

    @objc private func sortFilterTapped() {
        let vc = LibrarySortFilterViewController(
            currentSort: currentSort,
            currentFilter: currentFilter,
            formats: uniqueFormats(),
            countries: uniqueCountries(),
            labels: uniqueLabels()
        )
        vc.onApply = { [weak self] sort, filter in
            guard let self else { return }
            self.currentSort = sort
            self.currentFilter = filter
            self.applyFilterAndSort()
        }
        let nav = UINavigationController(rootViewController: vc)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    @objc private func albumSortTapped(_ sender: UIBarButtonItem) {
        sortFlg.toggle()
        sender.image = UIImage(systemName: sortFlg ? "arrow.up" : "arrow.down")
        loadAlbumData()
    }

    // MARK: - Album Data

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
        let adView = UIView()
        adView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.addSubview(adView)
        NSLayoutConstraint.activate([
            adView.centerXAnchor.constraint(equalTo: bannerView.centerXAnchor),
            adView.centerYAnchor.constraint(equalTo: bannerView.centerYAnchor),
            adView.widthAnchor.constraint(equalToConstant: 320),
            adView.heightAnchor.constraint(equalToConstant: 50),
        ])
        ImobileSdkAds.showBySpotID(forAdMobMediation: sid, view: adView)
    }
}

// MARK: - UICollectionView

extension LibraryViewController: UICollectionViewDelegate, UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        displayRecords.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LibraryCell", for: indexPath) as! LibraryCell
        let record = displayRecords[indexPath.item]
        if let data = record.albumImage, let img = UIImage(data: data as Data) {
            cell.imageView.image = img
        } else {
            cell.imageView.image = UIImage(systemName: "music.note")
            cell.imageView.tintColor = .secondaryLabel
        }
        // ウォントリストは半透明で区別
        cell.contentView.alpha = record.wantsFlg == "true" ? 0.6 : 1.0
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let record = displayRecords[indexPath.item]
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(
            withIdentifier: "AddViewController2"
        ) as! AddViewController2
        vc.mode = .edit
        vc.record = record
        navigationController?.pushViewController(vc, animated: true)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == collectionView || scrollView == tableView {
            updateScrollTopButtonVisibility(offsetY: scrollView.contentOffset.y)
        }
    }
}

// MARK: - UITableView（Album）

extension LibraryViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { uniqueValues2.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 120 : 100
    }

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
        let deleteAction = UIContextualAction(style: .destructive,
            title: NSLocalizedString("delete_action", comment: "")) { [weak self] _, _, done in
            self?.deleteAlbum(indexPath: indexPath); done(true)
        }
        let renameAction = UIContextualAction(style: .normal,
            title: NSLocalizedString("rename_action", comment: "")) { [weak self] _, _, done in
            self?.showRenameAlert(indexPath: indexPath); done(true)
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
        let imgSize: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 100 : 84
        NSLayoutConstraint.activate([
            thumbImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            thumbImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbImageView.widthAnchor.constraint(equalToConstant: imgSize),
            thumbImageView.heightAnchor.constraint(equalToConstant: imgSize),
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

// MARK: - LibrarySortFilterViewController

class LibrarySortFilterViewController: UIViewController {

    var onApply: ((LibrarySortKey, LibraryFilter) -> Void)?

    private var selectedSort: LibrarySortKey
    private var selectedFilter: LibraryFilter

    private let formats: [String]
    private let countries: [String]
    private let labels: [String]

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private enum Section: Int, CaseIterable {
        case sort, filterWants, filterFormat, filterCountry, filterLabel
    }

    init(currentSort: LibrarySortKey,
         currentFilter: LibraryFilter,
         formats: [String],
         countries: [String],
         labels: [String]) {
        self.selectedSort   = currentSort
        self.selectedFilter = currentFilter
        self.formats        = formats
        self.countries      = countries
        self.labels         = labels
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "ソート / フィルタ"
        view.backgroundColor = .systemGroupedBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "リセット", style: .plain, target: self, action: #selector(resetTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = .systemOrange

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "適用", style: .done, target: self, action: #selector(applyTapped)
        )

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate   = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func resetTapped() {
        selectedSort   = .artistAsc
        selectedFilter = LibraryFilter()
        tableView.reloadData()
    }

    @objc private func applyTapped() {
        onApply?(selectedSort, selectedFilter)
        dismiss(animated: true)
    }

    private func filterItems(for section: Section) -> [String] {
        switch section {
        case .filterWants:   return LibraryWantsFilter.allCases.map { $0.rawValue }
        case .filterFormat:  return ["すべて"] + formats
        case .filterCountry: return ["すべて"] + countries
        case .filterLabel:   return ["すべて"] + labels
        default: return []
        }
    }
}

// MARK: - LibrarySortFilterViewController: UITableView

extension LibrarySortFilterViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sec = Section(rawValue: section) else { return 0 }
        return sec == .sort ? LibrarySortKey.allCases.count : filterItems(for: sec).count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .sort:          return "並び順"
        case .filterWants:   return "表示対象"
        case .filterFormat:  return "フォーマット"
        case .filterCountry: return "リリース国"
        case .filterLabel:   return "レーベル"
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        cell.tintColor = UIColor.systemBlue
        guard let sec = Section(rawValue: indexPath.section) else { return cell }

        if sec == .sort {
            let key = LibrarySortKey.allCases[indexPath.row]
            cell.textLabel?.text = key.rawValue
            cell.accessoryType   = (selectedSort == key) ? UITableViewCell.AccessoryType.checkmark : .none
        } else {
            let list = filterItems(for: sec)
            let text = list[indexPath.row]
            cell.textLabel?.text = text

            var isSelected = false
            switch sec {
            case .filterWants:
                isSelected = text == selectedFilter.wants.rawValue
            case .filterFormat:
                isSelected = (text == "すべて" && selectedFilter.format == nil) || text == selectedFilter.format
            case .filterCountry:
                isSelected = (text == "すべて" && selectedFilter.country == nil) || text == selectedFilter.country
            case .filterLabel:
                isSelected = (text == "すべて" && selectedFilter.label == nil) || text == selectedFilter.label
            default: break
            }
            cell.accessoryType = isSelected ? UITableViewCell.AccessoryType.checkmark : .none
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let sec = Section(rawValue: indexPath.section) else { return }

        if sec == .sort {
            selectedSort = LibrarySortKey.allCases[indexPath.row]
            tableView.reloadSections([indexPath.section], with: .none)
        } else {
            let list     = filterItems(for: sec)
            let selected = list[indexPath.row]
            switch sec {
            case .filterWants:
                selectedFilter.wants = LibraryWantsFilter.allCases.first { $0.rawValue == selected } ?? .collectionOnly
            case .filterFormat:
                selectedFilter.format  = (selected == "すべて") ? nil : selected
            case .filterCountry:
                selectedFilter.country = (selected == "すべて") ? nil : selected
            case .filterLabel:
                selectedFilter.label   = (selected == "すべて") ? nil : selected
            default: break
            }
            tableView.reloadSections([indexPath.section], with: .none)
        }
    }
}
