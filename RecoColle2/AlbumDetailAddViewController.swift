//
//  AlbumDetailAddViewController.swift
//  RecoColle2
//
//  Created by 丸田信一 on 2024/04/09.
//

import UIKit
import CoreData

class AlbumDetailAddViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    var checkArray: Set<IndexPath> = []
    var recordLists : [RecordList2] = []
    var sortFlg = true
    var noimage = UIImage(named:"noimage")!
    var albumName: String?
    var isNewAlbum: Bool = false

    @IBAction func add(_ sender: Any) {

        guard !checkArray.isEmpty else {
            showAlert(title: NSLocalizedString("alert_title", comment: ""),
                      message: NSLocalizedString("select_one_item", comment: ""))
            return
        }

        guard let albumName = albumName, !albumName.isEmpty else {
            showAlert(title: NSLocalizedString("alert_title", comment: ""),
                      message: NSLocalizedString("album_name_empty", comment: ""))
            return
        }

        let context = (UIApplication.shared.delegate as! AppDelegate)
            .persistentContainer.viewContext

        do {
            if isNewAlbum {
                let request: NSFetchRequest<Albums> = Albums.fetchRequest()
                request.predicate = NSPredicate(format: "albumName == %@", albumName)
                let existing = try context.fetch(request)
                if !existing.isEmpty {
                    showAlert(title: NSLocalizedString("error_title", comment: ""),
                              message: NSLocalizedString("album_exists", comment: ""))
                    return
                }
            }

            for index in checkArray {
                guard index.row < recordLists.count else { continue }
                let recordList = recordLists[index.row]
                let album = Albums(context: context)
                album.id = UUID().uuidString
                album.idRecordList2 = recordList.id
                album.albumName = albumName
            }

            if context.hasChanges {
                try context.save()
            }

            navigationController?.popViewController(animated: true)

        } catch {
            print("Save failed:", error)
            showAlert(title: NSLocalizedString("error_title", comment: ""),
                      message: NSLocalizedString("save_failed", comment: ""))
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok_button", comment: ""), style: .default))
        present(alert, animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("select_items_title", comment: "")
        print("受け取った albumName:", albumName ?? "nil")

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addTapped)
        )

        collectionView.allowsMultipleSelection = true
        collectionView.delegate = self
        collectionView.dataSource = self
        getData()
    }

    @objc func addTapped() {
        add(self)
    }
}

extension AlbumDetailAddViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return recordLists.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
        let albumImage = cell.contentView.viewWithTag(1) as! UIImageView
        let checkMark = cell.contentView.viewWithTag(2) as! UIImageView
        let recordList = recordLists[indexPath.row]
        let imageData = recordList.albumImage

        if let data = imageData {
            albumImage.image = UIImage(data: data)
            albumImage.contentMode = .scaleAspectFill
        } else {
            albumImage.image = noimage
        }

        albumImage.clipsToBounds = true
        checkMark.isHidden = !checkArray.contains(indexPath)

        return cell
    }

    func getData() {
        let request = NSFetchRequest<RecordList2>(entityName: "RecordList2")
        let sortDescripter1 = NSSortDescriptor(key: "artistName", ascending: sortFlg)
        let sortDescripter2 = NSSortDescriptor(key: "releaseDate", ascending: sortFlg)
        request.sortDescriptors = [sortDescripter1, sortDescripter2]
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        do {
            recordLists = try context.fetch(request)
        } catch {
            print("読み込み失敗！")
        }
    }
}

extension AlbumDetailAddViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellSize = collectionView.frame.width / 4 - 3
        return CGSize(width: cellSize, height: cellSize)
    }
}

extension AlbumDetailAddViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        checkArray.insert(indexPath)
        let cell = collectionView.cellForItem(at: indexPath)!
        let checkMark = cell.contentView.viewWithTag(2) as! UIImageView
        checkMark.isHidden = false
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        checkArray.remove(indexPath)
        let cell = collectionView.cellForItem(at: indexPath)!
        let checkMark = cell.contentView.viewWithTag(2) as! UIImageView
        checkMark.isHidden = true
    }
}
