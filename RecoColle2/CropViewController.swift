//
//  CropViewController.swift
//  RecoColle2
//
//  ・写真は画面いっぱいに表示（固定）
//  ・正方形の枠をドラッグで移動、コーナーをドラッグでリサイズ
//  ・確定で枠内を切り抜いて返す

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
    private let imageView    = UIImageView()
    private let cropBoxView  = CropBoxView()
    private let confirmButton = UIButton(type: .system)
    private let cancelButton  = UIButton(type: .system)

    // クロップ枠のフレーム（view座標系）
    private var cropFrame: CGRect = .zero

    // ドラッグ開始時の状態
    private var dragStartCropFrame: CGRect = .zero
    private var dragStartPoint: CGPoint = .zero
    private enum DragMode {
        case none, move
        case resizeTopLeft, resizeTopRight, resizeBottomLeft, resizeBottomRight
    }
    private var dragMode: DragMode = .none

    // コーナーのタッチ判定サイズ
    private let cornerHitSize: CGFloat = 44

    // 枠の最小サイズ
    private let minBoxSize: CGFloat = 80

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupImageView()
        setupCropBox()
        setupButtons()
        setupGestures()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupInitialLayout()
    }

    private var layoutDone = false
    private func setupInitialLayout() {
        guard !layoutDone else { return }
        layoutDone = true

        // 画像を画面いっぱいに表示（アスペクト比維持）
        guard let img = sourceImage else { return }
        let viewW = view.bounds.width
        let viewH = view.bounds.height
        let imgW  = img.size.width
        let imgH  = img.size.height
        let scale = min(viewW / imgW, viewH / imgH)
        let dispW = imgW * scale
        let dispH = imgH * scale
        imageView.frame = CGRect(
            x: (viewW - dispW) / 2,
            y: (viewH - dispH) / 2,
            width: dispW,
            height: dispH
        )

        // 初期クロップ枠：画像表示範囲内で中央に正方形
        let boxSize = min(dispW, dispH) * 0.8
        cropFrame = CGRect(
            x: (viewW - boxSize) / 2,
            y: (viewH - boxSize) / 2,
            width: boxSize,
            height: boxSize
        )
        cropBoxView.frame = view.bounds
        cropBoxView.cropRect = cropFrame
        cropBoxView.setNeedsDisplay()
    }

    // MARK: - Setup

    private func setupImageView() {
        imageView.contentMode = .scaleAspectFit
        imageView.image = sourceImage?.fixedOrientation()
        view.addSubview(imageView)
    }

    private func setupCropBox() {
        cropBoxView.isUserInteractionEnabled = false
        view.addSubview(cropBoxView)
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

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(pan)
    }

    // MARK: - Gesture

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        let point = gr.location(in: view)

        switch gr.state {
        case .began:
            dragStartPoint = point
            dragStartCropFrame = cropFrame
            dragMode = detectDragMode(at: point)

        case .changed:
            let dx = point.x - dragStartPoint.x
            let dy = point.y - dragStartPoint.y
            updateCropFrame(dx: dx, dy: dy)

        default:
            dragMode = .none
        }
    }

    private func detectDragMode(at point: CGPoint) -> DragMode {
        let f = cropFrame
        let hs = cornerHitSize

        // コーナー判定（正方形なので4隅）
        if CGRect(x: f.minX - hs/2, y: f.minY - hs/2, width: hs, height: hs).contains(point) {
            return .resizeTopLeft
        }
        if CGRect(x: f.maxX - hs/2, y: f.minY - hs/2, width: hs, height: hs).contains(point) {
            return .resizeTopRight
        }
        if CGRect(x: f.minX - hs/2, y: f.maxY - hs/2, width: hs, height: hs).contains(point) {
            return .resizeBottomLeft
        }
        if CGRect(x: f.maxX - hs/2, y: f.maxY - hs/2, width: hs, height: hs).contains(point) {
            return .resizeBottomRight
        }
        // 枠内ならMove
        if f.contains(point) {
            return .move
        }
        return .none
    }

    private func updateCropFrame(dx: CGFloat, dy: CGFloat) {
        let img = imageView.frame  // 画像の表示範囲（移動・リサイズの限界）
        var f = dragStartCropFrame

        switch dragMode {
        case .move:
            f.origin.x += dx
            f.origin.y += dy

        case .resizeTopLeft:
            // 左上コーナー：右下を固定して正方形を維持
            let delta = (dx + dy) / 2  // 平均移動量で正方形維持
            let newSize = max(minBoxSize, f.width - delta)
            let sizeDiff = newSize - f.width
            f.origin.x -= sizeDiff
            f.origin.y -= sizeDiff
            f.size = CGSize(width: newSize, height: newSize)

        case .resizeTopRight:
            // 右上コーナー：左下を固定
            let delta = (-dx + dy) / 2
            let newSize = max(minBoxSize, f.width - delta)
            let sizeDiff = newSize - f.width
            f.origin.y -= sizeDiff
            f.size = CGSize(width: newSize, height: newSize)

        case .resizeBottomLeft:
            // 左下コーナー：右上を固定
            let delta = (dx - dy) / 2
            let newSize = max(minBoxSize, f.width - delta)
            let sizeDiff = newSize - f.width
            f.origin.x -= sizeDiff
            f.size = CGSize(width: newSize, height: newSize)

        case .resizeBottomRight:
            // 右下コーナー：左上を固定
            let delta = -(dx + dy) / 2
            let newSize = max(minBoxSize, f.width - delta)
            f.size = CGSize(width: newSize, height: newSize)

        case .none:
            return
        }

        // 画像範囲外に出ないよう制限
        f.origin.x = max(img.minX, min(f.origin.x, img.maxX - f.width))
        f.origin.y = max(img.minY, min(f.origin.y, img.maxY - f.height))
        // 枠が画像からはみ出ないようサイズも制限
        f.size.width  = min(f.width,  img.maxX - f.origin.x)
        f.size.height = min(f.height, img.maxY - f.origin.y)
        // 正方形を維持
        let side = min(f.width, f.height)
        f.size = CGSize(width: side, height: side)

        cropFrame = f
        cropBoxView.cropRect = f
        cropBoxView.setNeedsDisplay()
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
        guard let img = sourceImage?.fixedOrientation() else { return UIImage() }

        // imageView上での表示スケール（元画像→表示画像）
        let scaleX = img.size.width  / imageView.frame.width
        let scaleY = img.size.height / imageView.frame.height

        // cropFrameをimageView座標系に変換
        let relX = cropFrame.origin.x - imageView.frame.origin.x
        let relY = cropFrame.origin.y - imageView.frame.origin.y

        // 元画像座標に変換
        let srcX = relX * scaleX
        let srcY = relY * scaleY
        let srcW = cropFrame.width  * scaleX
        let srcH = cropFrame.height * scaleY

        let clampedX = max(0, min(srcX, img.size.width  - srcW))
        let clampedY = max(0, min(srcY, img.size.height - srcH))
        let clampedW = min(srcW, img.size.width  - clampedX)
        let clampedH = min(srcH, img.size.height - clampedY)

        let rect = CGRect(x: clampedX, y: clampedY, width: clampedW, height: clampedH)
        guard let cgImg = img.cgImage?.cropping(to: rect) else { return img }
        return UIImage(cgImage: cgImg)
    }
}

// MARK: - CropBoxView（暗幕＋正方形の穴＋コーナーハンドル）

class CropBoxView: UIView {

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
            ctx.move(to: CGPoint(x: x, y: cropRect.minY))
            ctx.addLine(to: CGPoint(x: x, y: cropRect.maxY))
            let y = cropRect.minY + third * CGFloat(i)
            ctx.move(to: CGPoint(x: cropRect.minX, y: y))
            ctx.addLine(to: CGPoint(x: cropRect.maxX, y: y))
        }
        ctx.strokePath()

        // コーナーハンドル（大きめで掴みやすく）
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(4)
        let L: CGFloat = 24
        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: cropRect.minX, y: cropRect.minY + L),
             CGPoint(x: cropRect.minX, y: cropRect.minY),
             CGPoint(x: cropRect.minX + L, y: cropRect.minY)),
            (CGPoint(x: cropRect.maxX - L, y: cropRect.minY),
             CGPoint(x: cropRect.maxX, y: cropRect.minY),
             CGPoint(x: cropRect.maxX, y: cropRect.minY + L)),
            (CGPoint(x: cropRect.minX, y: cropRect.maxY - L),
             CGPoint(x: cropRect.minX, y: cropRect.maxY),
             CGPoint(x: cropRect.minX + L, y: cropRect.maxY)),
            (CGPoint(x: cropRect.maxX - L, y: cropRect.maxY),
             CGPoint(x: cropRect.maxX, y: cropRect.maxY),
             CGPoint(x: cropRect.maxX, y: cropRect.maxY - L)),
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
