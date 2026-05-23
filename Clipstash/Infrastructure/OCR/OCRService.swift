import Foundation
import Vision
import AppKit
import os

enum OCRError: Error, Equatable {
    case invalidImage
    case visionFailed(String)
    case noText
}

actor OCRService {
    private static let log = Logger(subsystem: "com.soi.clipstash", category: "ocr")

    func recognize(pngData: Data) async -> Result<String, OCRError> {
        guard let cgImage = makeCGImage(from: pngData) else {
            return .failure(.invalidImage)
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            let lines = (request.results ?? []).compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            let text = lines.joined(separator: "\n")
            if text.isEmpty {
                return .failure(.noText)
            }
            Self.log.info("ocr recognised \(text.count, privacy: .public) chars")
            return .success(text)
        } catch {
            return .failure(.visionFailed(error.localizedDescription))
        }
    }

    private func makeCGImage(from pngData: Data) -> CGImage? {
        guard let image = NSImage(data: pngData) else { return nil }
        var rect = NSRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
