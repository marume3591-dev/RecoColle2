//
//  AddViewController.swift
//  RecoColle2
//
//  Created by 丸田信一 on 2022/12/15.
//

import UIKit
import AVFoundation
import SwiftUI  

class AddViewController: UIViewController, UITextFieldDelegate,  UIImagePickerControllerDelegate, UINavigationControllerDelegate, AVCaptureMetadataOutputObjectsDelegate , UITextViewDelegate{
    
    private weak var activeField: UIView?
    var ocrImage: UIImage?
    // OCRの用途を切り替えるため
    enum OCRMode {
        case artistTitle
        case catNo
    }
    var shouldRunOCR = false
    var currentOCRMode: OCRMode = .artistTitle
    var ocrResults: [[String: Any]] = []
    let fromAppDelegate: AppDelegate = UIApplication.shared.delegate as! AppDelegate

    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var textField2: UITextField!
    @IBOutlet weak var formatTextField: UITextField!
    @IBOutlet weak var textField3: UITextField!
    @IBOutlet weak var Button: UIButton!
    @IBOutlet weak var textField4: UITextField!
    @IBOutlet weak var memoTextView: UITextView!
    
    @IBOutlet weak var Button1: UIButton!
    //    var formats: [String] = []
    @IBOutlet weak var Button2: UIButton!
    @IBOutlet weak var Button3: UIButton!
    @IBOutlet weak var Button4: UIButton!
    weak var pickerView: UIPickerView?
    @IBOutlet weak var albumImage: UIImageView!
    @IBOutlet weak var listSegment: UISegmentedControl!
    var wantsFlg = "false"
    @IBOutlet weak var bannerView: UIView!
    
    // barCode追加
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    @IBAction func scanBarcodeBtnTapped(_ sender: UIButton) {
        startBarcodeScanning()
    }
    @IBAction func ocrBtnTapped(_ sender: UIButton) {
        guard PremiumManager.shared.isPremiumUser() else {
            showOCRPaywall()
            return
        }
        shouldRunOCR = true
        currentOCRMode = .artistTitle   // ★追加
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = self
        picker.allowsEditing = false

        present(picker, animated: true)
    }
    @IBAction func catNoBtnTapped(_ sender: UIButton) {
        guard PremiumManager.shared.isPremiumUser() else {
            showOCRPaywall()
            return
        }
        shouldRunOCR = true
        currentOCRMode = .catNo
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = self
        picker.allowsEditing = false
        present(picker, animated: true)
    }
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        wantsFlg = sender.selectedSegmentIndex == 1 ? "true" : "false"
    }

    func showOCRPaywall() {
        let alert = UIAlertController(
            title: "Unlock Premium Features",
            message: "Upgrade to Premium to remove ads and enable OCR search for your music collection.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Upgrade", style: .default) { _ in
            let vc = UIHostingController(rootView: IAPView())
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func startBarcodeScanning() {
        captureSession = AVCaptureSession()
        
        guard let session = captureSession else {
            showAlert("Failed to create session")
            return
        }

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            showAlert("Camera is not available")
            return
        }

        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            showAlert("Camera input error")
            return
        }

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            showAlert("Cannot add input")
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean13, .ean8]
        } else {
            showAlert("Cannot add output")
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer!)

        session.startRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let session = captureSession {
            session.stopRunning()
        }

        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let barcode = metadataObject.stringValue {
            foundBarcode(code: barcode)
        }

        previewLayer?.removeFromSuperlayer()
    }

    func foundBarcode(code: String) {
        print("Barcode scanned successfully: \(code)")
        fetchDiscogsInfo(barcode: code)
    }

    func showAlert(_ message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Notice", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
    // バーコードからCD情報を取得
    func fetchDiscogsInfo(barcode: String) {
        var userAgent = "RecoColle2/1.0 (marume3591@icloud.com)"
        let key = "VTvQRnPmaaybKvVDYsej"
        let secret = "VKFSjBMuqcgsAdmMvUzfoeLlsQbGYqdE"
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String{
            userAgent = "RecoColle2/\(version) (marume3591@icloud.com)"
        }

        // 1. search API でバーコード検索
        let searchURL = URL(string: "https://api.discogs.com/database/search?barcode=\(barcode)&key=\(key)&secret=\(secret)")!
        var request = URLRequest(url: searchURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Search API error: \(String(describing: error))")
                DispatchQueue.main.async {
                    self.showAlert("No information found")
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let first = results.first {

                    // cover image
                    let coverURL = first["cover_image"] as? String ?? ""

                    // format（配列の場合が多いので join）
                    let formats = (first["format"] as? [String])?.joined(separator: ", ") ?? ""

                    // country
                    let country = first["country"] as? String ?? ""

                    // title（"Artist – Album" 形式なので分割）
                    let title = first["title"] as? String ?? ""
                    let separators: [Character] = ["–", "-"]
                    let parts = title.split(whereSeparator: { separators.contains($0) })
                                     .map { $0.trimmingCharacters(in: .whitespaces) }

                    let artistName = parts.count > 0 ? parts[0] : ""
                    let albumTitle = parts.count > 1 ? parts[1] : parts[0]
                    
                    // release id を取得
                    guard let releaseID = first["id"] as? Int else {
                        DispatchQueue.main.async {
                            self.showAlert("No information found")
                        }
                        return
                    }

                    // 2. release API で年（released/year）取得
                    let detailURL = URL(string: "https://api.discogs.com/releases/\(releaseID)?key=\(key)&secret=\(secret)")!
                    var detailRequest = URLRequest(url: detailURL)
                    detailRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent") // ここも同じ変数

                    URLSession.shared.dataTask(with: detailRequest) { data, _, error in
                        guard let data = data, error == nil else {
                            print("Release API error: \(String(describing: error))")
                            return
                        }

                        var releaseYearString = ""
                        if let releaseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            // released_year（Int）または released（YYYY-MM-DD 文字列）
                            if let releasedYear = releaseJSON["year"] as? Int {
                                releaseYearString = "\(releasedYear)"
                            } else if let releasedString = releaseJSON["released"] as? String, !releasedString.isEmpty {
                                releaseYearString = String(releasedString.prefix(4))
                            }
                        }

                        // UI 更新はメインスレッドで
                        DispatchQueue.main.async {
                            self.textField.text = artistName              // アーティスト
                            self.textField2.text = albumTitle              // アルバム
                            self.textField3.text = country                 // 国
                            self.textField4.text = releaseYearString       // 年
                            self.formatTextField.text = formats                 // フォーマット

                            // cover art
                            if let url = URL(string: coverURL) {
                                URLSession.shared.dataTask(with: url) { data, _, _ in
                                    if let data = data, let image = UIImage(data: data) {
                                        DispatchQueue.main.async {
                                            self.albumImage.image = image
                                            self.image = image
                                            self.resizedPicture = image.resize(targetSize: CGSize(width: 80, height: 80))
                                        }
                                    }
                                }.resume()
                            }
                        }
                    }.resume()

                } else {
                    DispatchQueue.main.async {
                        self.showAlert("No information found")
                    }
                }
            } catch {
                print("JSON parse error: \(error)")
                DispatchQueue.main.async {
                    self.showAlert("No information found")
                }
            }
        }.resume()
    }
    func fetchDiscogsInfoByOCR(artist: String?, title: String?) {
        guard let artist = artist, let title = title else {
            showAlert("OCR information is incomplete")
            return
        }

        let userAgent = "RecoColle2/1.0 (marume3591@icloud.com)"
        let key = "VTvQRnPmaaybKvVDYsej"
        let secret = "VKFSjBMuqcgsAdmMvUzfoeLlsQbGYqdE"

        let query = "\(artist) \(title)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.discogs.com/database/search?q=\(query)&type=release&key=\(key)&secret=\(secret)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { self.showAlert("Discogs search failed") }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]] {

                    // OCR artist/title でフィルタリング
                    let filteredResults = results.filter { item in
                        guard let itemTitle = item["title"] as? String else { return false }
                        let separators: [Character] = ["–", "-"]
                        let parts = itemTitle.split(whereSeparator: { separators.contains($0) })
                                               .map { $0.trimmingCharacters(in: .whitespaces) }

                        let itemArtist = parts.count > 0 ? parts[0].uppercased() : ""
                        let itemAlbum  = parts.count > 1 ? parts[1].uppercased() : parts[0].uppercased()

                        return itemArtist.contains(artist.uppercased()) && itemAlbum.contains(title.uppercased())
                    }

                    // 年を取得するために DispatchGroup
                    let group = DispatchGroup()
                    var resultsWithYear: [[String: Any]] = []

                    for var item in filteredResults {
                        if let releaseID = item["id"] as? Int {
                            group.enter()
                            let detailURL = URL(string: "https://api.discogs.com/releases/\(releaseID)?key=\(key)&secret=\(secret)")!
                            var detailRequest = URLRequest(url: detailURL)
                            detailRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")

                            URLSession.shared.dataTask(with: detailRequest) { data, _, _ in
                                defer { group.leave() }
                                guard let data = data,
                                      let releaseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

                                if let year = releaseJSON["year"] as? Int {
                                    item["year"] = year
                                } else if let released = releaseJSON["released"] as? String, !released.isEmpty {
                                    item["year"] = Int(released.prefix(4))
                                } else {
                                    item["year"] = ""   // 空白をセット
                                }

                                resultsWithYear.append(item)
                            }.resume()
                        } else {
                            resultsWithYear.append(item)
                        }
                    }

                    group.notify(queue: .main) {
                        if resultsWithYear.isEmpty {
                            self.showAlert("No results match the OCR conditions")
                        } else {
                            self.showOCRResultList(resultsWithYear)
                        }
                    }

                } else {
                    DispatchQueue.main.async { self.showAlert("No search results found") }
                }
            } catch {
                DispatchQueue.main.async { self.showAlert("Failed to parse JSON") }
            }
        }.resume()
    }

    // 一覧表示用のメソッド（既存の showOCRResultList を流用）
    func showOCRResultList(_ ocrResults: [[String: Any]]) {
        let vc = OCRResultViewController(style: .plain)
        vc.results = ocrResults

        vc.onSelect = { selected in
            self.applyDiscogsResult(selected)
        }

        navigationController?.pushViewController(vc, animated: true)
    }

//    func applyDiscogsResult(_ first: [String: Any]) {
//
//        let coverURL = first["cover_image"] as? String ?? ""
//        let formats = (first["format"] as? [String])?.joined(separator: ", ") ?? ""
//        let country = first["country"] as? String ?? ""
//
//        let title = first["title"] as? String ?? ""
//        let separators: [Character] = ["–", "-"]
//        let parts = title.split(whereSeparator: { separators.contains($0) })
//            .map { $0.trimmingCharacters(in: .whitespaces) }
//
//        let artistName = parts.count > 0 ? parts[0] : ""
//        let albumTitle = parts.count > 1 ? parts[1] : parts[0]
//
//        DispatchQueue.main.async {
//            self.textField.text = artistName
//            self.textField2.text = albumTitle
//            self.textField3.text = country
//            self.formatTextField.text = formats
//        }
//
//        // cover image
//        if let url = URL(string: coverURL) {
//            URLSession.shared.dataTask(with: url) { data, _, _ in
//                if let data = data, let image = UIImage(data: data) {
//                    DispatchQueue.main.async {
//                        self.albumImage.image = image
//                        self.image = image
//                        self.resizedPicture = image.resize(
//                            targetSize: CGSize(width: 80, height: 80)
//                        )
//                    }
//                }
//            }.resume()
//        }
//
//        // ===== CATNO → memo に反映 =====
//        var catnoValue: String?
//
//        if let catno = first["catno"] as? String {
//            catnoValue = catno
//        } else if let catnos = first["catno"] as? [String],
//                  let firstCatno = catnos.first {
//            catnoValue = firstCatno
//        }
//
//        if let catno = catnoValue, !catno.isEmpty {
//            DispatchQueue.main.async {
//                self.memoTextView.text = "CATNO: \(catno)"
//            }
//        }
//        
//        // year
//        let releaseID = first["id"] as? Int
//        let masterID  = first["master_id"] as? Int
//
//        fetchReleaseYear(releaseID: releaseID, masterID: masterID) { year in
//            DispatchQueue.main.async {
//                self.textField4.text = year ?? ""
//            }
//        }
//    }
    func applyDiscogsResult(_ first: [String: Any]) {

        let coverURL = first["cover_image"] as? String ?? ""
        let formats = (first["format"] as? [String])?.joined(separator: ", ") ?? ""
        let country = first["country"] as? String ?? ""

        let title = first["title"] as? String ?? ""
        let separators: [Character] = ["–", "-"]
        let parts = title.split(whereSeparator: { separators.contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }

        let artistName = parts.count > 0 ? parts[0] : ""
        let albumTitle = parts.count > 1 ? parts[1] : parts[0]

        DispatchQueue.main.async {
            self.textField.text = artistName
            self.textField2.text = albumTitle
            self.textField3.text = country
            self.formatTextField.text = formats
        }

        // cover image は縮小して保持（フル画像破棄）
        if let url = URL(string: coverURL) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data, let img = UIImage(data: data) else { return }
                let resized = img.resize(targetSize: CGSize(width: 80, height: 80))
                DispatchQueue.main.async {
                    self.albumImage.image = resized
                    self.resizedPicture = resized
                }
            }.resume()
        }

        // CATNO → memo に反映
        var catnoValue: String?
        if let catno = first["catno"] as? String {
            catnoValue = catno
        } else if let catnos = first["catno"] as? [String], let firstCatno = catnos.first {
            catnoValue = firstCatno
        }
        if let catno = catnoValue, !catno.isEmpty {
            DispatchQueue.main.async {
                self.memoTextView.text = "CATNO: \(catno)"
            }
        }

        // year を取得して反映
        let releaseID = first["id"] as? Int
        let masterID  = first["master_id"] as? Int
        fetchReleaseYear(releaseID: releaseID, masterID: masterID) { year in
            DispatchQueue.main.async {
                self.textField4.text = year ?? ""
            }
        }
    }
    // Cover Art Archive からジャケット画像を取得
    func fetchCoverArt(releaseID: String) {
        // フロントカバーのURL
        guard let coverArtURL = URL(string: "https://coverartarchive.org/release/\(releaseID)/front") else {
            return
        }

        URLSession.shared.dataTask(with: coverArtURL) { data, response, error in
            if let error = error {
                print("Cover art fetch error: \(error)")
                return
            }

            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.albumImage.image = image
                    self.albumImage.layer.borderColor = UIColor.blue.cgColor
                    self.albumImage.layer.borderWidth = 1
                }
            }
        }.resume()
    }

    
    var image: UIImage!
    var resizedPicture: UIImage!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = false

        Task {
            await PremiumManager.shared.refresh()
            let isPremium = PremiumManager.shared.isPremium
            bannerView.isHidden = isPremium

            if !isPremium {
                setupAd()
            }

            print("AddView → Premium:", isPremium)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        textField.delegate = self
        textField2.delegate = self
        textField3.delegate = self
        textField4.delegate = self
        formatTextField.delegate = self
        memoTextView.delegate = self
        
        NotificationCenter.default.addObserver(
                self,
                selector: #selector(premiumUpdated),
                name: .premiumStatusChanged,
                object: nil
            )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showkeyboard),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hidekeyboard),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )


        let tap: UITapGestureRecognizer =
            UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)

        //memoTextView.layer.borderColor = UIColor.lightGray.cgColor
        //memoTextView.layer.borderWidth = 1.0

        Button.layer.cornerRadius = 10

        albumImage.layer.borderColor = UIColor.lightGray.cgColor
        albumImage.layer.borderWidth = 1
        
        memoTextView.layer.borderColor = UIColor.lightGray.cgColor
        memoTextView.layer.borderWidth = 0.5
        memoTextView.layer.cornerRadius = 5
        memoTextView.clipsToBounds = true
        
        textField.layer.borderColor = UIColor.lightGray.cgColor
        textField2.layer.borderColor = UIColor.lightGray.cgColor
        formatTextField.layer.borderColor = UIColor.lightGray.cgColor
        textField3.layer.borderColor = UIColor.lightGray.cgColor
        textField4.layer.borderColor = UIColor.lightGray.cgColor
        
        textField.layer.borderWidth = 0.5
        textField2.layer.borderWidth = 0.5
        formatTextField.layer.borderWidth = 0.5
        textField3.layer.borderWidth = 0.5
        textField4.layer.borderWidth = 0.5

        textField.layer.cornerRadius = 5
        textField2.layer.cornerRadius = 5
        formatTextField.layer.cornerRadius = 5
        textField3.layer.cornerRadius = 5
        textField4.layer.cornerRadius = 5

        Button1.layer.cornerRadius = 6
        Button2.layer.cornerRadius = 6
        Button3.layer.cornerRadius = 6
        Button4.layer.cornerRadius = 6
        
        listSegment.selectedSegmentIndex = wantsFlg == "true" ? 1 : 0

    }
    @objc func premiumUpdated() {
        bannerView.isHidden = true
        print("AddView → Premium notified, hide banner")
    }

    private var isAdLoaded = false

    private func setupAd() {
        guard !isAdLoaded else { return }
        isAdLoaded = true

        let IMOBILE_BANNER_PID = "81561"
        let IMOBILE_BANNER_MID = "567770"
        let IMOBILE_BANNER_SID = "1847196"

        ImobileSdkAds.setTestMode(fromAppDelegate.globalTestMode)
        ImobileSdkAds.register(
            withPublisherID: IMOBILE_BANNER_PID,
            mediaID: IMOBILE_BANNER_MID,
            spotID: IMOBILE_BANNER_SID
        )

        DispatchQueue.global().async {
            ImobileSdkAds.start(bySpotID: IMOBILE_BANNER_SID)
        }

        let imobileAdSize = CGSize(width: 320, height: 50)
        let screenSize = UIScreen.main.bounds.size
        let x = (screenSize.width - imobileAdSize.width) / 2

        let adView = UIView(
            frame: CGRect(x: x, y: 0,
                          width: imobileAdSize.width,
                          height: imobileAdSize.height)
        )

        bannerView.addSubview(adView)
        ImobileSdkAds.showBySpotID(
            forAdMobMediation: IMOBILE_BANNER_SID,
            view: adView
        )
    }

// pickerView
    @objc func dismissKeyboard() {
        self.view.endEditing(true)
    }
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

// add Buttom
    @IBAction func btnTapped(_ sender: Any) {
        var flg = ""
        var errorMassage = ""
        
        if textField.text!.isEmpty == true {
            flg = "1"
            errorMassage = "Artist Name"
        }
        if flg == "" {
            if textField2.text!.isEmpty == true {
                flg = "2"
                errorMassage = "Album Title"
            }
        }

        if flg == "" {
            let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
            let recordList = RecordList2(context: context)
            recordList.artistName = textField.text!
            recordList.albumTitle = textField2.text!
            recordList.format = formatTextField.text!
            recordList.releaseCountry = textField3.text!
            recordList.memo = memoTextView.text!
            recordList.wantsFlg = wantsFlg
            recordList.releaseDate = textField4.text!
            let myid: String = NSUUID().uuidString
            recordList.id = myid

            if let resized = resizedPicture {
                recordList.albumImage = resized.jpegData(compressionQuality: 0.7)
            } else {
                recordList.albumImage = nil
            }
            (UIApplication.shared.delegate as! AppDelegate).saveContext()
            navigationController!.popViewController(animated: true)
            NotificationCenter.default.post(name: .recordUpdated, object: nil)
        }else{
            let alui = UIAlertController(title: "Required", message: errorMassage, preferredStyle: UIAlertController.Style.alert)
            let btn = UIAlertAction(title: "Continue", style: UIAlertAction.Style.default, handler: nil)
            alui.addAction(btn)
            present(alui, animated: true, completion: nil)
         }
    }
// 画像選択
    @IBAction func photoBtnTapped(_ sender: Any) {
        shouldRunOCR = false
    // カメラロール表示
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self
        imagePickerController.mediaTypes = ["public.image"]
        present(imagePickerController,animated: true,completion: nil)
    }
//    @objc func imagePickerController(_ picker: UIImagePickerController,
//                                     didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
//
//        picker.dismiss(animated: true)
//
//        guard let image = info[.originalImage] as? UIImage else {
//            return
//        }
//
//        // OCR用に一時変数として保持
//        self.image = image
//        self.resizedPicture = image.resize(targetSize: CGSize(width: 200, height: 200))
//
//        if !shouldRunOCR {
//            // 通常の画像選択（カメラロールやOCRではない場合）は画面反映
//            self.albumImage.image = self.resizedPicture
//            self.albumImage.layer.borderColor = UIColor.blue.cgColor
//            self.albumImage.layer.borderWidth = 1
//        }
//
//        if shouldRunOCR {
//            let service = SpineOCRService()
//            service.recognize(from: image) { hint in
//                // ===== OCR 生ログ =====
//                print("===== OCR RAW RESULT =====")
//                print("texts :", hint.rawTexts)
//                print("catno :", hint.catno ?? "nil")
//                print("==========================")
//
//                switch self.currentOCRMode {
//                case .artistTitle:
//                    self.fetchDiscogsInfoByOCRTexts(hint.rawTexts)
//
//                case .catNo:
//                    if let catNo = hint.catno {
//                        self.fetchDiscogsInfoByCatNo(catNo)
//                    } else {
//                        self.showAlert("Catalog number could not be recognized")
//                    }
//                }
//            }
//        }
//    }
    @objc func imagePickerController(_ picker: UIImagePickerController,
                                     didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage else { return }

        // OCR用に一時変数として縮小して保持
        let resizedForOCR = image.resize(targetSize: CGSize(width: 1024, height: 1024))
        self.ocrImage = resizedForOCR

        if !shouldRunOCR {
            // 通常の画像選択（カメラロールやOCRではない場合）
            let resized = image.resize(targetSize: CGSize(width: 200, height: 200))
            self.albumImage.image = resized
            self.resizedPicture = resized
            // フル解像度画像は破棄
            self.image = nil
        }

        if shouldRunOCR {
            let service = SpineOCRService()
            service.recognize(from: resizedForOCR) { [weak self] hint in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    switch self.currentOCRMode {
                    case .artistTitle:
                        self.fetchDiscogsInfoByOCRTexts(hint.rawTexts)
                    case .catNo:
                        if let catNo = hint.catno {
                            self.fetchDiscogsInfoByCatNo(catNo)
                        } else {
                            self.showAlert("Catalog number could not be recognized")
                        }
                    }
                    // OCR用フル画像は不要になったら破棄
                    self.ocrImage = nil
                }
            }
        }
    }
    
//    func fetchDiscogsInfoByOCRTexts(_ texts: [String]) {
//
//        let key = "VTvQRnPmaaybKvVDYsej"
//        let secret = "VKFSjBMuqcgsAdmMvUzfoeLlsQbGYqdE"
//        let userAgent = "RecoColle2/1.0"
//
//        // OCR結果を1本のクエリにする
//        let query = texts.joined(separator: " ")
//            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
//
//        let urlString =
//            "https://api.discogs.com/database/search" +
//            "?q=\(query)&type=release" +
//            "&key=\(key)&secret=\(secret)"
//
//        guard let url = URL(string: urlString) else { return }
//
//        var request = URLRequest(url: url)
//        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
//
//        URLSession.shared.dataTask(with: request) { data, _, error in
//            guard
//                let data = data,
//                error == nil,
//                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
//                let results = json["results"] as? [[String: Any]],
//                !results.isEmpty
//            else {
//                DispatchQueue.main.async {
//                    self.showAlert("No OCR search results found")
//                }
//                return
//            }
//
//            DispatchQueue.main.async {
//                self.showOCRResultList(results)
//            }
//        }.resume()
//    }
    func fetchDiscogsInfoByOCRTexts(_ texts: [String]) {
        let key = "VTvQRnPmaaybKvVDYsej"
        let secret = "VKFSjBMuqcgsAdmMvUzfoeLlsQbGYqdE"
        let userAgent = "RecoColle2/1.0"

        let query = texts.joined(separator: " ").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.discogs.com/database/search?q=\(query)&type=release&key=\(key)&secret=\(secret)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard
                let data = data,
                error == nil,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let results = json["results"] as? [[String: Any]],
                !results.isEmpty
            else {
                DispatchQueue.main.async { self.showAlert("No OCR search results found") }
                return
            }

            DispatchQueue.main.async {
                self.showOCRResultList(results)
            }
        }.resume()
    }
    
    func fetchDiscogsInfoByCatNo(_ catNo: String) {
        let key = "VTvQRnPmaaybKvVDYsej"
        let secret = "VKFSjBMuqcgsAdmMvUzfoeLlsQbGYqdE"
        let encoded = catNo.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.discogs.com/database/search?catno=\(encoded)&type=release&key=\(key)&secret=\(secret)"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]], !results.isEmpty else {
                self.showAlert("No OCR search results found")
                return
            }

            let group = DispatchGroup()
            var resultsWithYear: [[String: Any]] = []

            for var item in results {
                if let releaseID = item["id"] as? Int {
                    group.enter()
                    let detailURL = URL(string: "https://api.discogs.com/releases/\(releaseID)?key=\(key)&secret=\(secret)")!
                    var detailRequest = URLRequest(url: detailURL)
                    detailRequest.setValue("RecoColle2/1.0", forHTTPHeaderField: "User-Agent")

                    URLSession.shared.dataTask(with: detailRequest) { data, _, _ in
                        defer { group.leave() }
                        guard let data = data,
                              let releaseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

                        if let year = releaseJSON["year"] as? Int {
                            item["year"] = year
                        } else if let released = releaseJSON["released"] as? String, !released.isEmpty {
                            item["year"] = Int(released.prefix(4))
                        } else {
                            item["year"] = ""   // 空白をセット
                        }

                        resultsWithYear.append(item)
                    }.resume()
                } else {
                    resultsWithYear.append(item)
                }
            }

            group.notify(queue: .main) {
                self.showOCRResultList(resultsWithYear)
            }

        }.resume()
    }

    //キーボード表示時
    @objc func showkeyboard(notification: Notification) {

        guard
            let keyboardFrame =
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let activeField = activeField
        else { return }

        // 入力欄の一番下のY座標
        let fieldMaxY = activeField.convert(activeField.bounds, to: self.view).maxY

        let keyboardMinY = keyboardFrame.minY

        let distance = fieldMaxY - keyboardMinY + 20

        if distance > 0 {
            let transform = CGAffineTransform(translationX: 0, y: -distance)
            UIView.animate(withDuration: 0.3) {
                self.view.transform = transform
            }
        }
    }
    //キーボード非表示時
    @objc func hidekeyboard() {
        UIView.animate(withDuration: 0.3) {
            self.view.transform = .identity
        }
    }
    //他の部分を触ったときにキーボードを閉じる
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    func fetchReleaseYear(
        releaseID: Int?,
        masterID: Int?,
        completion: @escaping (String?) -> Void
    ) {
        let key = "VTvQRnPmaaybKvVDYsej"
        let secret = "VKFSjBMuqcgsAdmMvUzfoeLlsQbGYqdE"

        // ① release を優先
        if let releaseID = releaseID {
            let url = URL(string: "https://api.discogs.com/releases/\(releaseID)?key=\(key)&secret=\(secret)")!
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if
                    let data = data,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                {
                    if let year = json["year"] as? Int {
                        completion(String(year))
                        return
                    }
                    if let released = json["released"] as? String {
                        completion(String(released.prefix(4)))
                        return
                    }
                }

                // ② release で取れなければ master
                self.fetchMasterYear(masterID: masterID, completion: completion)
            }.resume()
        } else {
            fetchMasterYear(masterID: masterID, completion: completion)
        }
    }
    
    func fetchMasterYear(
        masterID: Int?,
        completion: @escaping (String?) -> Void
    ) {
        guard let masterID = masterID else {
            completion(nil)
            return
        }

        let key = "VTvQRnPmaaybKvVDYsej"
        let secret = "VKFSjBMuqcgsAdmMvUzfoeLlsQbGYqdE"

        let url = URL(string: "https://api.discogs.com/masters/\(masterID)?key=\(key)&secret=\(secret)")!

        URLSession.shared.dataTask(with: url) { data, _, _ in
            if
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let year = json["year"] as? Int
            {
                completion(String(year))
            } else {
                completion(nil)
            }
        }.resume()
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        activeField = textField
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        activeField = textView
    }

}
