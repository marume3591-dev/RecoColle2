//
//  AddViewController.swift
//  RecoColle2
//
//  Created by 丸田信一 on 2022/12/15.
//

import UIKit
import AVFoundation
import SwiftUI
import Vision
import ShazamKit


class AddViewController2: UIViewController, UITextFieldDelegate,  UIImagePickerControllerDelegate, UINavigationControllerDelegate, AVCaptureMetadataOutputObjectsDelegate , UITextViewDelegate, AVCaptureVideoDataOutputSampleBufferDelegate{
    
    let fromAppDelegate: AppDelegate = UIApplication.shared.delegate as! AppDelegate
    private var bannerHeightConstraint: NSLayoutConstraint!
    private weak var activeField: UIView?
    private var shazamSession: SHSession?
    private var audioEngine: AVAudioEngine?
    private var focusTapGesture: UITapGestureRecognizer?
    private var initialArtist: String = ""
    private var initialTitle: String = ""
    private var initialFormat: String = ""
    private var initialCountry: String = ""
    private var initialYear: String = ""
    private var initialMemo: String = ""
    private var initialWantsFlg: String = "false"
    private var initialImageData: Data? = nil
    private var initialDiscogsReleaseId: String? = nil
    private var initialPriceLow: Double = 0
    private var initialPriceUpdatedAt: Date? = nil
    private var initialCatno: String? = nil
    private var initialLabel: String? = nil
    
    weak var pickerView: UIPickerView?
    
    enum OCRMode {
        case artistTitle
        case catNo
    }
    enum ScreenMode {
        case add
        case edit
    }
    enum LaunchMode {
        case normal
        case barcode
        case ocr
        case shazam
        case catno
    }

    var launchMode: LaunchMode = .normal
    
    var mode: ScreenMode = .add
    var record: RecordList2?
    
    var ocrImage: UIImage?
    var shouldRunOCR = false
    var currentOCRMode: OCRMode = .artistTitle
    var ocrResults: [[String: Any]] = []
    var wantsFlg = "false"
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var videoOutput = AVCaptureVideoDataOutput()
    var isProcessingOCR = false
    var isScanning = false
    var scanFrameRect: CGRect = .zero
    var roiRect: CGRect = .zero
    var shouldCaptureFrame = false
    var pendingDiscogsReleaseId: String?
    var pendingPriceLow: Double = 0
    var pendingPriceUpdatedAt: Date? = nil
    var pendingCatno: String? = nil
    var pendingLabel: String? = nil
    var didLinkDiscogs = false
    
    @IBOutlet weak var Button: UIButton!
    @IBOutlet weak var Button1: UIButton!
    @IBOutlet weak var Button2: UIButton!
    @IBOutlet weak var Button3: UIButton!
    @IBOutlet weak var Button4: UIButton!
    
    let saveButton = UIButton(type:.system)
    let photoButton = UIButton(type:.system)
    let barcodeButton = UIButton(type:.system)
    let ocrButton = UIButton(type:.system)
    let catnoButton = UIButton(type:.system)
    let discogsLinkButton = UIButton(type: .system)
    let shazamButton = UIButton(type: .system)
    
    let textField = UITextField()
    let textField2 = UITextField()
    let formatTextField = UITextField()
    let textField3 = UITextField()
    let textField4 = UITextField()
    let memoTextView = UITextView()
    let albumImage = UIImageView()
    let listSegment = UISegmentedControl(items:["Collection","Wants"])
    let bannerView = UIView()
    
    
    @objc func scanBarcodeBtnTapped() {
        startBarcodeScanning()
    }
    @objc func ocrBtnTapped() {
        guard PremiumManager.shared.isPremiumUser() else {
            showOCRPaywall()
            return
        }
        currentOCRMode = .artistTitle
        startOCRScanning()
    }
    @objc func catNoBtnTapped() {
        guard PremiumManager.shared.isPremiumUser() else {
            showOCRPaywall()
            return
        }
        currentOCRMode = .catNo
        startOCRScanning()
    }
    
    @objc func segmentChanged(_ sender: UISegmentedControl) {
        wantsFlg = sender.selectedSegmentIndex == 1 ? "true" : "false"
    }

    @objc func photoBtnTapped() {
        shouldRunOCR = false
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self
        imagePickerController.mediaTypes = ["public.image"]
        present(imagePickerController,animated: true,completion: nil)
    }

    @objc func btnTapped() {
        var flg = ""
        var errorMassage = ""

        if textField.text!.isEmpty == true {
            flg = "1"
            errorMassage = NSLocalizedString("Artist", comment: "")
        }
        if flg == "" {
            if textField2.text!.isEmpty == true {
                flg = "2"
                errorMassage = NSLocalizedString("Title", comment: "")
            }
        }

        if flg == "" {
            let context = fromAppDelegate.persistentContainer.viewContext
            let recordList: RecordList2

            if mode == .edit {
                recordList = record!
            } else {
                recordList = RecordList2(context: context)
                recordList.id = UUID().uuidString
            }

            recordList.artistName = textField.text!
            recordList.albumTitle = textField2.text!
            recordList.format = formatTextField.text!
            recordList.releaseCountry = textField3.text!
            recordList.releaseDate = textField4.text!
            recordList.memo = memoTextView.text!
            recordList.wantsFlg = wantsFlg

            if let catnoTextField = view.viewWithTag(4001) as? UITextField,
               let text = catnoTextField.text, !text.isEmpty {
                recordList.catno = text
            } else if let catno = pendingCatno, !catno.isEmpty {
                recordList.catno = catno
            }

            if let labelTextField = view.viewWithTag(4002) as? UITextField,
               let text = labelTextField.text, !text.isEmpty {
                recordList.label = text
            } else if let label = pendingLabel, !label.isEmpty {
                recordList.label = label
            }

            if let releaseId = pendingDiscogsReleaseId, didLinkDiscogs {
                recordList.discogsReleaseId = releaseId
                recordList.priceLow = pendingPriceLow
                recordList.priceUpdatedAt = pendingPriceUpdatedAt
            }

            if let resized = resizedPicture {
                recordList.albumImage = resized.jpegData(compressionQuality: 0.7)
            } else if mode == .add {
                recordList.albumImage = nil
            }

            (UIApplication.shared.delegate as! AppDelegate).saveContext()
            if mode != .edit {
                ReviewManager.shared.incrementRecordCount()
            }
            NotificationCenter.default.post(name: .recordUpdated, object: nil)
            let toastMessage = mode == .edit
                ? NSLocalizedString("update_button", comment: "") + "!"
                : NSLocalizedString("save_button", comment: "") + "!"
            self.showToast(message: toastMessage) {
                self.navigationController?.popViewController(animated: true)
                NotificationCenter.default.post(
                    name: .recordUpdated,
                    object: nil,
                    userInfo: [
                        "artistName": recordList.artistName ?? "",
                        "albumTitle": recordList.albumTitle ?? ""
                    ]
                )
                // スクロールアニメーション分待ってからpop
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.navigationController?.popViewController(animated: true)
                }
            }
        } else {
            let alui = UIAlertController(
                title: NSLocalizedString("required_title", comment: ""),
                message: errorMassage,
                preferredStyle: UIAlertController.Style.alert
            )
            let btn = UIAlertAction(
                title: NSLocalizedString("continue_button", comment: ""),
                style: UIAlertAction.Style.default,
                handler: nil
            )
            alui.addAction(btn)
            present(alui, animated: true, completion: nil)
        }
    }
    
    func showOCRPaywall() {
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
    
    func startBarcodeScanning() {
        forcePortraitOrientation()
        (UIApplication.shared.delegate as? AppDelegate)?.orientationLock = .portrait
        
        captureSession = AVCaptureSession()
        
        guard let session = captureSession else {
            showAlert(NSLocalizedString("notice_title", comment: ""))
            return
        }
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            showAlert(NSLocalizedString("camera_unavailable", comment: ""))
            return
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            showAlert(NSLocalizedString("camera_unavailable", comment: ""))
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            showAlert(NSLocalizedString("camera_unavailable", comment: ""))
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean13, .ean8]
        } else {
            showAlert(NSLocalizedString("camera_unavailable", comment: ""))
            return
        }
        
        let cameraView = UIView()
        cameraView.backgroundColor = .black
        cameraView.tag = 999
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraView)
        
        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(equalTo: view.topAnchor),
            cameraView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspectFill
        cameraView.layer.addSublayer(previewLayer!)
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("cancel_button", comment: ""),
            style: .plain,
            target: self,
            action: #selector(cancelBarcodeScanning)
        )
    }
    // 戻るボタンを復元するヘルパー
    private func restoreBackButton() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("back_button", comment: ""),
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
    }
    
    @objc func cancelBarcodeScanning() {
        (UIApplication.shared.delegate as? AppDelegate)?.orientationLock = .all
        captureSession?.stopRunning()
        previewLayer?.removeFromSuperlayer()
        view.viewWithTag(999)?.removeFromSuperview()
        restoreBackButton()
    }

    func forcePortraitOrientation() {
        if #available(iOS 16.0, *) {
            let windowScene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first
            windowScene?.requestGeometryUpdate(
                .iOS(interfaceOrientations: .portrait)
            )
            setNeedsUpdateOfSupportedInterfaceOrientations()
        } else {
            UIDevice.current.setValue(
                UIInterfaceOrientation.portrait.rawValue,
                forKey: "orientation"
            )
            UINavigationController.attemptRotationToDeviceOrientation()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        (UIApplication.shared.delegate as? AppDelegate)?.orientationLock = .all
        
        if let session = captureSession {
            session.stopRunning()
        }
        
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let barcode = metadataObject.stringValue {
            foundBarcode(code: barcode)
        }
        
        previewLayer?.removeFromSuperlayer()
        view.viewWithTag(999)?.removeFromSuperview()
        restoreBackButton()
    }
    
    func foundBarcode(code: String) {
        print("Barcode scanned successfully: \(code)")
        fetchDiscogsInfo(barcode: code)
    }
    
    func showAlert(_ message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: NSLocalizedString("notice_title", comment: ""),
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("ok_button", comment: ""), style: .default))
            self.present(alert, animated: true)
        }
    }

    func fetchDiscogsInfo(barcode: String) {
        var userAgent = "RecoColle2/1.0 (marume3591@icloud.com)"
        let key = "VTvQRnPmaaybKvVDYsej"
        let secret = "VKFSjBMuqcgsAdmMvUzfoeLlsQbGYqdE"
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            userAgent = "RecoColle2/\(version) (marume3591@icloud.com)"
        }

        let searchURL = URL(string: "https://api.discogs.com/database/search?barcode=\(barcode)&key=\(key)&secret=\(secret)")!
        var request = URLRequest(url: searchURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Search API error: \(String(describing: error))")
                DispatchQueue.main.async { self.showAlert(NSLocalizedString("no_info_found", comment: "")) }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let first = results.first {

                    let coverURL = first["cover_image"] as? String ?? ""
                    let formats = (first["format"] as? [String])?.joined(separator: ", ") ?? ""
                    let country = first["country"] as? String ?? ""

                    let title = first["title"] as? String ?? ""
                    let separators: [Character] = ["–", "-"]
                    let parts = title.split(whereSeparator: { separators.contains($0) })
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                    let artistName = parts.count > 0 ? parts[0] : ""
                    let albumTitle = parts.count > 1 ? parts[1] : parts[0]

                    guard let releaseID = first["id"] as? Int else {
                        DispatchQueue.main.async { self.showAlert(NSLocalizedString("no_info_found", comment: "")) }
                        return
                    }

                    let detailURL = URL(string: "https://api.discogs.com/releases/\(releaseID)?key=\(key)&secret=\(secret)")!
                    var detailRequest = URLRequest(url: detailURL)
                    detailRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")

                    URLSession.shared.dataTask(with: detailRequest) { data, _, error in
                        guard let data = data, error == nil else { return }

                        var releaseYearString = ""
                        var catnoString = ""
                        var labelString = ""

                        if let releaseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let releasedYear = releaseJSON["year"] as? Int {
                                releaseYearString = "\(releasedYear)"
                            } else if let releasedString = releaseJSON["released"] as? String, !releasedString.isEmpty {
                                releaseYearString = String(releasedString.prefix(4))
                            }

                            if let labels = releaseJSON["labels"] as? [[String: Any]],
                               let firstLabel = labels.first {
                                if let catno = firstLabel["catno"] as? String, !catno.isEmpty {
                                    catnoString = catno
                                }
                                if let name = firstLabel["name"] as? String, !name.isEmpty {
                                    labelString = name
                                }
                            }
                        }

                        DispatchQueue.main.async {
                            self.textField.text = artistName
                            self.textField2.text = albumTitle
                            self.textField3.text = country
                            self.textField4.text = releaseYearString
                            self.formatTextField.text = formats
                            self.pendingCatno = catnoString.isEmpty ? nil : catnoString
                            self.pendingLabel = labelString.isEmpty ? nil : labelString

                            if let catnoTextField = self.view.viewWithTag(4001) as? UITextField {
                                catnoTextField.text = self.pendingCatno
                            }
                            if let labelTextField = self.view.viewWithTag(4002) as? UITextField {
                                labelTextField.text = self.pendingLabel
                            }

                            self.pendingDiscogsReleaseId = String(releaseID)
                            self.didLinkDiscogs = true

                            Task {
                                let stats = try? await DiscogsService().fetchPriceStats(releaseId: String(releaseID))
                                await MainActor.run {
                                    self.pendingPriceLow = stats?.lowest ?? 0
                                    self.pendingPriceUpdatedAt = stats?.lowest != nil ? Date() : nil
                                }
                            }

                            if let url = URL(string: coverURL) {
                                URLSession.shared.dataTask(with: url) { data, _, _ in
                                    if let data = data, let image = UIImage(data: data) {
                                        DispatchQueue.main.async {
                                            let resized = image.resize(targetSize: CGSize(width: 400, height: 400))
                                            self.albumImage.image = resized
                                            self.resizedPicture = resized
                                        }
                                    }
                                }.resume()
                            }
                        }
                    }.resume()

                } else {
                    DispatchQueue.main.async { self.showAlert(NSLocalizedString("no_info_found", comment: "")) }
                }
            } catch {
                print("JSON parse error: \(error)")
                DispatchQueue.main.async { self.showAlert(NSLocalizedString("no_info_found", comment: "")) }
            }
        }.resume()
    }

    func fetchDiscogsInfoByOCR(artist: String?, title: String?, retryCount: Int = 0) {
        guard let artist = artist, let title = title else {
            showAlert(NSLocalizedString("ocr_incomplete", comment: ""))
            return
        }
        guard retryCount < 3 else {
            DispatchQueue.main.async {
                self.showAlert(NSLocalizedString("discogs_busy", comment: ""))
            }
            return
        }

        let userAgent = "RecoColle2/1.0 (marume3591@icloud.com)"
        let key = "VTvQRnPmaaybKvVDYsej"
        let secret = "VKFSjBMuqcgsAdmMvUzfoeLlsQbGYqdE"

        let query = "\(artist) \(title)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.discogs.com/database/search?q=\(query)&type=release&per_page=50&page=1&key=\(key)&secret=\(secret)"

        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { self.showAlert(NSLocalizedString("discogs_search_failed", comment: "")) }
                return
            }
            if let jsonString = String(data: data, encoding: .utf8),
               jsonString.contains("You are making requests too quickly") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.fetchDiscogsInfoByOCR(artist: artist, title: title, retryCount: retryCount + 1)
                }
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]] {

                    let totalPages = (json["pagination"] as? [String: Any])?["pages"] as? Int ?? 1

                    let group = DispatchGroup()
                    var resultsWithYear: [[String: Any]] = []

                    for var item in results {
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
                                    item["year"] = ""
                                }
                                resultsWithYear.append(item)
                            }.resume()
                        } else {
                            resultsWithYear.append(item)
                        }
                    }

                    group.notify(queue: .main) {
                        if resultsWithYear.isEmpty {
                            self.showAlert(NSLocalizedString("no_matching_releases", comment: ""))
                        } else {
                            let q = DiscogsSearchQuery.text("\(artist) \(title)")
                            self.showOCRResultList(resultsWithYear,
                                                   title: NSLocalizedString("link_discogs", comment: ""),
                                                   query: q,
                                                   totalPages: totalPages)
                        }
                    }

                } else {
                    DispatchQueue.main.async { self.showAlert(NSLocalizedString("no_discogs_results", comment: "")) }
                }
            } catch {
                DispatchQueue.main.async { self.showAlert(NSLocalizedString("no_discogs_results", comment: "")) }
            }
        }.resume()
    }

    // ★ showOCRResultList：query と totalPages を受け取りページネーション対応
    func showOCRResultList(_ ocrResults: [[String: Any]],
                           title: String = "OCR Results",
                           query: DiscogsSearchQuery? = nil,
                           totalPages: Int = 1) {
        let vc = OCRResultViewController()
        vc.results = ocrResults
        vc.title = title
        vc.searchQuery = query
        vc.setInitialPagination(currentPage: 1, totalPages: totalPages)
        vc.onSelect = { [weak self] selected in
            self?.applyDiscogsResult(selected)
        }
        navigationController?.pushViewController(vc, animated: true)
        self.ocrResults = []
    }

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

        if let url = URL(string: coverURL) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data, let img = UIImage(data: data) else { return }
                let resized = img.resize(targetSize: CGSize(width: 400, height: 400))
                DispatchQueue.main.async {
                    self.albumImage.image = resized
                    self.resizedPicture = resized
                }
            }.resume()
        }

        if let catno = first["catno"] as? String, !catno.isEmpty {
            self.pendingCatno = catno
        } else if let catnos = first["catno"] as? [String], let firstCatno = catnos.first {
            self.pendingCatno = firstCatno
        }

        if let labelArray = first["label"] as? [String] {
            self.pendingLabel = labelArray.first
        } else if let labelStr = first["label"] as? String {
            self.pendingLabel = labelStr
        }

        DispatchQueue.main.async {
            if let catnoTextField = self.view.viewWithTag(4001) as? UITextField {
                catnoTextField.text = self.pendingCatno
            }
            if let labelTextField = self.view.viewWithTag(4002) as? UITextField {
                labelTextField.text = self.pendingLabel
            }
        }

        let releaseID = first["id"] as? Int
        let masterID  = first["master_id"] as? Int
        fetchReleaseYear(releaseID: releaseID, masterID: masterID) { year in
            DispatchQueue.main.async {
                self.textField4.text = year ?? ""
            }
        }

        if let releaseId = first["id"] as? Int {
            self.pendingDiscogsReleaseId = String(releaseId)
            self.didLinkDiscogs = true
            Task {
                let stats = try? await DiscogsService().fetchPriceStats(releaseId: String(releaseId))
                self.pendingPriceLow = stats?.lowest ?? 0
                self.pendingPriceUpdatedAt = stats?.lowest != nil ? Date() : nil
            }
        }

        if let updatePriceButton = view.viewWithTag(3001) as? UIButton {
            updatePriceButton.isEnabled = true
            updatePriceButton.alpha = 1.0
        }
    }

    func fetchCoverArt(releaseID: String) {
        guard let coverArtURL = URL(string: "https://coverartarchive.org/release/\(releaseID)/front") else { return }
        URLSession.shared.dataTask(with: coverArtURL) { data, response, error in
            if let error = error { print("Cover art fetch error: \(error)"); return }
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.albumImage.image = image
                    self.albumImage.layer.borderColor = UIColor.blue.cgColor
                    self.albumImage.layer.borderWidth = 1
                }
            }
        }.resume()
    }
    
    //var image: UIImage!
    var resizedPicture: UIImage?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = false
        
        Task {
            await PremiumManager.shared.refresh()
            let isPremium = PremiumManager.shared.isPremium
            bannerView.isHidden = isPremium
            bannerHeightConstraint.constant = isPremium ? 0 : 50
            if !isPremium { setupAd() }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if launchMode == .shazam {
            try? AVAudioSession.sharedInstance().setCategory(.record)
            try? AVAudioSession.sharedInstance().setActive(true)
        }
        
        view.backgroundColor = .systemGroupedBackground
        setupUI()
        setupAction()
        if launchMode != .normal {
            view.subviews.forEach { $0.alpha = 0 }
            navigationController?.navigationBar.alpha = 0
        }

        if mode == .add {
            title = NSLocalizedString("add_item_title", comment: "")
        } else {
            title = NSLocalizedString("edit_item_title", comment: "")
        }
        
        if mode == .edit {
            loadRecord()
        }
        
        if mode == .add {
            albumImage.image = UIImage(systemName: "photo")
            albumImage.tintColor = .systemGray3
        }
        if mode == .add || mode == .edit {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: NSLocalizedString("back_button", comment: ""),
                style: .plain,
                target: self,
                action: #selector(backButtonTapped)
            )
        }

        textField.delegate = self
        textField2.delegate = self
        textField3.delegate = self
        textField4.delegate = self
        formatTextField.delegate = self
        memoTextView.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(showkeyboard), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hidekeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(premiumUpdated), name: .premiumStatusChanged, object: nil)
        
        if let scrollView = view.subviews.first(where: { $0 is UIScrollView }) {
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            tap.cancelsTouchesInView = false
            scrollView.addGestureRecognizer(tap)
        }
        
        albumImage.layer.borderColor = UIColor.systemGray2.cgColor
        albumImage.layer.borderWidth = 1
        albumImage.clipsToBounds = true
        
        listSegment.selectedSegmentIndex = wantsFlg == "true" ? 1 : 0
        listSegment.backgroundColor = .secondarySystemBackground
        listSegment.selectedSegmentTintColor = .systemBlue
        listSegment.setTitleTextAttributes([.foregroundColor: UIColor.secondaryLabel], for: .normal)
        listSegment.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        listSegment.layer.cornerRadius = 8
        listSegment.clipsToBounds = true
        
        albumImage.isUserInteractionEnabled = true
        let imageTap = UITapGestureRecognizer(target: self, action: #selector(selectImage))
        albumImage.addGestureRecognizer(imageTap)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let cameraView = view.viewWithTag(999) {
            previewLayer?.frame = cameraView.bounds
        }
    }

    @objc func backButtonTapped() {
        if audioEngine?.isRunning == true {
            stopShazamRecognition()
            hideShazamOverlay()
        }
        if hasUnsavedChanges() {
            let alert = UIAlertController(
                title: NSLocalizedString("unsaved_changes_title", comment: ""),
                message: NSLocalizedString("unsaved_changes_message", comment: ""),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("save_go_back", comment: ""), style: .default) { _ in
                self.btnTapped()
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("discard_go_back", comment: ""), style: .destructive) { _ in
                self.navigationController?.popViewController(animated: true)
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("keep_editing", comment: ""), style: .cancel))
            present(alert, animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if launchMode != .normal {
            UIView.animate(withDuration: 0.2) {
                self.view.subviews.forEach { $0.alpha = 1 }
                self.navigationController?.navigationBar.alpha = 1
            }
        }
        switch launchMode {

        case .barcode:
            launchMode = .normal
            startBarcodeScanning()

        case .ocr:
            launchMode = .normal
            currentOCRMode = .artistTitle
            startOCRScanning()

        case .catno:
            launchMode = .normal
            currentOCRMode = .catNo
            startOCRScanning()

        case .shazam:
            launchMode = .normal
            startShazamRecognition()

        case .normal:
            break
        }
    }
    
    func loadRecord() {
        guard let record = record else { return }

        textField.text = record.artistName
        textField2.text = record.albumTitle
        formatTextField.text = record.format
        textField3.text = record.releaseCountry
        textField4.text = record.releaseDate
        memoTextView.text = record.memo

        if let catnoTextField = view.viewWithTag(4001) as? UITextField { catnoTextField.text = record.catno }
        if let labelTextField = view.viewWithTag(4002) as? UITextField { labelTextField.text = record.label }

        if let data = record.albumImage {
            albumImage.image = UIImage(data: data)
        } else {
            albumImage.image = UIImage(named: "noimage")
        }

        pendingDiscogsReleaseId = record.discogsReleaseId
        pendingCatno = record.catno
        pendingLabel = record.label
        pendingPriceLow = record.priceLow
        pendingPriceUpdatedAt = record.priceUpdatedAt

        initialArtist           = record.artistName ?? ""
        initialTitle            = record.albumTitle ?? ""
        initialFormat           = record.format ?? ""
        initialCountry          = record.releaseCountry ?? ""
        initialYear             = record.releaseDate ?? ""
        initialMemo             = record.memo ?? ""
        initialWantsFlg         = record.wantsFlg ?? "false"
        wantsFlg = record.wantsFlg ?? "false"
        initialImageData        = record.albumImage
        initialDiscogsReleaseId = record.discogsReleaseId
        initialPriceLow         = record.priceLow
        initialPriceUpdatedAt   = record.priceUpdatedAt
        initialCatno            = record.catno
        initialLabel            = record.label

        let hasDiscogs = !(record.discogsReleaseId ?? "").isEmpty
        if let updatePriceButton = view.viewWithTag(3001) as? UIButton {
            updatePriceButton.isEnabled = hasDiscogs
            updatePriceButton.alpha = hasDiscogs ? 1.0 : 0.4
        }
    }

    private func hasUnsavedChanges() -> Bool {
        print("---hasUnsavedChanges---")

        let currentCatno = (view.viewWithTag(4001) as? UITextField)?.text ?? ""
        let currentLabel = (view.viewWithTag(4002) as? UITextField)?.text ?? ""

        if mode == .edit {

            if (textField.text ?? "")       != initialArtist           { return true }
            if (textField2.text ?? "")      != initialTitle            { return true }
            if (formatTextField.text ?? "") != initialFormat           { return true }
            if (textField3.text ?? "")      != initialCountry          { return true }
            if (textField4.text ?? "")      != initialYear             { return true }
            if (memoTextView.text ?? "")    != initialMemo             { return true }

            if wantsFlg                     != initialWantsFlg         { return true }

            if resizedPicture               != nil                     { return true }

            if pendingDiscogsReleaseId      != initialDiscogsReleaseId { return true }
            if pendingPriceLow              != initialPriceLow         { return true }
            if pendingPriceUpdatedAt        != initialPriceUpdatedAt   { return true }

            if currentCatno                 != (initialCatno ?? "")    { return true }
            if currentLabel                 != (initialLabel ?? "")    { return true }

        } else {
            print("artist:", textField.text ?? "nil")
            print("title:", textField2.text ?? "nil")
            print("format:", formatTextField.text ?? "nil")
            print("year:", textField4.text ?? "nil")
            let artist = (textField.text ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let title = (textField2.text ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let format = (formatTextField.text ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let country = (textField3.text ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let year = (textField4.text ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let memo = (memoTextView.text ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !artist.isEmpty { return true }
            if !title.isEmpty { return true }
            if !format.isEmpty { return true }
            if !country.isEmpty { return true }
            if !year.isEmpty { return true }

            if !memo.isEmpty &&
                memo != NSLocalizedString("memo_placeholder", comment: "") {
                return true
            }

            if resizedPicture != nil { return true }

            if !currentCatno
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty {
                return true
            }

            if !currentLabel
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty {
                return true
            }
        }

        return false
    }

    func setupUI() {
        let scrollView = UIScrollView()
        let contentView = UIView()
        
        view.addSubview(scrollView)
        view.addSubview(bannerView)
        scrollView.addSubview(contentView)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        
        bannerHeightConstraint = bannerView.heightAnchor.constraint(equalToConstant: 50)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bannerView.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bannerHeightConstraint,
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -40),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 500),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        
        let imageContainer = UIView()
        albumImage.translatesAutoresizingMaskIntoConstraints = false
        albumImage.contentMode = .scaleAspectFit
        imageContainer.addSubview(albumImage)
        NSLayoutConstraint.activate([
            albumImage.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
            albumImage.centerYAnchor.constraint(equalTo: imageContainer.centerYAnchor),
            albumImage.heightAnchor.constraint(equalToConstant: 120),
            albumImage.widthAnchor.constraint(equalToConstant: 120),
            imageContainer.heightAnchor.constraint(equalToConstant: 120)
        ])
        stack.addArrangedSubview(imageContainer)
        
        let imageLabel = UILabel()
        imageLabel.text = mode == .add
            ? NSLocalizedString("tap_add_cover", comment: "")
            : NSLocalizedString("tap_cover_options", comment: "")
        imageLabel.font = UIFont.systemFont(ofSize: 12)
        imageLabel.textColor = .secondaryLabel
        imageLabel.textAlignment = .center
        stack.addArrangedSubview(imageLabel)
        
        styleTextField(textField)
        styleTextField(textField2)
        styleTextField(formatTextField)
        styleTextField(textField3)
        styleTextField(textField4)
        
        let countryYearRow = UIStackView(arrangedSubviews: [
            labeledField(title: NSLocalizedString("Country", comment: ""), field: textField3),
            labeledField(title: NSLocalizedString("Year", comment: ""), field: textField4)
        ])
        countryYearRow.axis = .horizontal
        countryYearRow.spacing = 10
        countryYearRow.distribution = .fillEqually
        
        memoTextView.heightAnchor.constraint(equalToConstant: 60).isActive = true
        memoTextView.layer.borderWidth = 1
        memoTextView.layer.borderColor = UIColor.systemGray2.cgColor
        memoTextView.layer.cornerRadius = 6
        
        stack.addArrangedSubview(labeledField(title: NSLocalizedString("Artist", comment: ""), field: textField))
        stack.addArrangedSubview(labeledField(title: NSLocalizedString("Title", comment: ""), field: textField2))
        stack.addArrangedSubview(labeledField(title: NSLocalizedString("Format", comment: ""), field: formatTextField))
        stack.addArrangedSubview(countryYearRow)

        let catnoTextField = UITextField()
        let labelTextField = UITextField()
        styleTextField(catnoTextField)
        styleTextField(labelTextField)
        catnoTextField.tag = 4001
        labelTextField.tag = 4002
        catnoTextField.delegate = self
        labelTextField.delegate = self

        let catnoLabelRow = UIStackView(arrangedSubviews: [
            labeledField(title: NSLocalizedString("Cat No", comment: ""), field: catnoTextField),
            labeledField(title: NSLocalizedString("Label", comment: ""), field: labelTextField)
        ])
        catnoLabelRow.axis = .horizontal
        catnoLabelRow.spacing = 10
        catnoLabelRow.distribution = .fillEqually
        stack.addArrangedSubview(catnoLabelRow)
        stack.addArrangedSubview(labeledTextView(title: NSLocalizedString("Memo", comment: ""), view: memoTextView))
        
        barcodeButton.setTitle(" Barcode", for: .normal)
        catnoButton.setTitle(" Cat No", for: .normal)
        ocrButton.setTitle(" Scan Title", for: .normal)
        shazamButton.setTitle(" Shazam", for: .normal)

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        barcodeButton.setImage(UIImage(systemName: "barcode.viewfinder", withConfiguration: symbolConfig), for: .normal)
        catnoButton.setImage(UIImage(systemName: "number.square", withConfiguration: symbolConfig), for: .normal)
        ocrButton.setImage(UIImage(systemName: "text.viewfinder", withConfiguration: symbolConfig), for: .normal)
        shazamButton.setImage(UIImage(systemName: "music.note", withConfiguration: symbolConfig), for: .normal)
        
        let buttons = [barcodeButton, catnoButton, ocrButton, shazamButton]
        for b in buttons {
            b.layer.cornerRadius = 8
            b.layer.borderWidth = 1
            b.layer.borderColor = UIColor.separator.cgColor
            b.heightAnchor.constraint(equalToConstant: 40).isActive = true
        }

        let row1 = UIStackView(arrangedSubviews: [barcodeButton, catnoButton])
        row1.axis = .horizontal; row1.spacing = 10; row1.distribution = .fillEqually

        let row2 = UIStackView(arrangedSubviews: [ocrButton, shazamButton])
        row2.axis = .horizontal; row2.spacing = 10; row2.distribution = .fillEqually

        let buttonStack = UIStackView(arrangedSubviews: [row1, row2])
        buttonStack.axis = .vertical; buttonStack.spacing = 10
        stack.addArrangedSubview(buttonStack)
        stack.addArrangedSubview(listSegment)
        
        if mode == .edit {
            saveButton.setTitle(NSLocalizedString("update_button", comment: ""), for: .normal)
        } else {
            saveButton.setTitle(NSLocalizedString("save_button", comment: ""), for: .normal)
        }
        saveButton.backgroundColor = .systemBlue
        saveButton.tintColor = .white
        saveButton.layer.cornerRadius = 10
        saveButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        stack.addArrangedSubview(saveButton)
        
        discogsLinkButton.setTitle(NSLocalizedString("link_discogs", comment: ""), for: .normal)
        discogsLinkButton.setImage(UIImage(systemName: "link"), for: .normal)
        discogsLinkButton.layer.cornerRadius = 8
        discogsLinkButton.layer.borderWidth = 1
        discogsLinkButton.layer.borderColor = UIColor.separator.cgColor
        discogsLinkButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        discogsLinkButton.addTarget(self, action: #selector(discogsLinkButtonTapped), for: .touchUpInside)
        
        let updatePriceButton = UIButton(type: .system)
        updatePriceButton.setTitle("Update Price", for: .normal)
        updatePriceButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        updatePriceButton.layer.cornerRadius = 8
        updatePriceButton.layer.borderWidth = 1
        updatePriceButton.layer.borderColor = UIColor.separator.cgColor
        updatePriceButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        updatePriceButton.addTarget(self, action: #selector(updatePriceButtonTapped), for: .touchUpInside)
        updatePriceButton.tag = 3001

        let discogsRow = UIStackView(arrangedSubviews: [discogsLinkButton, updatePriceButton])
        discogsRow.axis = .horizontal; discogsRow.spacing = 10; discogsRow.distribution = .fillEqually
        discogsRow.isHidden = mode != .edit
        stack.addArrangedSubview(discogsRow)
    }

    @objc func updatePriceButtonTapped() {
        guard let record = record else { return }
        guard let releaseId = record.discogsReleaseId, !releaseId.isEmpty else {
            showAlert(NSLocalizedString("please_link_discogs", comment: ""))
            return
        }
        let previousPrice = record.priceLow
        Task {
            let stats = try? await DiscogsService().fetchPriceStats(releaseId: releaseId)
            await MainActor.run {
                if let lowest = stats?.lowest {
                    record.priceLow = lowest
                    record.priceUpdatedAt = Date()
                    (UIApplication.shared.delegate as! AppDelegate).saveContext()
                    let message: String
                    if lowest > previousPrice {
                        message = "Price went up: \(self.formatValue(lowest))"
                    } else if lowest < previousPrice {
                        message = "Price went down: \(self.formatValue(lowest))"
                    } else {
                        message = "Price unchanged: \(self.formatValue(lowest))"
                    }
                    self.showToast(message: message, duration: 2.0) {
                        self.navigationController?.popViewController(animated: true)
                        NotificationCenter.default.post(name: .recordUpdated, object: nil)
                    }
                } else {
                    self.showToast(message: "Price data could not be retrieved")
                }
            }
        }
    }

    func formatValue(_ value: Double) -> String {
        let targetCurrency = Locale.current.currency?.identifier ?? "USD"
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

    @objc func discogsLinkButtonTapped() {
        let artist = textField.text ?? ""
        let title = textField2.text ?? ""
        guard !artist.isEmpty, !title.isEmpty else {
            showAlert(NSLocalizedString("artist_title_required", comment: ""))
            return
        }
        let memo = memoTextView.text ?? ""
        let catNo = extractCatNo(from: memo)
        discogsLinkButton.isEnabled = false
        showLoadingOverlay()
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                self.discogsLinkButton.isEnabled = true
                self.hideLoadingOverlay()
                if let catNo = catNo {
                    self.fetchDiscogsInfoByCatNo(catNo)
                } else {
                    self.fetchDiscogsInfoByOCR(artist: artist, title: title, retryCount: 0)
                }
            }
        }
    }

    func extractCatNo(from memo: String) -> String? {
        let lines = memo.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.uppercased().hasPrefix("CATNO:") {
                let value = trimmed.dropFirst("CATNO:".count).trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }
    
    func setupAction() {
        photoButton.addTarget(self, action: #selector(photoBtnTapped), for: .touchUpInside)
        barcodeButton.addTarget(self, action: #selector(scanBarcodeBtnTapped), for: .touchUpInside)
        ocrButton.addTarget(self, action: #selector(ocrBtnTapped), for: .touchUpInside)
        catnoButton.addTarget(self, action: #selector(catNoBtnTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(btnTapped), for: .touchUpInside)
        listSegment.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        shazamButton.addTarget(self, action: #selector(shazamBtnTapped), for: .touchUpInside)
    }

    @objc func shazamBtnTapped() {
        guard PremiumManager.shared.isPremiumUser() else { showOCRPaywall(); return }
        startShazamRecognition()
    }
    
    func startShazamRecognition() {
        shazamSession = SHSession()
        shazamSession?.delegate = self
        audioEngine = AVAudioEngine()
        do {
            if AVAudioSession.sharedInstance().category != .record {
                try AVAudioSession.sharedInstance().setCategory(.record)
                try AVAudioSession.sharedInstance().setActive(true)
            }
            let inputNode = audioEngine!.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 8192, format: format) { buffer, time in
                self.shazamSession?.matchStreamingBuffer(buffer, at: time)
            }
            try audioEngine!.start()
            showShazamOverlay()
        } catch {
            showAlert(NSLocalizedString("microphone_error", comment: ""))
        }
    }

    func stopShazamRecognition() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        shazamSession = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    @objc func premiumUpdated() {
        bannerView.isHidden = true
        bannerHeightConstraint.constant = 0
    }
    
    private var isAdLoaded = false
    
    private func setupAd() {
        guard !isAdLoaded else { return }
        isAdLoaded = true
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { print("AVAudioSession設定失敗:", error) }
        
        let IMOBILE_BANNER_PID = "81561"
        let IMOBILE_BANNER_MID = "567770"
        let IMOBILE_BANNER_SID = "1847196"
        ImobileSdkAds.setTestMode(fromAppDelegate.globalTestMode)
        ImobileSdkAds.register(withPublisherID: IMOBILE_BANNER_PID, mediaID: IMOBILE_BANNER_MID, spotID: IMOBILE_BANNER_SID)
        DispatchQueue.global().async { ImobileSdkAds.start(bySpotID: IMOBILE_BANNER_SID) }
        
        let adView = UIView()
        adView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.addSubview(adView)
        NSLayoutConstraint.activate([
            adView.centerXAnchor.constraint(equalTo: bannerView.centerXAnchor),
            adView.centerYAnchor.constraint(equalTo: bannerView.centerYAnchor),
            adView.widthAnchor.constraint(equalToConstant: 320),
            adView.heightAnchor.constraint(equalToConstant: 50),
        ])
        ImobileSdkAds.showBySpotID(forAdMobMediation: IMOBILE_BANNER_SID, view: adView)
    }
    
    @objc func dismissKeyboard() { self.view.endEditing(true) }

    func numberOfComponents(in pickerView: UIPickerView) -> Int { return 1 }
    
    @objc func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        let resizedForOCR = image.resize(targetSize: CGSize(width: 1024, height: 1024))
        self.ocrImage = resizedForOCR
        if !shouldRunOCR {
            let resized = image.resize(targetSize: CGSize(width: 400, height: 400))
            self.albumImage.image = resized
            self.resizedPicture = resized
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
                            self.showAlert(NSLocalizedString("catno_not_recognized", comment: ""))
                        }
                    }
                    self.ocrImage = nil
                }
            }
        }
    }

    @objc func selectImage() {
        let alert = UIAlertController(
            title: NSLocalizedString("cover_image_title", comment: ""),
            message: nil,
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("take_photo", comment: ""), style: .default) { _ in self.openCamera() })
        alert.addAction(UIAlertAction(title: NSLocalizedString("change_image", comment: ""), style: .default) { _ in self.openPhotoLibrary() })
        if mode == .edit {
            alert.addAction(UIAlertAction(title: NSLocalizedString("search_ebay", comment: ""), style: .default) { _ in
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "EbayViewController") as! EbayViewController
                vc.recordList = self.record
                self.navigationController?.pushViewController(vc, animated: true)
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("search_discogs", comment: ""), style: .default) { _ in
                let artist = self.textField.text ?? ""
                let title = self.textField2.text ?? ""
                let query = "\(artist) \(title)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let urlString = "https://www.discogs.com/search/?q=\(query)&type=release"
                let webView = self.storyboard?.instantiateViewController(withIdentifier: "MyWebView") as! WebViewController
                webView.url = urlString
                webView.modalPresentationStyle = .fullScreen
                self.present(webView, animated: true, completion: nil)
            })
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel_button", comment: ""), style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = albumImage
            popover.sourceRect = albumImage.bounds
        }
        present(alert, animated: true)
    }
    
    func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showAlert(NSLocalizedString("camera_unavailable", comment: ""))
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = self
        picker.allowsEditing = false
        present(picker, animated: true)
    }
    
    func openPhotoLibrary() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.allowsEditing = false
        present(picker, animated: true)
    }

    // ★ fetchDiscogsInfoByOCRTexts：pagination 対応
    func fetchDiscogsInfoByOCRTexts(_ texts: [String]) {
        let key = "VTvQRnPmaaybKvVDYsej"
        let secret = "VKFSjBMuqcgsAdmMvUzfoeLlsQbGYqdE"
        let userAgent = "RecoColle2/1.0"
        let queryString = texts.joined(separator: " ")
        let query = queryString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.discogs.com/database/search?q=\(query)&type=release&per_page=50&page=1&key=\(key)&secret=\(secret)"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]], !results.isEmpty else {
                DispatchQueue.main.async { self.showAlert(NSLocalizedString("no_ocr_results", comment: "")) }
                return
            }
            let totalPages = (json["pagination"] as? [String: Any])?["pages"] as? Int ?? 1
            let q = DiscogsSearchQuery.text(queryString)
            DispatchQueue.main.async {
                self.showOCRResultList(results, query: q, totalPages: totalPages)
            }
        }.resume()
    }

    // ★ fetchDiscogsInfoByCatNo：pagination 対応
    func fetchDiscogsInfoByCatNo(_ catNo: String) {
        let key = "VTvQRnPmaaybKvVDYsej"
        let secret = "VKFSjBMuqcgsAdmMvUzfoeLlsQbGYqdE"
        let encoded = catNo.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.discogs.com/database/search?catno=\(encoded)&type=release&per_page=50&page=1&key=\(key)&secret=\(secret)"
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]], !results.isEmpty else {
                self.showAlert(NSLocalizedString("no_catno_results", comment: ""))
                return
            }
            let totalPages = (json["pagination"] as? [String: Any])?["pages"] as? Int ?? 1
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
                        if let year = releaseJSON["year"] as? Int { item["year"] = year }
                        else if let released = releaseJSON["released"] as? String, !released.isEmpty { item["year"] = Int(released.prefix(4)) }
                        else { item["year"] = "" }
                        resultsWithYear.append(item)
                    }.resume()
                } else {
                    resultsWithYear.append(item)
                }
            }
            group.notify(queue: .main) {
                let q = DiscogsSearchQuery.catno(catNo)
                self.showOCRResultList(resultsWithYear, query: q, totalPages: totalPages)
            }
        }.resume()
    }
    
    @objc func showkeyboard(notification: Notification) {
        guard let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let activeField = activeField else { return }
        let fieldMaxY = activeField.convert(activeField.bounds, to: self.view).maxY
        let distance = fieldMaxY - keyboardFrame.minY + 20
        if distance > 0 {
            UIView.animate(withDuration: 0.3) { self.view.transform = CGAffineTransform(translationX: 0, y: -distance) }
        }
    }

    @objc func hidekeyboard() {
        UIView.animate(withDuration: 0.3) { self.view.transform = .identity }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { self.view.endEditing(true) }
    
    func fetchReleaseYear(releaseID: Int?, masterID: Int?, completion: @escaping (String?) -> Void) {
        let key = "VTvQRnPmaaybKvVDYsej"
        let secret = "VKFSjBMuqcgsAdmMvUzfoeLlsQbGYqdE"
        if let releaseID = releaseID {
            let url = URL(string: "https://api.discogs.com/releases/\(releaseID)?key=\(key)&secret=\(secret)")!
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let year = json["year"] as? Int, year > 0 { completion(String(year)); return }
                    if let released = json["released"] as? String, !released.isEmpty { completion(String(released.prefix(4))); return }
                }
                self.fetchMasterYear(masterID: masterID, completion: completion)
            }.resume()
        } else {
            fetchMasterYear(masterID: masterID, completion: completion)
        }
    }
    
    func fetchMasterYear(masterID: Int?, completion: @escaping (String?) -> Void) {
        guard let masterID = masterID else { completion(nil); return }
        let key = "VTvQRnPmaaybKvVDYsej"
        let secret = "VKFSjBMuqcgsAdmMvUzfoeLlsQbGYqdE"
        let url = URL(string: "https://api.discogs.com/masters/\(masterID)?key=\(key)&secret=\(secret)")!
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let year = json["year"] as? Int, year > 0 { completion(String(year)) }
            else { completion(nil) }
        }.resume()
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) { activeField = textField }
    func textViewDidBeginEditing(_ textView: UITextView) { activeField = textView }
    
    func labeledField(title: String, field: UITextField) -> UIStackView {
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        let stack = UIStackView(arrangedSubviews: [label, field])
        stack.axis = .vertical; stack.spacing = 4
        return stack
    }

    func labeledTextView(title: String, view: UITextView) -> UIStackView {
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray2.cgColor
        view.layer.cornerRadius = 6
        view.heightAnchor.constraint(equalToConstant: 80).isActive = true
        view.inputAccessoryView = makeKeyboardToolbar()
        let stack = UIStackView(arrangedSubviews: [label, view])
        stack.axis = .vertical; stack.spacing = 4
        return stack
    }

    func styleTextField(_ field: UITextField) {
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.systemGray2.cgColor
        field.layer.cornerRadius = 6
        field.backgroundColor = .systemBackground
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 0))
        field.leftViewMode = .always
        field.heightAnchor.constraint(equalToConstant: 34).isActive = true
        field.inputAccessoryView = makeKeyboardToolbar()
    }

    private func makeKeyboardToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(
            title: NSLocalizedString("done_button", comment: "Done"),
            style: .done,
            target: self,
            action: #selector(dismissKeyboard)
        )
        toolbar.items = [space, done]
        return toolbar
    }

    func startOCRScanning() {
        forcePortraitOrientation()
        (UIApplication.shared.delegate as? AppDelegate)?.orientationLock = .portrait
        captureSession = AVCaptureSession()
        guard let session = captureSession else { return }
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: device) else { return }
        configureCameraFocus(device)
        if session.canAddInput(input) { session.addInput(input) }
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "ocrCamera"))
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        
        let cameraView = UIView()
        cameraView.backgroundColor = .black
        cameraView.tag = 999
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraView)
        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(equalTo: view.topAnchor),
            cameraView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspectFill
        cameraView.layer.addSublayer(previewLayer!)
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("cancel_button", comment: ""),
            style: .plain,
            target: self,
            action: #selector(cancelOCRScanning)
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.view.viewWithTag(1001)?.removeFromSuperview()
            self.view.viewWithTag(1002)?.removeFromSuperview()
            self.view.viewWithTag(1003)?.removeFromSuperview()
            self.view.viewWithTag(1005)?.removeFromSuperview()
            self.addScanFrame()
            self.addScanButton()
        }
    }

    func configureCameraFocus(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if #available(iOS 15.4, *) {
                if device.isAutoFocusRangeRestrictionSupported { device.autoFocusRangeRestriction = .near }
            }
            if device.isLowLightBoostSupported { device.automaticallyEnablesLowLightBoostWhenAvailable = true }
            device.unlockForConfiguration()
        } catch { print("フォーカス設定エラー:", error) }
    }

    @objc func cancelOCRScanning() {
        stopOCRCamera()
        restoreBackButton()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !shouldCaptureFrame || isProcessingOCR { return }
        shouldCaptureFrame = false
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        isProcessingOCR = true
        recognizeText(pixelBuffer: pixelBuffer)
    }
    
    func recognizeText(pixelBuffer: CVPixelBuffer) {
        let request = VNRecognizeTextRequest { request, error in
            defer { self.isProcessingOCR = false }
            guard let results = request.results as? [VNRecognizedTextObservation] else { return }
            var texts: [String] = []
            for observation in results {
                guard let candidate = observation.topCandidates(1).first else { continue }
                let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { texts.append(text) }
            }
            DispatchQueue.main.async {
                self.hideScanLoadingOverlay()
                self.isScanning = false
                self.stopOCRCamera()
                if texts.count > 0 {
                    switch self.currentOCRMode {
                    case .artistTitle:
                        self.fetchDiscogsInfoByOCRTexts(texts)
                    case .catNo:
                        if let catNo = texts.first {
                            self.fetchDiscogsInfoByCatNo(catNo)
                        } else {
                            self.showAlert(NSLocalizedString("catno_not_recognized", comment: ""))
                        }
                    }
                } else {
                    self.showAlert(NSLocalizedString("text_not_recognized", comment: ""))
                }
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]
        if self.roiRect != .zero { request.regionOfInterest = self.roiRect }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do { try handler.perform([request]) } catch { print("OCR ERROR:", error) }
    }

    func addScanFrame() {
        let width: CGFloat = view.bounds.width * 0.8
        let height: CGFloat = 120
        let x = (view.bounds.width - width) / 2
        let y = view.bounds.height * 0.35
        
        let frameView = UIView(frame: CGRect(x: x, y: y, width: width, height: height))
        frameView.layer.borderColor = UIColor.systemGreen.cgColor
        frameView.layer.borderWidth = 2
        frameView.layer.cornerRadius = 8
        frameView.backgroundColor = .clear
        frameView.tag = 1001
        
        let overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlayView.tag = 1005
        let path = UIBezierPath(rect: view.bounds)
        let framePath = UIBezierPath(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerRadius: 8)
        path.append(framePath)
        path.usesEvenOddFillRule = true
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        maskLayer.fillRule = .evenOdd
        overlayView.layer.mask = maskLayer
        view.addSubview(overlayView)
        view.addSubview(frameView)
        
        if let previewLayer = previewLayer {
            let converted = previewLayer.metadataOutputRectConverted(fromLayerRect: frameView.frame)
            roiRect = CGRect(x: converted.origin.x, y: 1 - converted.origin.y - converted.height, width: converted.width, height: converted.height)
        }
        
        let label = UILabel()
        label.text = currentOCRMode == .catNo
            ? NSLocalizedString("align_frame_catno", comment: "")
            : NSLocalizedString("align_frame", comment: "")
        label.textColor = .white
        label.textAlignment = .center
        label.frame = CGRect(x: 0, y: frameView.frame.maxY + 10, width: view.bounds.width, height: 30)
        label.tag = 1002
        view.addSubview(label)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(focusOnTap(_:)))
        tapGesture.cancelsTouchesInView = false
        focusTapGesture = tapGesture
        view.addGestureRecognizer(tapGesture)
    }
    
    func stopOCRCamera() {
        (UIApplication.shared.delegate as? AppDelegate)?.orientationLock = .all
        captureSession?.stopRunning()
        previewLayer?.removeFromSuperlayer()
        view.viewWithTag(999)?.removeFromSuperview()
        view.viewWithTag(1001)?.removeFromSuperview()
        view.viewWithTag(1002)?.removeFromSuperview()
        view.viewWithTag(1003)?.removeFromSuperview()
        view.viewWithTag(1005)?.removeFromSuperview()
        if let gesture = focusTapGesture { view.removeGestureRecognizer(gesture); focusTapGesture = nil }
        restoreBackButton()
    }

    @objc func focusOnTap(_ gesture: UITapGestureRecognizer) {
        guard let device = AVCaptureDevice.default(for: .video), let previewLayer = previewLayer else { return }
        let tapPoint = gesture.location(in: view)
        if let scanButton = view.viewWithTag(1003), scanButton.frame.contains(tapPoint) { return }
        let focusPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: tapPoint)
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported { device.focusPointOfInterest = focusPoint; device.focusMode = .autoFocus }
            if device.isExposurePointOfInterestSupported { device.exposurePointOfInterest = focusPoint; device.exposureMode = .autoExpose }
            device.unlockForConfiguration()
            showFocusIndicator(at: tapPoint)
        } catch { print("タップフォーカスエラー:", error) }
    }

    func showFocusIndicator(at point: CGPoint) {
        let indicator = UIView(frame: CGRect(x: 0, y: 0, width: 70, height: 70))
        indicator.center = point
        indicator.layer.borderColor = UIColor.yellow.cgColor
        indicator.layer.borderWidth = 2
        indicator.layer.cornerRadius = 4
        indicator.backgroundColor = .clear
        view.addSubview(indicator)
        UIView.animate(withDuration: 0.3, animations: { indicator.transform = CGAffineTransform(scaleX: 0.7, y: 0.7) }) { _ in
            UIView.animate(withDuration: 0.5, delay: 0.5) { indicator.alpha = 0 } completion: { _ in indicator.removeFromSuperview() }
        }
    }
    
    func addScanButton() {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("scan_button", comment: ""), for: .normal)
        button.backgroundColor = .systemBlue
        button.tintColor = .white
        button.layer.cornerRadius = 8
        let frameBottom = view.bounds.height * 0.35 + 120
        let safeAreaBottom = view.bounds.height - view.safeAreaInsets.bottom
        let buttonY = (frameBottom + safeAreaBottom) / 2 - 25
        button.frame = CGRect(x: (view.bounds.width - 200) / 2, y: buttonY, width: 200, height: 50)
        button.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
        button.tag = 1003
        view.addSubview(button)
        view.bringSubviewToFront(button)
    }
    
    @objc func startScan() { isScanning = true }
    @objc func scanButtonTapped() { shouldCaptureFrame = true; showScanLoadingOverlay() }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopOCRCamera()
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { return .portrait }
    override var shouldAutorotate: Bool { return false }
    
    func showToast(message: String, duration: Double = 2.0, completion: (() -> Void)? = nil) {
        let toast = UILabel()
        toast.text = message
        toast.textColor = .white
        toast.textAlignment = .center
        toast.font = UIFont.systemFont(ofSize: 17, weight: .medium)
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
            toast.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            toast.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            toast.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 28),
            toast.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -28),
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -view.bounds.height / 6),
            container.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -60),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        UIView.animate(withDuration: 0.3, animations: { container.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.3, delay: duration, animations: { container.alpha = 0 }) { _ in
                container.removeFromSuperview()
                completion?()
            }
        }
    }

    func showShazamOverlay() {
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        overlay.tag = 2001
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        let iconImage = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 100, weight: .regular)
        iconImage.image = UIImage(systemName: "music.note", withConfiguration: config)
        iconImage.tintColor = .orange
        iconImage.contentMode = .scaleAspectFit
        iconImage.tag = 2002
        iconImage.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(iconImage)
        let label = UILabel()
        label.text = NSLocalizedString("listening", comment: "")
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(label)
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle(NSLocalizedString("cancel_button", comment: ""), for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        cancelButton.tintColor = .white
        cancelButton.layer.borderColor = UIColor.white.cgColor
        cancelButton.layer.borderWidth = 1
        cancelButton.layer.cornerRadius = 8
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelShazam), for: .touchUpInside)
        overlay.addSubview(cancelButton)
        NSLayoutConstraint.activate([
            iconImage.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            iconImage.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -40),
            iconImage.widthAnchor.constraint(equalToConstant: 100),
            iconImage.heightAnchor.constraint(equalToConstant: 100),
            label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            label.topAnchor.constraint(equalTo: iconImage.bottomAnchor, constant: 16),
            cancelButton.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            cancelButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 40),
            cancelButton.widthAnchor.constraint(equalToConstant: 120),
            cancelButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        overlay.alpha = 0
        UIView.animate(withDuration: 0.3) { overlay.alpha = 1 }
        UIView.animate(withDuration: 0.8, delay: 0, options: [.repeat, .autoreverse], animations: {
            iconImage.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        })
    }

    func hideShazamOverlay() {
        if let overlay = view.viewWithTag(2001) {
            UIView.animate(withDuration: 0.3, animations: { overlay.alpha = 0 }) { _ in overlay.removeFromSuperview() }
        }
    }

    @objc func cancelShazam() { hideShazamOverlay(); stopShazamRecognition() }
    
    func showLoadingOverlay() {
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        overlay.tag = 5001
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(spinner)
        let label = UILabel()
        label.text = NSLocalizedString("searching_discogs", comment: "")
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(label)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -20),
            label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            label.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 16)
        ])
        overlay.alpha = 0
        spinner.startAnimating()
        UIView.animate(withDuration: 0.3) { overlay.alpha = 1 }
    }

    func hideLoadingOverlay() {
        guard let overlay = view.viewWithTag(5001) else { return }
        UIView.animate(withDuration: 0.2, animations: { overlay.alpha = 0 }) { _ in overlay.removeFromSuperview() }
    }

    func showScanLoadingOverlay() {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.tag = 6001
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        spinner.startAnimating()
    }

    func hideScanLoadingOverlay() { view.viewWithTag(6001)?.removeFromSuperview() }
}

extension AddViewController2: SHSessionDelegate {
    
    func session(_ session: SHSession, didFind match: SHMatch) {
        guard let item = match.mediaItems.first else { return }
        let artist = item.artist ?? ""
        let song   = item.title  ?? ""
        DispatchQueue.main.async {
            self.hideShazamOverlay()
            self.stopShazamRecognition()
            self.fetchAlbumFromiTunes(artist: artist, song: song) { albumName, artistName, collectionType in
                let finalArtist = artistName ?? artist
                let finalAlbum  = albumName ?? song
                DispatchQueue.main.async {
                    self.fetchDiscogsInfoByShazam(artist: finalArtist, title: finalAlbum, song: song)
                }
            }
        }
    }
    
    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        DispatchQueue.main.async {
            self.hideShazamOverlay()
            self.stopShazamRecognition()
            self.showAlert(NSLocalizedString("music_not_recognized", comment: ""))
        }
    }

    func fetchAlbumFromiTunes(artist: String, song: String, completion: @escaping (String?, String?, String?) -> Void) {
        let query = "\(artist) \(song)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://itunes.apple.com/search?term=\(query)&entity=song&limit=1"
        guard let url = URL(string: urlString) else { completion(nil, nil, nil); return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first else { completion(nil, nil, nil); return }
            completion(first["collectionName"] as? String, first["artistName"] as? String, first["collectionType"] as? String)
        }.resume()
    }

    // ★ fetchDiscogsInfoByShazam：Shazamは2クエリ合算のためページネーションなし
    func fetchDiscogsInfoByShazam(artist: String, title: String, song: String? = nil) {
        let key = "VTvQRnPmaaybKvVDYsej"
        let secret = "VKFSjBMuqcgsAdmMvUzfoeLlsQbGYqdE"
        let group = DispatchGroup()
        var allResults: [[String: Any]] = []
        
        let albumQuery = "\(artist) \(title)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let albumURL = URL(string: "https://api.discogs.com/database/search?q=\(albumQuery)&type=release&key=\(key)&secret=\(secret)")!
        group.enter()
        var albumRequest = URLRequest(url: albumURL)
        albumRequest.setValue("RecoColle2/1.0", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: albumRequest) { data, _, _ in
            defer { group.leave() }
            guard let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else { return }
            allResults.append(contentsOf: results)
        }.resume()
        
        if let song = song, song != title {
            let songQuery = "\(artist) \(song)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let songURL = URL(string: "https://api.discogs.com/database/search?q=\(songQuery)&type=release&key=\(key)&secret=\(secret)")!
            group.enter()
            var songRequest = URLRequest(url: songURL)
            songRequest.setValue("RecoColle2/1.0", forHTTPHeaderField: "User-Agent")
            URLSession.shared.dataTask(with: songRequest) { data, _, _ in
                defer { group.leave() }
                guard let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let results = json["results"] as? [[String: Any]] else { return }
                allResults.append(contentsOf: results)
            }.resume()
        }
        
        group.notify(queue: .main) {
            var seen = Set<Int>()
            let unique = allResults.filter { item in
                guard let id = item["id"] as? Int else { return true }
                return seen.insert(id).inserted
            }
            guard !unique.isEmpty else {
                self.showAlert(NSLocalizedString("no_results", comment: ""))
                return
            }
            // Shazamは2クエリ合算のためページネーションなし（totalPages: 1）
            self.showOCRResultList(unique,
                                   title: NSLocalizedString("shazam_results", comment: ""),
                                   query: nil,
                                   totalPages: 1)
        }
    }
}
