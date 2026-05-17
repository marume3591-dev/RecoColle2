// DetailViewController.swift
// OCR + Discogs（Add と同等ロジック版）

import UIKit
import AVFoundation
import SwiftUI

class DetailViewController: UIViewController,
                            UITextFieldDelegate,
                            UIImagePickerControllerDelegate,
                            UINavigationControllerDelegate,
                            AVCaptureMetadataOutputObjectsDelegate , UITextViewDelegate{
    
    private var activeField: UIView?
    
    // MARK: - OCR Mode
    enum OCRMode {
        case artistTitle
        case catNo
    }
    
    var shouldRunOCR = false
    var currentOCRMode: OCRMode = .artistTitle
    
    let fromAppDelegate: AppDelegate = UIApplication.shared.delegate as! AppDelegate
    
    var recordList: RecordList2!
    var gamenflg: String?
    var noimage = UIImage(named: "noimage")!
    
    // MARK: - IBOutlets
    @IBOutlet weak var TextField1: UITextField!
    @IBOutlet weak var TextField2: UITextField!
    @IBOutlet weak var albumImage: UIImageView!
    @IBOutlet weak var Format: UITextField!
    @IBOutlet weak var TextField3: UITextField!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var Button: UIButton!
    @IBOutlet weak var TextField4: UITextField!
    @IBOutlet weak var bannerView: UIView!
    @IBOutlet weak var Button1: UIButton!
    
    @IBOutlet weak var Button2: UIButton!
    // MARK: - Image
    @IBOutlet weak var Button3: UIButton!
    @IBOutlet weak var Button4: UIButton!
    @IBOutlet weak var listSegment: UISegmentedControl!
    var image: UIImage?
    var resizedPicture: UIImage?
    
    // OCR 用
    var ocrImage: UIImage?
    var ocrSearchResults: [[String: Any]] = []
    
    // Barcode
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var wantsFlg = "false"
    
    @IBAction func onTapImage(_ sender: UITapGestureRecognizer) {
        view.endEditing(true)
        view.transform = .identity
        let point = sender.location(in: albumImage)

        if albumImage.bounds.contains(point) {
            performSegue(withIdentifier: "toEbaySearch", sender: self)
        }
    }

    @IBAction func ebayBtnTapped(_ sender: Any) {
        view.endEditing(true)
        view.transform = .identity
        performSegue(withIdentifier: "toEbaySearch", sender: self)
    }
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        wantsFlg = sender.selectedSegmentIndex == 1 ? "true" : "false"
    }
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
            
            print("DetailView → Premium:", isPremium)
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.transform = .identity
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        TextField1.delegate = self
        TextField2.delegate = self
        TextField3.delegate = self
        TextField4.delegate = self
        Format.delegate = self
        textView.delegate = self
        
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
        
        TextField1.text = recordList.artistName
        TextField2.text = recordList.albumTitle
        TextField3.text = recordList.releaseCountry
        TextField4.text = recordList.releaseDate
        Format.text = recordList.format
        textView.text = recordList.memo
        
        if let data = recordList.albumImage,
           let img = UIImage(data: data) {
            resizedPicture = img.resize2(targetSize: CGSize(width: 80, height: 80))
            albumImage.image = resizedPicture
            image = img
        } else {
            albumImage.image = noimage
        }
        
        wantsFlg = recordList.wantsFlg ?? "false"

        let tap = UITapGestureRecognizer(target: self,
                                         action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
        textView.layer.cornerRadius = 5
        textView.clipsToBounds = true

        Button.layer.cornerRadius = 10

        TextField1.layer.borderColor = UIColor.lightGray.cgColor
        TextField2.layer.borderColor = UIColor.lightGray.cgColor
        Format.layer.borderColor = UIColor.lightGray.cgColor
        TextField3.layer.borderColor = UIColor.lightGray.cgColor
        TextField4.layer.borderColor = UIColor.lightGray.cgColor
        
        TextField1.layer.borderWidth = 0.5
        TextField2.layer.borderWidth = 0.5
        Format.layer.borderWidth = 0.5
        TextField3.layer.borderWidth = 0.5
        TextField4.layer.borderWidth = 0.5

        TextField1.layer.cornerRadius = 5
        TextField2.layer.cornerRadius = 5
        Format.layer.cornerRadius = 5
        TextField3.layer.cornerRadius = 5
        TextField4.layer.cornerRadius = 5

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
    
    // MARK: - OCR Buttons
    @IBAction func ocrBtnTapped(_ sender: UIButton) {
        guard PremiumManager.shared.isPremium else {
            showOCRPaywall()
            return
        }
        shouldRunOCR = true
        currentOCRMode = .artistTitle
        presentCamera()
    }
    
    @IBAction func catNoBtnTapped(_ sender: UIButton) {
        guard PremiumManager.shared.isPremium else {
            showOCRPaywall()
            return
        }
        shouldRunOCR = true
        currentOCRMode = .catNo
        presentCamera()
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

    func presentCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = self
        picker.allowsEditing = false
        present(picker, animated: true)
    }
    
    // MARK: - Barcode
    @IBAction func scanBarcodeBtnTapped(_ sender: UIButton) {
        startBarcodeScanning()
    }
    
    func startBarcodeScanning() {
        captureSession = AVCaptureSession()
        guard let session = captureSession else { return }
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            showAlert("Camera input error")
            return
        }
        
        session.addInput(input)
        
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.ean8, .ean13]
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer!)
        
        session.startRunning()
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        
        captureSession?.stopRunning()
        previewLayer?.removeFromSuperlayer()
        
        if let code = (metadataObjects.first as?
                       AVMetadataMachineReadableCodeObject)?.stringValue {
            fetchDiscogsByBarcode(code)
        }
    }
    
    // MARK: - Discogs Search
    func fetchDiscogsByBarcode(_ barcode: String) {
        let key = "VTvQRnPmaaybKvVDYsej"
        let secret = "VKFSjBMuqcgsAdmMvUzfoeLlsQbGYqdE"
        let userAgent = "RecoColle2/1.0 (marume3591@icloud.com)"
        
        let urlString =
        "https://api.discogs.com/database/search" +
        "?barcode=\(barcode)&key=\(key)&secret=\(secret)"
        
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  !results.isEmpty else {
                DispatchQueue.main.async {
                    self.showAlert("No information found")
                }
                return
            }
            
            self.ocrSearchResults = results
            DispatchQueue.main.async {
                self.showOCRResultsList()
            }
        }.resume()
    }
    
    func fetchDiscogsByOCRTexts(_ texts: [String]) {
        let key = "VTvQRnPmaaybKvVDYsej"
        let secret = "VKFSjBMuqcgsAdmMvUzfoeLlsQbGYqdE"
        let userAgent = "RecoColle2/1.0 (marume3591@icloud.com)"
        
        let query = texts.joined(separator: " ")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString =
        "https://api.discogs.com/database/search" +
        "?q=\(query)&type=release" +
        "&key=\(key)&secret=\(secret)"
        
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  !results.isEmpty else {
                DispatchQueue.main.async {
                    self.showAlert("No OCR search results found")
                }
                return
            }
            
            self.ocrSearchResults = results
            DispatchQueue.main.async {
                self.showOCRResultsList()
            }
        }.resume()
    }
    
    func fetchDiscogsByCatNo(_ catNo: String) {
        let key = "VTvQRnPmaaybKvVDYsej"
        let secret = "VKFSjBMuqcgsAdmMvUzfoeLlsQbGYqdE"
        
        let encoded = catNo.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString =
        "https://api.discogs.com/database/search" +
        "?catno=\(encoded)&type=release" +
        "&key=\(key)&secret=\(secret)"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  !results.isEmpty else {
                DispatchQueue.main.async {
                    self.showAlert("No OCR search results found")
                }
                return
            }
            
            self.ocrSearchResults = results
            DispatchQueue.main.async {
                self.showOCRResultsList()
            }
        }.resume()
    }
    
    func showOCRResultsList() {
        let vc = OCRResultViewController()
        vc.results = ocrSearchResults
        vc.onSelect = { [weak self] selected in
            self?.applyDiscogsResult(selected)
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    // MARK: - Apply Discogs Result
    func applyDiscogsResult(_ first: [String: Any]) {
        
        let coverURL = first["cover_image"] as? String ?? ""
        let formats  = (first["format"] as? [String])?.joined(separator: ", ") ?? ""
        let country  = first["country"] as? String ?? ""
        
        let title = first["title"] as? String ?? ""
        let separators: [Character] = ["–", "-"]
        let parts = title
            .split(whereSeparator: { separators.contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
        
        let artistName = parts.count > 0 ? parts[0] : ""
        let albumTitle = parts.count > 1 ? parts[1] : parts[0]
        
        DispatchQueue.main.async {
            self.TextField1.text = artistName
            self.TextField2.text = albumTitle
            self.TextField3.text = country
            self.Format.text     = formats
        }
        
        // ===== year =====
        // Add と違い「一覧で取得済み」を優先
        if let year = first["year"] as? String {
            self.TextField4.text = year
        }
        
        // ===== CATNO =====
        if let catno = first["catno"] as? String {
            self.textView.text = "CATNO: \(catno)"
        }
        
        // ===== image =====
        if let url = URL(string: coverURL) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let img = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.albumImage.image = img
                        self.image = img
                        self.resizedPicture = img.resize(targetSize: CGSize(width: 80, height: 80))
                    }
                }
            }.resume()
        }
    }
    
    // MARK: - Image Picker
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info:
                               [UIImagePickerController.InfoKey: Any]) {
        
        picker.dismiss(animated: true)
        
        guard let pickedImage = info[.originalImage] as? UIImage else { return }
        
        // OCR の場合：画面には反映しない
        if shouldRunOCR {
            ocrImage = pickedImage
            
            let service = SpineOCRService()
            service.recognize(from: pickedImage) { [weak self] hint in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    switch self.currentOCRMode {
                    case .artistTitle:
                        self.fetchDiscogsByOCRTexts(hint.rawTexts)
                    case .catNo:
                        if let catno = hint.catno {
                            self.fetchDiscogsByCatNo(catno)
                        } else {
                            self.showAlert("Catalog number could not be recognized")
                        }
                    }
                }
            }
            return
        }
        
        // 通常画像選択
        image = pickedImage
        resizedPicture = pickedImage.resize2(
            targetSize: CGSize(width: 200, height: 200)
        )
        albumImage.image = resizedPicture
    }
    
    // MARK: - Save
    @IBAction func btnTapped(_ sender: Any) {
        guard !(TextField1.text?.isEmpty ?? true),
              !(TextField2.text?.isEmpty ?? true) else {
            showAlert("Artist Name and Album Title are required")
            return
        }
        
        recordList.artistName = TextField1.text!
        recordList.albumTitle = TextField2.text!
        recordList.format = Format.text!
        recordList.releaseCountry = TextField3.text!
        recordList.releaseDate = TextField4.text!
        recordList.wantsFlg = wantsFlg
        recordList.memo = textView.text!
        
        if let img = resizedPicture {
            recordList.albumImage = img.jpegData(compressionQuality: 0.1)
        } else {
            recordList.albumImage = nil
        }
        
        fromAppDelegate.saveContext()
        
        if gamenflg == "albumDetail" {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
        NotificationCenter.default.post(name: .recordUpdated, object: nil)
    }
    
    // MARK: - Utility
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func showAlert(_ message: String) {
        let alert = UIAlertController(title: "Notice",
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK",
                                      style: .default))
        present(alert, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toEbaySearch" {
            guard let destination = segue.destination as? EbayViewController else {
                fatalError("Failed to prepare EbayViewController.")
            }
            destination.recordList = recordList
        }
    }

    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        activeField = textField
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        activeField = nil
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        activeField = textView
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        activeField = nil
    }
    
    @IBAction func photoBtnTapped(_ sender: Any) {
        // カメラロール表示
            let imagePickerController = UIImagePickerController()
            imagePickerController.sourceType = .photoLibrary
            imagePickerController.delegate = self
            imagePickerController.mediaTypes = ["public.image"]
            present(imagePickerController,animated: true,completion: nil)
    }

    @objc func showkeyboard(notification: Notification) {
        view.transform = .identity   // ←追加

        guard let activeField = activeField,
              let keyboardFrame =
                notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                    as? CGRect else { return }

        let keyboardMinY = keyboardFrame.minY
        let fieldMaxY = activeField.convert(activeField.bounds, to: view).maxY

        let distance = fieldMaxY - keyboardMinY + 20

        if distance > 0 {
            UIView.animate(withDuration: 0.3) {
                self.view.transform =
                    CGAffineTransform(translationX: 0, y: -distance)
            }
        }
    }

    @objc func hidekeyboard() {
        UIView.animate(withDuration: 0.3) {
            self.view.transform = .identity
        }
    }
}


// MARK: - UIImage Resize
extension UIImage {
    func resize2(targetSize: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: targetSize).image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
