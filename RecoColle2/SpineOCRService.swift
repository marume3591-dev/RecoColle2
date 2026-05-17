import UIKit
import Vision

final class SpineOCRService {

    // MARK: - Public

    func recognize(from image: UIImage,
                   completion: @escaping (SearchHint) -> Void) {

        recognizeMultiAngle(image: image) { texts in
            let normalized = self.normalize(texts)
            let deduped = self.removeDuplicates(normalized)

            // カタログ番号だけ抽出
            let catnos = self.extractCatalogNumbers(from: deduped)

            completion(
                SearchHint(
                    rawTexts: deduped,
                    catno: catnos.first
                )
            )
        }
    }

    // MARK: - OCR (multi angle)

    private func recognizeMultiAngle(image: UIImage,
                                     completion: @escaping ([String]) -> Void) {

        let angles: [CGFloat] = [0, .pi / 2, .pi, 3 * .pi / 2]
        var results: [String] = []
        let group = DispatchGroup()

        for angle in angles {
            group.enter()
            let rotated = image.rotated(by: angle)
            recognize(image: rotated) { texts in
                results.append(contentsOf: texts)
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(results)
        }
    }

    private func recognize(image: UIImage,
                           completion: @escaping ([String]) -> Void) {

        guard let cgImage = image.cgImage else {
            completion([])
            return
        }

        let request = VNRecognizeTextRequest { request, _ in
            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let texts = observations.compactMap {
                $0.topCandidates(1).first?.string
            }
            completion(texts)
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.02
        request.recognitionLanguages = ["en", "ja"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }

    // MARK: - Normalize

    private func normalize(_ texts: [String]) -> [String] {
        texts
            .map {
                $0
                    .uppercased()
                    .replacingOccurrences(of: "|", with: " ")
                    .replacingOccurrences(of: "•", with: " ")
                    .replacingOccurrences(of: "・", with: " ")
                    .replacingOccurrences(of: "\\s+", with: " ",
                                          options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { $0.count >= 3 }
    }

    // MARK: - Dedup

    private func removeDuplicates(_ texts: [String]) -> [String] {
        var seen = Set<String>()
        return texts.filter { seen.insert($0).inserted }
    }

    // MARK: - Catalog No

    private func extractCatalogNumbers(from texts: [String]) -> [String] {
        let pattern = #"([A-Z]{2,}\s?-?\s?\d{3,6})"#
        let regex = try! NSRegularExpression(pattern: pattern)

        return texts.compactMap { text in
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range) {
                return (text as NSString).substring(with: match.range)
            }
            return nil
        }
    }
}

// MARK: - Models

struct SearchHint {
    let rawTexts: [String]
    let catno: String?
}

// MARK: - UIImage Rotate

extension UIImage {
    func rotated(by radians: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            ctx.cgContext.translateBy(x: size.width / 2,
                                      y: size.height / 2)
            ctx.cgContext.rotate(by: radians)
            draw(in: CGRect(x: -size.width / 2,
                             y: -size.height / 2,
                             width: size.width,
                             height: size.height))
        }
    }
}
