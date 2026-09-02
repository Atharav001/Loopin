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