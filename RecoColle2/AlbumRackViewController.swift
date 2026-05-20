import UIKit
import CoreData

class AlbumRackViewController: UIViewController,
                               UICollectionViewDataSource,
                               UICollectionViewDelegate,
                               UIColorPickerViewControllerDelegate {
    
    var albumName: String?
    var flg: String?
    var str: String?
    var recordLists: [RecordList2] = []
    var albums: [Albums] = []
    var wk_indexPath: IndexPath!
    let noimage = UIImage(named: "noimage")!
    
    var checkArray: Set<String> = []
    
    private var myCollectionView: UICollectionView!
    private var layout: UICollectionViewFlowLayout!
    private var columns: Int {
        UIDevice.current.userInterfaceIdiom == .pad ? 8 : 3
    }
    private var deleteBarButton: UIBarButtonItem!
    
    // RecordList2キャッシュ
    private var recordCache: [String: RecordList2] = [:]
    
    // ラック背景色
    private let rackColorKey = "AlbumRackBackgroundColor"
    private var rackColor: UIColor {
        get {
            guard let data = UserDefaults.standard.data(forKey: rackColorKey),
                  let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data)
            else {
                return UIColor(red: 0.55, green: 0.35, blue: 0.18, alpha: 1.0)
            }
            return color
        }
        set {
            let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true)
            UserDefaults.standard.set(data, forKey: rackColorKey)
            myCollectionView.backgroundColor = newValue
        }
    }

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

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = albumName ?? "Albums"
        
        let addButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addTapped)
        )
        
        deleteBarButton = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain,
            target: self,
            action: #selector(deleteTapped)
        )
        
        let colorButton = UIBarButtonItem(
            image: UIImage(systemName: "paintpalette"),
            style: .plain,
            target: self,
            action: #selector(colorTapped)
        )
        
        navigationItem.rightBarButtonItems = [addButton, deleteBarButton, colorButton]
        
        setupCollectionView()
        setupScrollTopButton()
        loadData()
        updateActionButtons()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.bringSubviewToFront(scrollTopButton)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        checkArray.removeAll()
        loadData()
        myCollectionView.reloadData()
        updateActionButtons()
    }
    
    private func setupCollectionView() {
        layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .zero
        
        myCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        myCollectionView.translatesAutoresizingMaskIntoConstraints = false
        myCollectionView.dataSource = self
        myCollectionView.delegate = self
        myCollectionView.allowsMultipleSelection = true
        myCollectionView.register(AlbumCell.self, forCellWithReuseIdentifier: "AlbumCell")
        myCollectionView.backgroundColor = rackColor
        // ★ドラッグ＆ドロップ
        myCollectionView.dragDelegate = self
        myCollectionView.dropDelegate = self
        myCollectionView.dragInteractionEnabled = true
        
        view.addSubview(myCollectionView)
        
        NSLayoutConstraint.activate([
            myCollectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            myCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            myCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            myCollectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

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
        guard !albums.isEmpty else { return }
        myCollectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: true)
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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let width = myCollectionView.bounds.width
        let cellWidth = floor(width / CGFloat(columns))
        layout.itemSize = CGSize(width: cellWidth, height: cellWidth)
    }
    
    private func loadData() {
        let context = (UIApplication.shared.delegate as! AppDelegate)
            .persistentContainer.viewContext
        
        if let albumName = albumName {
            let request = NSFetchRequest<Albums>(entityName: "Albums")
            request.predicate = NSPredicate(format: "albumName == %@", albumName)
            request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            albums = (try? context.fetch(request)) ?? []
            
            recordCache.removeAll()
            let recordIds = albums.compactMap { $0.idRecordList2 }
            
            if !recordIds.isEmpty {
                let recRequest = NSFetchRequest<RecordList2>(entityName: "RecordList2")
                recRequest.predicate = NSPredicate(format: "id IN %@", recordIds)
                
                if let records = try? context.fetch(recRequest) {
                    for rec in records {
                        if let id = rec.id {
                            recordCache[id] = rec
                        }
                    }
                }
            }
        } else if flg == "add" {
            let request = NSFetchRequest<RecordList2>(entityName: "RecordList2")
            recordLists = (try? context.fetch(request)) ?? []
            
            recordCache = Dictionary(uniqueKeysWithValues: recordLists.compactMap { rec in
                rec.id.map { ($0, rec) }
            })
        }
        
        myCollectionView.reloadData()
    }
    
    private func saveSortOrder() {
        let context = (UIApplication.shared.delegate as! AppDelegate)
            .persistentContainer.viewContext
        for (i, album) in albums.enumerated() {
            album.sortOrder = Int32(i)
        }
        try? context.save()
    }
    
    @objc private func deleteTapped() {
        guard !checkArray.isEmpty else { return }
        
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        
        for albumId in checkArray {
            let request = NSFetchRequest<Albums>(entityName: "Albums")
            request.predicate = NSPredicate(format: "id == %@", albumId)
            
            if let results = try? context.fetch(request) {
                for obj in results {
                    context.delete(obj)
                }
            }
        }
        
        try? context.save()
        
        checkArray.removeAll()
        loadData()
        updateActionButtons()
    }
    
    @objc private func addTapped() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(
            withIdentifier: "AlbumDetailAddViewController"
        ) as! AlbumDetailAddViewController
        
        vc.albumName = self.albumName
        
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func colorTapped() {
        let picker = UIColorPickerViewController()
        picker.selectedColor = rackColor
        picker.delegate = self
        present(picker, animated: true)
    }
    
    func colorPickerViewController(_ viewController: UIColorPickerViewController,
                                   didSelect color: UIColor,
                                   continuously: Bool) {
        rackColor = color
    }
    
    private func updateActionButtons() {
        let deleteEnabled = !checkArray.isEmpty
        deleteBarButton.isEnabled = deleteEnabled
        deleteBarButton.tintColor = deleteEnabled ? .systemRed : .systemGray
    }
}

// MARK: - UICollectionViewDataSource / Delegate
extension AlbumRackViewController {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return albumName != nil ? albums.count : recordLists.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let index = indexPath.item
        
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "AlbumCell",
            for: indexPath
        ) as! AlbumCell
        
        var imageData: Data?
        let album: Albums? = albumName != nil ? albums[index] : nil
        
        if let album = album {
            if let recId = album.idRecordList2 {
                imageData = recordCache[recId]?.albumImage
            }
        } else {
            imageData = recordLists[index].albumImage
        }
        
        cell.imageView.image = imageData != nil ? UIImage(data: imageData!) : noimage
        
        if let album = album, let id = album.id {
            cell.checkMarkView.isHidden = !checkArray.contains(id)
        } else {
            cell.checkMarkView.isHidden = true
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        
        let index = indexPath.item
        
        guard let album = albums[safe: index],
              let albumId = album.id else { return }
        
        checkArray.insert(albumId)
        
        if let cell = collectionView.cellForItem(at: indexPath) as? AlbumCell {
            cell.checkMarkView.isHidden = false
        }
        
        updateActionButtons()
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        didDeselectItemAt indexPath: IndexPath) {
        
        let index = indexPath.item
        
        guard let album = albums[safe: index],
              let albumId = album.id else { return }
        
        checkArray.remove(albumId)
        
        if let cell = collectionView.cellForItem(at: indexPath) as? AlbumCell {
            cell.checkMarkView.isHidden = true
        }
        
        updateActionButtons()
    }

    // スクロール検知
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateScrollTopButtonVisibility(offsetY: scrollView.contentOffset.y)
    }
}

// MARK: - AlbumCell
class AlbumCell: UICollectionViewCell {

    let imageView = UIImageView()
    let checkMarkView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.backgroundColor = .clear
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        checkMarkView.image = UIImage(systemName: "checkmark.circle.fill")
        checkMarkView.tintColor = .systemBlue
        checkMarkView.translatesAutoresizingMaskIntoConstraints = false
        checkMarkView.isHidden = true
        
        contentView.addSubview(imageView)
        contentView.addSubview(checkMarkView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
            
            checkMarkView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            checkMarkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            checkMarkView.widthAnchor.constraint(equalToConstant: 20),
            checkMarkView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Array safe subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - UICollectionViewDragDelegate
extension AlbumRackViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        itemsForBeginning session: UIDragSession,
                        at indexPath: IndexPath) -> [UIDragItem] {
        let index = indexPath.item
        guard albums[safe: index] != nil else { return [] }
        let provider = NSItemProvider(object: "\(index)" as NSString)
        let item = UIDragItem(itemProvider: provider)
        item.localObject = indexPath
        return [item]
    }
}

// MARK: - UICollectionViewDropDelegate
extension AlbumRackViewController: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let destinationIndexPath = coordinator.destinationIndexPath,
              let item = coordinator.items.first,
              let sourceIndexPath = item.sourceIndexPath else { return }

        let srcIndex = sourceIndexPath.item
        let dstIndex = destinationIndexPath.item

        guard srcIndex != dstIndex,
              albums[safe: srcIndex] != nil,
              albums[safe: dstIndex] != nil else { return }

        collectionView.performBatchUpdates {
            let moved = albums.remove(at: srcIndex)
            albums.insert(moved, at: dstIndex)
            collectionView.moveItem(at: sourceIndexPath, to: destinationIndexPath)
        } completion: { _ in
            self.saveSortOrder()
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        dropSessionDidUpdate session: UIDropSession,
                        withDestinationIndexPath destinationIndexPath: IndexPath?)
    -> UICollectionViewDropProposal {
        return UICollectionViewDropProposal(
            operation: .move,
            intent: .insertAtDestinationIndexPath
        )
    }
}
