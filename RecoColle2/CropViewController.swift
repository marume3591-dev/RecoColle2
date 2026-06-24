//
//  CropViewController.swift
//  RecoColle2
//
//  ・写真は画面いっぱいに表示
//  ・クロップ枠を自由に移動・縦横独立リサイズ
//  ・回転スライダー（-45°〜+45°）
//  ・確定で回転＋切り抜きして返す

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
    private let imageView      = UIImageView()
    private let cropBoxView    = CropBoxView()
    private let confirmButton  = UIButton(type: .system)
    private let cancelButton   = UIButton(type: .system)
    private let rotationSlider = UISlider()
    private let rotationLabel  = UILabel()

    // 現在の回転角度（度）
    private var currentAngleDeg: Float = 0

    // 元画像（向き補正済み）
    private var fixedSource: UIImage!

    // クロップ枠
    private var cropFrame: CGRect = .zero
    private var dragStartCropFrame: CGRect = .zero
    private var dragStartPoint: CGPoint = .zero

    private enum DragMode {
        case none, move
        case resizeTop, resizeBottom, resizeLeft, resizeRight
        case resizeTopLeft, resizeTopRight, resizeBottomLeft, resizeBottomRight
    }
    private var dragMode: DragMode = .none
    private let cornerHitSize: CGFloat = 44
    private let edgeHitSize:   CGFloat = 24
    private let minSize: CGFloat = 40

    private var baseImageFrame: CGRect = .zero

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        fixedSource = sourceImage.fixedOrientation()
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

        let viewW      = view.bounds.width
        let safeTop    = view.safeAreaInsets.top
        let safeBottom = view.safeAreaInsets.bottom
        let availableH = view.bounds.height - safeTop - safeBottom - 120

        let imgW = fixedSource.size.width
        let imgH = fixedSource.size.height
        let scale = min(viewW / imgW, availableH / imgH)
        let dispW = imgW * scale
        let dispH = imgH * scale

        baseImageFrame = CGRect(
            x: (viewW - dispW) / 2,
            y: safeTop + (availableH - dispH) / 2,
            width: dispW, height: dispH
        )
        imageView.frame = baseImageFrame
        imageView.image = fixedSource

        // 初期クロップ枠：画像の80%
        let boxW = dispW * 0.8
        let boxH = dispH * 0.8
        cropFrame = CGRect(
            x: baseImageFrame.midX - boxW / 2,
            y: baseImageFrame.midY - boxH / 2,
            width: boxW, height: boxH
        )
        cropBoxView.frame    = view.bounds
        cropBoxView.cropRect = cropFrame
        cropBoxView.setNeedsDisplay()
    }

    // MARK: - Setup

    private func setupImageView() {
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = false
        view.addSubview(imageView)
    }

    private func setupCropBox() {
        cropBoxView.isUserInteractionEnabled = false
        view.addSubview(cropBoxView)
    }

    private func setupSlider() {
        let icon = UIImageView()
        icon.image = UIImage(systemName: "rotate.left",
                             withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        icon.tintColor = .lightGray
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 20).isActive = true

        rotationLabel.text = "0°"
        rotationLabel.textColor = .white
        rotationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        rotationLabel.textAlignment = .right
        rotationLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true

        rotationSlider.minimumValue   = -45
        rotationSlider.maximumValue   =  45
        rotationSlider.value          =   0
        rotationSlider.tintColor      = .white
        rotationSlider.thumbTintColor = .white
        rotationSlider.addTarget(self, action: #selector(rotationChanged(_:)), for: .valueChanged)

        let resetBtn = UIButton(type: .system)
        resetBtn.setImage(UIImage(systemName: "arrow.counterclockwise",
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)),
                          for: .normal)
        resetBtn.tintColor = .lightGray
        resetBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        resetBtn.addTarget(self, action: #selector(resetRotation), for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [icon, rotationSlider, rotationLabel, resetBtn])
        row.axis = .horizontal; row.spacing = 8; row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -56),
        ])
    }

    private func setupButtons() {
        cancelButton.setTitle(NSLocalizedString("cancel_button", comment: ""), for: .normal)
        cancelButton.tintColor = .white
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)

        confirmButton.setTitle(NSLocalizedString("crop_confirm_button", comment: ""), for: .normal)
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

    @objc private func rotationChanged(_ slider: UISlider) {
        currentAngleDeg = slider.value
        rotationLabel.text = String(format: "%.0f°", slider.value)
        // プレビューはtransformで回転するだけ（フレームサイズは変えない）
        let angle = CGFloat(slider.value) * .pi / 180
        imageView.transform = CGAffineTransform(rotationAngle: angle)
    }

    @objc private func resetRotation() {
        currentAngleDeg = 0
        rotationSlider.setValue(0, animated: true)
        rotationLabel.text = "0°"
        UIView.animate(withDuration: 0.2) {
            self.imageView.transform = .identity
        }
    }

    // MARK: - Pan Gesture

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        let point = gr.location(in: view)
        switch gr.state {
        case .began:
            dragStartPoint     = point
            dragStartCropFrame = cropFrame
            dragMode           = detectDragMode(at: point)
        case .changed:
            updateCropFrame(dx: point.x - dragStartPoint.x,
                            dy: point.y - dragStartPoint.y)
        default:
            dragMode = .none
        }
    }

    private func detectDragMode(at point: CGPoint) -> DragMode {
        let f  = cropFrame
        let hs = cornerHitSize
        let es = edgeHitSize

        // 4隅（優先）
        if CGRect(x: f.minX - hs/2, y: f.minY - hs/2, width: hs, height: hs).contains(point) { return .resizeTopLeft }
        if CGRect(x: f.maxX - hs/2, y: f.minY - hs/2, width: hs, height: hs).contains(point) { return .resizeTopRight }
        if CGRect(x: f.minX - hs/2, y: f.maxY - hs/2, width: hs, height: hs).contains(point) { return .resizeBottomLeft }
        if CGRect(x: f.maxX - hs/2, y: f.maxY - hs/2, width: hs, height: hs).contains(point) { return .resizeBottomRight }

        // 4辺
        if CGRect(x: f.minX + hs/2, y: f.minY - es/2, width: f.width - hs, height: es).contains(point) { return .resizeTop }
        if CGRect(x: f.minX + hs/2, y: f.maxY - es/2, width: f.width - hs, height: es).contains(point) { return .resizeBottom }
        if CGRect(x: f.minX - es/2, y: f.minY + hs/2, width: es, height: f.height - hs).contains(point) { return .resizeLeft }
        if CGRect(x: f.maxX - es/2, y: f.minY + hs/2, width: es, height: f.height - hs).contains(point) { return .resizeRight }

        // 内側 → 移動
        if f.contains(point) { return .move }
        return .none
    }

    private func updateCropFrame(dx: CGFloat, dy: CGFloat) {
        let img = imageView.frame
        var f   = dragStartCropFrame

        switch dragMode {
        case .move:
            f.origin.x += dx; f.origin.y += dy

        case .resizeTop:
            let newH = max(minSize, f.height - dy)
            f.origin.y += f.height - newH
            f.size.height = newH

        case .resizeBottom:
            f.size.height = max(minSize, f.height + dy)

        case .resizeLeft:
            let newW = max(minSize, f.width - dx)
            f.origin.x += f.width - newW
            f.size.width = newW

        case .resizeRight:
            f.size.width = max(minSize, f.width + dx)

        case .resizeTopLeft:
            let newW = max(minSize, f.width - dx)
            let newH = max(minSize, f.height - dy)
            f.origin.x += f.width - newW
            f.origin.y += f.height - newH
            f.size = CGSize(width: newW, height: newH)

        case .resizeTopRight:
            let newW = max(minSize, f.width + dx)
            let newH = max(minSize, f.height - dy)
            f.origin.y += f.height - newH
            f.size = CGSize(width: newW, height: newH)

        case .resizeBottomLeft:
            let newW = max(minSize, f.width - dx)
            f.origin.x += f.width - newW
            f.size = CGSize(width: newW, height: max(minSize, f.height + dy))

        case .resizeBottomRight:
            f.size = CGSize(width: max(minSize, f.width + dx), height: max(minSize, f.height + dy))

        case .none: return
        }

        // 画像範囲内に制限
        f.origin.x = max(img.minX, min(f.origin.x, img.maxX - f.width))
        f.origin.y = max(img.minY, min(f.origin.y, img.maxY - f.height))
        f.size.width  = min(f.width,  img.maxX - f.origin.x)
        f.size.height = min(f.height, img.maxY - f.origin.y)

        cropFrame = f
        cropBoxView.cropRect = f
        cropBoxView.setNeedsDisplay()
    }

    // MARK: - Actions

    @objc private func didTapCancel() { delegate?.cropViewControllerDidCancel(self) }

    @objc private func didTapConfirm() {
        // transformをリセットしてフレームを確定させてからcrop
        imageView.transform = .identity
        let rotated = imageRotated(fixedSource, angleDeg: CGFloat(currentAngleDeg))
        let cropped = cropFromImage(rotated)
        delegate?.cropViewController(self, didCrop: cropped)
    }

    // MARK: - Image Processing

    private func imageRotated(_ image: UIImage, angleDeg: CGFloat) -> UIImage {
        guard angleDeg != 0 else { return image }
        let angle = angleDeg * .pi / 180
        let w = image.size.width; let h = image.size.height
        let newW = abs(w * cos(angle)) + abs(h * sin(angle))
        let newH = abs(w * sin(angle)) + abs(h * cos(angle))
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale; format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: newW, height: newH), format: format).image { ctx in
            let c = ctx.cgContext
            c.translateBy(x: newW / 2, y: newH / 2)
            c.rotate(by: angle)
            image.draw(in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        }
    }

    private func cropFromImage(_ image: UIImage) -> UIImage {
        let dispFrame = imageView.frame
        let scaleX = image.size.width  / dispFrame.width
        let scaleY = image.size.height / dispFrame.height
        let relX = cropFrame.origin.x - dispFrame.origin.x
        let relY = cropFrame.origin.y - dispFrame.origin.y
        let srcX = relX * scaleX; let srcY = relY * scaleY
        let srcW = cropFrame.width  * scaleX
        let srcH = cropFrame.height * scaleY
        let cX = max(0, min(srcX, image.size.width  - srcW))
        let cY = max(0, min(srcY, image.size.height - srcH))
        let cW = min(srcW, image.size.width  - cX)
        let cH = min(srcH, image.size.height - cY)
        guard let cgImg = image.cgImage?.cropping(to: CGRect(x: cX, y: cY, width: cW, height: cH)) else { return image }
        return UIImage(cgImage: cgImg)
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale; format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func resizedForPreview(maxSize: CGFloat) -> UIImage {
        let maxDim = max(size.width, size.height)
        guard maxDim > maxSize else { return self }
        let s = maxSize / maxDim
        let newSize = CGSize(width: size.width * s, height: size.height * s)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1; format.opaque = false
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - CropBoxView（縦横自由な枠）

class CropBoxView: UIView {
    var cropRect: CGRect = .zero
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear; isOpaque = false }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // 暗幕
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.55).cgColor); ctx.fill(rect)
        ctx.setBlendMode(.clear); ctx.fill(cropRect); ctx.setBlendMode(.normal)

        // 枠線
        ctx.setStrokeColor(UIColor.white.cgColor); ctx.setLineWidth(1.5); ctx.stroke(cropRect)

        // グリッド線（3×3）
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.4).cgColor); ctx.setLineWidth(0.5)
        let tW = cropRect.width / 3; let tH = cropRect.height / 3
        for i in 1...2 {
            let x = cropRect.minX + tW * CGFloat(i)
            ctx.move(to: CGPoint(x: x, y: cropRect.minY)); ctx.addLine(to: CGPoint(x: x, y: cropRect.maxY))
            let y = cropRect.minY + tH * CGFloat(i)
            ctx.move(to: CGPoint(x: cropRect.minX, y: y)); ctx.addLine(to: CGPoint(x: cropRect.maxX, y: y))
        }
        ctx.strokePath()

        // コーナーハンドル
        ctx.setStrokeColor(UIColor.white.cgColor); ctx.setLineWidth(4)
        let L: CGFloat = 24
        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: cropRect.minX, y: cropRect.minY + L), CGPoint(x: cropRect.minX, y: cropRect.minY), CGPoint(x: cropRect.minX + L, y: cropRect.minY)),
            (CGPoint(x: cropRect.maxX - L, y: cropRect.minY), CGPoint(x: cropRect.maxX, y: cropRect.minY), CGPoint(x: cropRect.maxX, y: cropRect.minY + L)),
            (CGPoint(x: cropRect.minX, y: cropRect.maxY - L), CGPoint(x: cropRect.minX, y: cropRect.maxY), CGPoint(x: cropRect.minX + L, y: cropRect.maxY)),
            (CGPoint(x: cropRect.maxX - L, y: cropRect.maxY), CGPoint(x: cropRect.maxX, y: cropRect.maxY), CGPoint(x: cropRect.maxX, y: cropRect.maxY - L)),
        ]
        for (p1, p2, p3) in corners { ctx.move(to: p1); ctx.addLine(to: p2); ctx.addLine(to: p3) }
        ctx.strokePath()

        // 辺の中央ハンドル
        ctx.setFillColor(UIColor.white.cgColor)
        let midHandles: [CGPoint] = [
            CGPoint(x: cropRect.midX, y: cropRect.minY),
            CGPoint(x: cropRect.midX, y: cropRect.maxY),
            CGPoint(x: cropRect.minX, y: cropRect.midY),
            CGPoint(x: cropRect.maxX, y: cropRect.midY),
        ]
        for p in midHandles {
            ctx.fillEllipse(in: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10))
        }
    }
}
