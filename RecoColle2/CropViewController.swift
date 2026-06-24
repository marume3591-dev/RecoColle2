//
//  CropViewController.swift
//  RecoColle2
//
//  写真を正方形にクロップするViewController
//  ・ピンチで拡大縮小、ドラッグで移動
//  ・正方形の枠内に収まる部分を切り抜いて返す

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

    private let scrollView = UIScrollView()
    private let imageView  = UIImageView()

    /// 正方形のクロップ枠（ガイド表示のみ）
    private let cropOverlay = CropOverlayView()

    private let confirmButton = UIButton(type: .system)
    private let cancelButton  = UIButton(type: .system)

    /// クロップ枠のサイズ（画面幅 - 余白）
    private var cropSize: CGFloat {
        return min(view.bounds.width, view.bounds.height) - 40
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
    }

    // MARK: - Setup

    private func setupScrollView() {
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator   = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.clipsToBounds = false
        view.addSubview(scrollView)

        imageView.image = sourceImage
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)
    }

    private func setupOverlay() {
        cropOverlay.isUserInteractionEnabled = false
        view.addSubview(cropOverlay)
    }

    private func setupButtons() {
        // キャンセル
        cancelButton.setTitle("キャンセル", for: .normal)
        cancelButton.tintColor = .white
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)
        view.addSubview(cancelButton)

        // 確定
        confirmButton.setTitle("確定", for: .normal)
        confirmButton.tintColor = .systemYellow
        confirmButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        confirmButton.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)
        view.addSubview(confirmButton)

        cancelButton.translatesAutoresizingMaskIntoConstraints  = false
        confirmButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            confirmButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    private func configureScrollView() {
        let size = cropSize

        // クロップ枠を画面中央に配置
        let cropRect = CGRect(
            x: (view.bounds.width  - size) / 2,
            y: (view.bounds.height - size) / 2,
            width: size,
            height: size
        )
        cropOverlay.frame       = view.bounds
        cropOverlay.cropRect    = cropRect
        cropOverlay.setNeedsDisplay()

        // ScrollView をクロップ枠に合わせる
        scrollView.frame = cropRect

        // 画像サイズに合わせて contentSize を設定
        guard let img = sourceImage else { return }
        let imgW = img.size.width
        let imgH = img.size.height
        let scale = size / max(imgW, imgH)          // 長辺をクロップ枠に合わせる初期スケール
        let scaledW = imgW * scale
        let scaledH = imgH * scale

        imageView.frame = CGRect(x: 0, y: 0, width: scaledW, height: scaledH)
        scrollView.contentSize = imageView.frame.size

        // ズーム範囲：初期スケールを1倍として最大5倍
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.zoomScale        = 1.0

        // 画像が小さい場合は中央に寄せる
        centerImageInScrollView()
    }

    private func centerImageInScrollView() {
        let offsetX = max(0, (scrollView.bounds.width  - imageView.frame.width)  / 2)
        let offsetY = max(0, (scrollView.bounds.height - imageView.frame.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }

    // MARK: - Actions

    @objc private func didTapCancel() {
        delegate?.cropViewControllerDidCancel(self)
    }

    @objc private func didTapConfirm() {
        let cropped = cropImage()
        delegate?.cropViewController(self, didCrop: cropped)
    }

    // MARK: - Crop

    private func cropImage() -> UIImage {
        guard let img = sourceImage else { return UIImage() }

        // scrollView 上での表示スケールを取得
        let zoomScale    = scrollView.zoomScale
        let contentOffset = scrollView.contentOffset
        let inset        = scrollView.contentInset

        // クロップ枠（= scrollView.frame = cropRect）の左上が contentOffset の基準
        // contentInset が負にならないよう調整
        let originX = max(0, contentOffset.x + inset.left)
        let originY = max(0, contentOffset.y + inset.top)

        // ScrollView 内でのクロップ枠（full cropSize × cropSize）に対応する
        // 元画像座標を計算
        let imgW   = img.size.width
        let imgH   = img.size.height
        let scale  = cropSize / max(imgW, imgH)     // configureScrollView と同じ初期スケール
        let totalScale = scale * zoomScale           // 実際の表示スケール

        let cropX  = originX / totalScale
        let cropY  = originY / totalScale
        let cropW  = cropSize  / totalScale
        let cropH  = cropSize  / totalScale

        let clampedX = min(max(0, cropX), imgW - cropW)
        let clampedY = min(max(0, cropY), imgH - cropH)
        let clampedW = min(cropW, imgW - clampedX)
        let clampedH = min(cropH, imgH - clampedY)

        let cropRect = CGRect(x: clampedX, y: clampedY, width: clampedW, height: clampedH)

        // 向き補正してから切り抜く
        let fixedImage = img.fixedOrientation()
        guard let cgImage = fixedImage.cgImage?.cropping(to: cropRect) else {
            return img
        }

        return UIImage(cgImage: cgImage)
    }
}

// MARK: - UIScrollViewDelegate

extension CropViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImageInScrollView()
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

        // 正方形の穴を開ける
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
            ctx.move(to: CGPoint(x: x, y: cropRect.minY))
            ctx.addLine(to: CGPoint(x: x, y: cropRect.maxY))

            let y = cropRect.minY + third * CGFloat(i)
            ctx.move(to: CGPoint(x: cropRect.minX, y: y))
            ctx.addLine(to: CGPoint(x: cropRect.maxX, y: y))
        }
        ctx.strokePath()

        // コーナーマーカー
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(3)
        let cornerLen: CGFloat = 20

        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            // 左上
            (CGPoint(x: cropRect.minX, y: cropRect.minY + cornerLen),
             CGPoint(x: cropRect.minX, y: cropRect.minY),
             CGPoint(x: cropRect.minX + cornerLen, y: cropRect.minY)),
            // 右上
            (CGPoint(x: cropRect.maxX - cornerLen, y: cropRect.minY),
             CGPoint(x: cropRect.maxX, y: cropRect.minY),
             CGPoint(x: cropRect.maxX, y: cropRect.minY + cornerLen)),
            // 左下
            (CGPoint(x: cropRect.minX, y: cropRect.maxY - cornerLen),
             CGPoint(x: cropRect.minX, y: cropRect.maxY),
             CGPoint(x: cropRect.minX + cornerLen, y: cropRect.maxY)),
            // 右下
            (CGPoint(x: cropRect.maxX - cornerLen, y: cropRect.maxY),
             CGPoint(x: cropRect.maxX, y: cropRect.maxY),
             CGPoint(x: cropRect.maxX, y: cropRect.maxY - cornerLen)),
        ]

        for (p1, p2, p3) in corners {
            ctx.move(to: p1)
            ctx.addLine(to: p2)
            ctx.addLine(to: p3)
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
