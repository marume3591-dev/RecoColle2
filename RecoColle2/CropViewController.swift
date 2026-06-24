//
//  CropViewController.swift
//  RecoColle2
//
//  写真を正方形にクロップするViewController
//  ・ScrollViewを画面全体に広げてピンチ・ドラッグを全面で受け取る
//  ・正方形のオーバーレイは別レイヤーで表示（タッチを透過）
//  ・確定ボタンでクロップ枠内の画像を切り抜いて返す

import UIKit

protocol CropViewControllerDelegate: AnyObject {
    func cropViewController(_ vc: CropViewController, didCrop image: UIImage)
    func cropViewControllerDidCancel(_ vc: CropViewController)
}

class CropViewController: UIViewController {

    // MARK: - Public
    weak var delegate: CropViewControllerDelegate?
    var sourceImage: UIImage!

    // MARK: - Private UI
    private let scrollView   = UIScrollView()
    private let imageView    = UIImageView()
    private let cropOverlay  = CropOverlayView()
    private let confirmButton = UIButton(type: .system)
    private let cancelButton  = UIButton(type: .system)

    /// クロップ枠のサイズ（画面幅 - 余白）
    private var cropSize: CGFloat {
        return min(view.bounds.width, view.bounds.height) - 40
    }

    /// クロップ枠のRect（view座標系）
    private var cropRect: CGRect {
        let size = cropSize
        return CGRect(
            x: (view.bounds.width  - size) / 2,
            y: (view.bounds.height - size) / 2,
            width: size,
            height: size
        )
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupScrollView()
        setupOverlay()
        setupButtons()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configureScrollView()
        cropOverlay.frame    = view.bounds
        cropOverlay.cropRect = cropRect
        cropOverlay.setNeedsDisplay()
    }

    // MARK: - Setup

    private func setupScrollView() {
        // ScrollView は画面全体（ピンチ・ドラッグを全面で受け取る）
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator   = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom  = true
        scrollView.clipsToBounds = true
        scrollView.backgroundColor = .black
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        imageView.contentMode = .scaleAspectFit
        imageView.image = sourceImage
        scrollView.addSubview(imageView)
    }

    private func setupOverlay() {
        // オーバーレイはScrollViewの上に重ねる（タッチは透過）
        cropOverlay.isUserInteractionEnabled = false
        cropOverlay.backgroundColor = .clear
        view.addSubview(cropOverlay)
    }

    private func setupButtons() {
        cancelButton.setTitle("キャンセル", for: .normal)
        cancelButton.tintColor = .white
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)

        confirmButton.setTitle("確定", for: .normal)
        confirmButton.tintColor = .systemYellow
        confirmButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        confirmButton.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)

        [cancelButton, confirmButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            confirmButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    private func configureScrollView() {
        guard let img = sourceImage else { return }

        let viewW = view.bounds.width
        let viewH = view.bounds.height
        let imgW  = img.size.width
        let imgH  = img.size.height

        // 初期表示：画像の短辺をクロップ枠サイズに合わせる（枠が必ず画像内に収まる）
        let initialScale = cropSize / min(imgW, imgH)
        let scaledW = imgW * initialScale
        let scaledH = imgH * initialScale

        imageView.frame = CGRect(x: 0, y: 0, width: scaledW, height: scaledH)
        scrollView.contentSize = CGSize(width: scaledW, height: scaledH)

        // ズーム範囲
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.zoomScale        = 1.0

        // 画像を画面中央に表示
        let insetX = max(0, (viewW - scaledW) / 2)
        let insetY = max(0, (viewH - scaledH) / 2)
        scrollView.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)

        // クロップ枠の中心に画像中心が来るようにオフセットを設定
        let offsetX = (scaledW - viewW) / 2
        let offsetY = (scaledH - viewH) / 2
        if offsetX > 0 || offsetY > 0 {
            scrollView.contentOffset = CGPoint(
                x: max(0, offsetX),
                y: max(0, offsetY)
            )
        }
    }

    // MARK: - Actions

    @objc private func didTapCancel() {
        delegate?.cropViewControllerDidCancel(self)
    }

    @objc private func didTapConfirm() {
        delegate?.cropViewController(self, didCrop: cropImage())
    }

    // MARK: - Crop

    private func cropImage() -> UIImage {
        guard let img = sourceImage else { return UIImage() }

        let imgW = img.size.width
        let imgH = img.size.height

        // 現在の表示スケール（初期scale × zoomScale）
        let initialScale = cropSize / min(imgW, imgH)
        let totalScale   = initialScale * scrollView.zoomScale

        // scrollView上でのクロップ枠の位置（view座標 → scrollView content座標）
        let inset   = scrollView.contentInset
        let offset  = scrollView.contentOffset

        // クロップ枠のview座標系での左上
        let cropOriginInView = CGPoint(x: cropRect.minX, y: cropRect.minY)

        // scrollView content座標に変換
        let contentX = offset.x + cropOriginInView.x - inset.left  // insetが負になることはないがmax(0,...)で保護
        let contentY = offset.y + cropOriginInView.y - inset.top

        // 元画像座標に変換
        let imgX = contentX / totalScale
        let imgY = contentY / totalScale
        let imgCropW = cropSize / totalScale
        let imgCropH = cropSize / totalScale

        let clampedX = min(max(0, imgX), imgW - imgCropW)
        let clampedY = min(max(0, imgY), imgH - imgCropH)
        let clampedW = min(imgCropW, imgW - clampedX)
        let clampedH = min(imgCropH, imgH - clampedY)

        let rect = CGRect(x: clampedX, y: clampedY, width: clampedW, height: clampedH)

        let fixed = img.fixedOrientation()
        guard let cgImg = fixed.cgImage?.cropping(to: rect) else { return img }
        return UIImage(cgImage: cgImg)
    }
}

// MARK: - UIScrollViewDelegate

extension CropViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // ズーム後も画像を中央寄せ
        let viewW = view.bounds.width
        let viewH = view.bounds.height
        let contentW = scrollView.contentSize.width
        let contentH = scrollView.contentSize.height
        let insetX = max(0, (viewW - contentW) / 2)
        let insetY = max(0, (viewH - contentH) / 2)
        scrollView.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
    }
}

// MARK: - CropOverlayView（暗幕＋正方形の穴＋グリッド線）

class CropOverlayView: UIView {

    var cropRect: CGRect = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // 暗幕
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.55).cgColor)
        ctx.fill(rect)

        // 正方形の穴
        ctx.setBlendMode(.clear)
        ctx.fill(cropRect)
        ctx.setBlendMode(.normal)

        // 枠線
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(1.5)
        ctx.stroke(cropRect)

        // グリッド線（3×3）
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(0.5)
        let third = cropRect.width / 3
        for i in 1...2 {
            let x = cropRect.minX + third * CGFloat(i)
            ctx.move(to:    CGPoint(x: x, y: cropRect.minY))
            ctx.addLine(to: CGPoint(x: x, y: cropRect.maxY))
            let y = cropRect.minY + third * CGFloat(i)
            ctx.move(to:    CGPoint(x: cropRect.minX, y: y))
            ctx.addLine(to: CGPoint(x: cropRect.maxX, y: y))
        }
        ctx.strokePath()

        // コーナーマーカー
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(3)
        let L: CGFloat = 20
        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: cropRect.minX,     y: cropRect.minY + L), CGPoint(x: cropRect.minX,     y: cropRect.minY),     CGPoint(x: cropRect.minX + L, y: cropRect.minY)),
            (CGPoint(x: cropRect.maxX - L, y: cropRect.minY),     CGPoint(x: cropRect.maxX,     y: cropRect.minY),     CGPoint(x: cropRect.maxX,     y: cropRect.minY + L)),
            (CGPoint(x: cropRect.minX,     y: cropRect.maxY - L), CGPoint(x: cropRect.minX,     y: cropRect.maxY),     CGPoint(x: cropRect.minX + L, y: cropRect.maxY)),
            (CGPoint(x: cropRect.maxX - L, y: cropRect.maxY),     CGPoint(x: cropRect.maxX,     y: cropRect.maxY),     CGPoint(x: cropRect.maxX,     y: cropRect.maxY - L)),
        ]
        for (p1, p2, p3) in corners {
            ctx.move(to: p1); ctx.addLine(to: p2); ctx.addLine(to: p3)
        }
        ctx.strokePath()
    }
}

// MARK: - UIImage 向き補正

extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let result = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return result
    }
}
