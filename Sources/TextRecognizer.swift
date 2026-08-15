import Foundation
import Vision

enum TextRecognizer {
    /// 中英混排。顺序影响 Vision 的语言假设，中文在前。
    static let defaultLanguages = ["zh-Hans", "en-US"]

    static func recognize(imageAt url: URL, languages: [String] = defaultLanguages) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = languages
        request.usesLanguageCorrection = true

        try VNImageRequestHandler(url: url, options: [:]).perform([request])

        guard let results = request.results else { return "" }
        return results
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}
