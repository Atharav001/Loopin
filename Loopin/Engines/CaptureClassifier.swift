import Foundation
import AppKit

struct ClassifiedContent {
    var titleText: String
    var url: URL?
    var imageFileName: String?
    var dueDate: Date?
    var rawPasteboardText: String
}

enum CaptureClassifier {
    /// Order: image data → URL type/pattern → date → remaining text.
    /// Never throws; malformed or unexpected pasteboard content degrades to a plain text task.
    static func classify(pasteboard: NSPasteboard) -> ClassifiedContent {
        let rawText = pasteboard.string(forType: .string) ?? ""

        // 1. Image data (tiff/png) — write to disk, record filename.
        if let imageFileName = captureImage(from: pasteboard) {
            return ClassifiedContent(
                titleText: "Image",
                url: nil,
                imageFileName: imageFileName,
                dueDate: nil,
                rawPasteboardText: rawText
            )
        }

        // 2. URL type or link pattern via NSDataDetector.
        if let url = extractURL(from: pasteboard, text: rawText) {
            let title = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            return ClassifiedContent(
                titleText: title.isEmpty ? (url.host?.isEmpty == false ? url.absoluteString : "Link") : title,
                url: url,
                imageFileName: nil,
                dueDate: nil,
                rawPasteboardText: rawText
            )
        }

        // 3. Date via NSDataDetector — remove matched substring from title.
        var remaining = rawText
        let dueDate = extractDate(from: &remaining)

        let cleanedTitle = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
        return ClassifiedContent(
            titleText: cleanedTitle.isEmpty ? "New task" : cleanedTitle,
            url: nil,
            imageFileName: nil,
            dueDate: dueDate,
            rawPasteboardText: rawText
        )
    }

    /// Plain-typed text path (no image). Detects an inline URL or a
    /// natural-language date and strips the date phrase from the title.
    static func classifyText(_ text: String) -> ClassifiedContent {
        if let url = extractURL(fromText: text) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return ClassifiedContent(
                titleText: trimmed.isEmpty ? url.absoluteString : trimmed,
                url: url,
                imageFileName: nil,
                dueDate: nil,
                rawPasteboardText: text
            )
        }

        var remaining = text
        let dueDate = extractDate(from: &remaining)
        let cleanedTitle = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
        return ClassifiedContent(
            titleText: cleanedTitle.isEmpty ? "New task" : cleanedTitle,
            url: nil,
            imageFileName: nil,
            dueDate: dueDate,
            rawPasteboardText: text
        )
    }

    private static func captureImage(from pasteboard: NSPasteboard) -> String? {
        let fileType = pasteboard.availableType(from: [.tiff, .png])
        guard let fileType,
              let imageData = pasteboard.data(forType: fileType) else { return nil }

        let fileName = "\(UUID().uuidString).png"
        guard JSONStore.writeImage(imageData, named: fileName) else { return nil }
        return fileName
    }

    private static func extractURL(from pasteboard: NSPasteboard, text: String) -> URL? {
        if let urlType = pasteboard.availableType(from: [.URL]),
           let urlString = pasteboard.string(forType: urlType),
           let url = URL(string: urlString) {
            return url
        }
        return extractURL(fromText: text)
    }

    private static func extractURL(fromText text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let matches = detector.matches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: (text as NSString).length)
        )
        if let match = matches.first, let url = match.url {
            return url
        }
        return nil
    }

    private static func extractDate(from text: inout String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = detector.firstMatch(in: text, options: [], range: range),
              let date = match.date else {
            return nil
        }

        let matchedRange = match.range
        text = nsText.replacingCharacters(in: matchedRange, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return date
    }
}