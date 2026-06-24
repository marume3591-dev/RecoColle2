//
//  CropViewController.swift
//  RecoColle2
//
//  ・写真は画面いっぱいに表示
//  ・正方形の枠をドラッグで移動、コーナーをドラッグでリサイズ
//  ・下部スライダーで写真を回転（-45°〜+45°）
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
    private let imageView     = UIImageView()
    private let cropBoxView   = CropBoxView()
    private let confirmButton  = UIButton(type: .system)
    private let cancelButton   = UIButton(type: .system)
    private let rotationSlider = UISlider()
    private let angleLabel     = UILabel()

    // 現在の回転角度（ラジアン）
    private var currentAngle: CGFloat = 0

    // クロップ枠
    private var cropFrame: CGRect = .zero
    private var dragStartCropFrame: CGRect = .zero
    private var dragStartPoint: CGPoint = .zero
    private enum DragMode { case none, move, resizeTopLeft, resizeTopRight, resizeBottomLeft, resizeBottomRight }
    private var dragMode: DragMode = .none
    private let cornerHitSize: CGFloat = 44
    private let minBoxSize: CGFloat = 80

    // 画像の初期表示フレーム（回転の中心計算に使用）
    private var baseImageFrame: CGRect = .zero

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupImageView()
        setupCropBox()
        setupSlider()
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

        guard let img = sourceImage else { return }
        let viewW = view.bounds.width
        // スライダーエリア分を除いた高さ
        let sliderAreaH: CGFloat = 80
        let safeBottom = view.safeAreaInsets.bottom
        let availableH = view.bounds.height - sliderAreaH - safeBottom - 60

        let imgW = img.size.width
        let imgH = img.size.height
        let scale = min(viewW / imgW, availableH / imgH)
        let dispW = imgW * scale
        let dispH = imgH * scale

        baseImageFrame = CGRect(
            x: (viewW - dispW) / 2,
            y: (availableH - dispH) / 2 + view.safeAreaInsets.top,
            width: dispW,
            height: dispH
        )
        imageView.frame = baseImageFrame

        // 初期クロップ枠
        let boxSize = min(dispW, dispH) * 0.8
        cropFrame = CGRect(
            x: (viewW - boxSize) / 2,
            y: baseImageFrame.midY - boxSize / 2,
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

    private func setupSlider() {
        // 角度ラベル
        angleLabel.text = "0°"
        angleLabel.textColor = .white
        angleLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        angleLabel.textAlignment = .center
        angleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(angleLabel)

        // スライダー
        rotationSlider.minimumValue = -45
        rotationSlider.maximumValue =  45
        rotationSlider.value        =   0
        rotationSlider.tintColor    = .white
        rotationSlider.thumbTintColor = .white
        rotationSlider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
        rotationSlider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rotationSlider)

        // リセットボタン
        let resetButton = UIButton(type: .system)
        resetButton.setImage(UIImage(systemName: "arrow.counterclockwise"), for: .normal)
        resetButton.tintColor = .white
        resetButton.addTarget(self, action: #selector(resetRotation), for: .touchUpInside)
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(resetButton)

        NSLayoutConstraint.activate([
            angleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            angleLabel.bottomAnchor.constraint(equalTo: rotationSlider.topAnchor, constant: -4),

            rotationSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 50),
            rotationSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -50),
            rotationSlider.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),

            resetButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            resetButton.centerYAnchor.constraint(equalTo: rotationSlider.centerYAnchor),
        ])
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

    // MARK: - Slider

    @objc private func sliderChanged(_ slider: UISlider) {
        let degrees = slider.value
        currentAngle = CGFloat(degrees) * .pi / 180
        imageView.transform = CGAffineTransform(rotationAngle: currentAngle)
        angleLabel.text = String(format: "%.1f°", degrees)
    }

    @objc private func resetRotation() {
        currentAngle = 0
        rotationSlider.setValue(0, animated: true)
        angleLabel.text = "0°"
        UIView.animate(withDuration: 0.2) {
            self.imageView.transform = .identity
        }
    }

    // MARK: - Pan Gesture（枠の移動・リサイズ）

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
        if CGRect(x: f.minX - hs/2, y: f.minY - hs/2, width: hs, height: hs).contains(point) { return .resizeTopLeft }
        if CGRect(x: f.maxX - hs/2, y: f.minY - hs/2, width: hs, height: hs).contains(point) { return .resizeTopRight }
        if CGRect(x: f.minX - hs/2, y: f.maxY - hs/2, width: hs, height: hs).contains(point) { return .resizeBottomLeft }
        if CGRect(x: f.maxX - hs/2, y: f.maxY - hs/2, width: hs, height: hs).contains(point) { return .resizeBottomRight }
        if f.contains(point) { return .move }
        return .none
    }

    private func updateCropFrame(dx: CGFloat, dy: CGFloat) {
        // 制限範囲：画像の表示範囲（回転を考慮してbaseImageFrameを使用）
        let img = imageView.frame
        var f = dragStartCropFrame

        switch dragMode {
        case .move:
            f.origin.x += dx
            f.origin.y += dy

        case .resizeTopLeft:
            let delta = (dx + dy) / 2
            let newSize = max(minBoxSize, f.width - delta)
            let sizeDiff = newSize - f.width
            f.origin.x -= sizeDiff
            f.origin.y -= sizeDiff
            f.size = CGSize(width: newSize, height: newSize)

        case .resizeTopRight:
            let delta = (-dx + dy) / 2
            let newSize = max(minBoxSize, f.width - delta)
            let sizeDiff = newSize - f.width
            f.origin.y -= sizeDiff
            f.size = CGSize(width: newSize, height: newSize)

        case .resizeBottomLeft:
            let delta = (dx - dy) / 2
            let newSize = max(minBoxSize, f.width - delta)
            let sizeDiff = newSize - f.width
            f.origin.x -= sizeDiff
            f.size = CGSize(width: newSize, height: newSize)

        case .resizeBottomRight:
            let delta = -(dx + dy) / 2
            let newSize = max(minBoxSize, f.width - delta)
            f.size = CGSize(width: newSize, height: newSize)

        case .none:
            return
        }

        // 画像範囲内に制限
        f.origin.x = max(img.minX, min(f.origin.x, img.maxX - f.width))
        f.origin.y = max(img.minY, min(f.origin.y, img.maxY - f.height))
        f.size.width  = min(f.width,  img.maxX - f.origin.x)
        f.size.height = min(f.height, img.maxY - f.origin.y)
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

    // MARK: - Crop（回転を考慮して切り抜き）

    private func cropImage() -> UIImage {
        guard let img = sourceImage?.fixedOrientation() else { return UIImage() }

        let imgW = img.size.width
        let imgH = img.size.height

        // 回転込みで描画したUIImageを生成
        let rotatedImage = imageRotated(img, angle: currentAngle)

        // rotatedImage上でのcropFrameの位置を計算
        // imageView.frame（回転後のbounding box）とrotatedImageのサイズは一致する
        let dispFrame = imageView.frame
        let scaleX = rotatedImage.size.width  / dispFrame.width
        let scaleY = rotatedImage.size.height / dispFrame.height

        let relX = cropFrame.origin.x - dispFrame.origin.x
        let relY = cropFrame.origin.y - dispFrame.origin.y

        let srcX = relX * scaleX
        let srcY = relY * scaleY
        let srcW = cropFrame.width  * scaleX
        let srcH = cropFrame.height * scaleY

        let clampedX = max(0, min(srcX, rotatedImage.size.width  - srcW))
        let clampedY = max(0, min(srcY, rotatedImage.size.height - srcH))
        let clampedW = min(srcW, rotatedImage.size.width  - clampedX)
        let clampedH = min(srcH, rotatedImage.size.height - clampedY)

        let rect = CGRect(x: clampedX, y: clampedY, width: clampedW, height: clampedH)
        guard let cgImg = rotatedImage.cgImage?.cropping(to: rect) else { return img }
        return UIImage(cgImage: cgImg)
    }

    /// 画像を指定角度で回転したUIImageを返す
    private func imageRotated(_ image: UIImage, angle: CGFloat) -> UIImage {
        guard angle != 0 else { return image }
        let imgW = image.size.width
        let imgH = image.size.height

        // 回転後のbounding boxサイズ
        let newW = abs(imgW * cos(angle)) + abs(imgH * sin(angle))
        let newH = abs(imgW * sin(angle)) + abs(imgH * cos(angle))

        UIGraphicsBeginImageContextWithOptions(CGSize(width: newW, height: newH), false, image.scale)
        guard let ctx = UIGraphicsGetCurrentContext() else { return image }
        ctx.translateBy(x: newW / 2, y: newH / 2)
        ctx.rotate(by: angle)
        image.draw(in: CGRect(x: -imgW / 2, y: -imgH / 2, width: imgW, height: imgH))
        let result = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return result
    }
}

// MARK: - CropBoxView

class CropBoxView: UIView {
    var cropRect: CGRect = .zero
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear; isOpaque = false }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.55).cgColor)
        ctx.fill(rect)
        ctx.setBlendMode(.clear)
        ctx.fill(cropRect)
        ctx.setBlendMode(.normal)
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(1.5)
        ctx.stroke(cropRect)
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(0.5)
        let third = cropRect.width / 3
        for i in 1...2 {
            let x = cropRect.minX + third * CGFloat(i)
            ctx.move(to: CGPoint(x: x, y: cropRect.minY)); ctx.addLine(to: CGPoint(x: x, y: cropRect.maxY))
            let y = cropRect.minY + third * CGFloat(i)
            ctx.move(to: CGPoint(x: cropRect.minX, y: y)); ctx.addLine(to: CGPoint(x: cropRect.maxX, y: y))
        }
        ctx.strokePath()
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(4)
        let L: CGFloat = 24
        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: cropRect.minX, y: cropRect.minY + L), CGPoint(x: cropRect.minX, y: cropRect.minY), CGPoint(x: cropRect.minX + L, y: cropRect.minY)),
            (CGPoint(x: cropRect.maxX - L, y: cropRect.minY), CGPoint(x: cropRect.maxX, y: cropRect.minY), CGPoint(x: cropRect.maxX, y: cropRect.minY + L)),
            (CGPoint(x: cropRect.minX, y: cropRect.maxY - L), CGPoint(x: cropRect.minX, y: cropRect.maxY), CGPoint(x: cropRect.minX + L, y: cropRect.maxY)),
            (CGPoint(x: cropRect.maxX - L, y: cropRect.maxY), CGPoint(x: cropRect.maxX, y: cropRect.maxY), CGPoint(x: cropRect.maxX, y: cropRect.maxY - L)),
        ]
        for (p1, p2, p3) in corners { ctx.move(to: p1); ctx.addLine(to: p2); ctx.addLine(to: p3) }
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
