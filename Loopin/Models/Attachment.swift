import Foundation

struct LinkAttachment: Identifiable, Codable, Equatable {
    let id: UUID
    var url: URL
    var fetchedTitle: String?
    var faviconData: Data?

    init(
        id: UUID = UUID(),
        url: URL,
        fetchedTitle: String? = nil,
        faviconData: Data? = nil
    ) {
        self.id = id
        self.url = url
        self.fetchedTitle = fetchedTitle
        self.faviconData = faviconData
    }
}

struct ImageAttachment: Identifiable, Codable, Equatable {
    let id: UUID
    var imageFileName: String

    init(id: UUID = UUID(), imageFileName: String) {
        self.id = id
        self.imageFileName = imageFileName
    }
}

/// Non-image document attachment (V1_IMPROVEMENTS §4.3/§7). Stored under
/// Application Support, same pattern as ImageAttachment.
struct FileAttachment: Identifiable, Codable, Equatable {
    let id: UUID
    var fileName: String
    /// Derived from the file's UTType/extension, shown as a non-editable tag
    /// next to the editable name field (§4.3.2). Never user-entered.
    var fileTypeTag: String

    init(id: UUID = UUID(), fileName: String, fileTypeTag: String) {
        self.id = id
        self.fileName = fileName
        self.fileTypeTag = fileTypeTag
    }

    /// Derives the type tag (e.g. "PNG", "PDF", "DOCX") from `fileName`'s
    /// path extension. Falls back to "FILE" when there is none.
    static func typeTag(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.uppercased()
        return ext.isEmpty ? "FILE" : ext
    }

    static func make(fileName: String) -> FileAttachment {
        FileAttachment(fileName: fileName, fileTypeTag: typeTag(for: fileName))
    }
}

/// Small fixed per-item accent color set (V1_IMPROVEMENTS §4.1) — a tiny preset
/// set of colors, not a full picker, matching Memorigi's "colorful tasks" look.
enum TaskColorTag: String, Codable, CaseIterable, Identifiable {
    case teal
    case coral
    case violet
    case amber
    case neutral

    var id: String { rawValue }

    var label: String {
        switch self {
        case .teal: return "Teal"
        case .coral: return "Coral"
        case .violet: return "Violet"
        case .amber: return "Amber"
        case .neutral: return "Neutral"
        }
    }
}

/// Small fixed set of icon-forward row glyphs (§4.1): user-pickable SF Symbol
/// names stored on `Task.icon`. Kept deliberately tiny for v1.
enum TaskIcon: String, CaseIterable, Identifiable {
    case star
    case book
    case folder
    case tray
    case lightbulb
    case pencil
    case cart
    case heart
    case doc

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .star: return "star"
        case .book: return "book"
        case .folder: return "folder"
        case .tray: return "tray"
        case .lightbulb: return "lightbulb"
        case .pencil: return "pencil"
        case .cart: return "cart"
        case .heart: return "heart"
        case .doc: return "doc"
        }
    }
}