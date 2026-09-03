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
}

/// Small fixed per-item accent color set (V1_IMPROVEMENTS §4.1) — a tiny preset
/// set of colors, not a full picker, matching Memorigi's "colorful tasks" look.
enum TaskColorTag: String, Codable, CaseIterable {
    case teal
    case coral
    case violet
    case amber
    case neutral
}