import Foundation

enum TaskSize: String, Codable, Equatable, CaseIterable {
    case big
    case medium
    case small

    var label: String {
        switch self {
        case .big: return "Big"
        case .medium: return "Medium"
        case .small: return "Small"
        }
    }

    var symbol: String {
        switch self {
        case .big: return "largecircle.fill.circle"
        case .medium: return "circle.circle"
        case .small: return "smallcircle.filled.circle"
        }
    }
}

enum TaskFraming: String, Codable, Equatable {
    case quickWin
    case doFirstNextSession
}

struct Task: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isComplete: Bool
    var createdAt: Date
    var dueDate: Date?
    var linkAttachments: [LinkAttachment]
    var imageAttachments: [ImageAttachment]
    var fileAttachments: [FileAttachment]
    var size: TaskSize?
    var sortOrder: Int
    var framing: TaskFraming?
    var firstStep: String?
    var isImportant: Bool
    var colorTag: TaskColorTag?

    init(
        id: UUID = UUID(),
        title: String,
        isComplete: Bool = false,
        createdAt: Date = Date(),
        dueDate: Date? = nil,
        linkAttachments: [LinkAttachment] = [],
        imageAttachments: [ImageAttachment] = [],
        fileAttachments: [FileAttachment] = [],
        size: TaskSize? = nil,
        sortOrder: Int = 0,
        framing: TaskFraming? = nil,
        firstStep: String? = nil,
        isImportant: Bool = false,
        colorTag: TaskColorTag? = nil
    ) {
        self.id = id
        self.title = title
        self.isComplete = isComplete
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.linkAttachments = linkAttachments
        self.imageAttachments = imageAttachments
        self.fileAttachments = fileAttachments
        self.size = size
        self.sortOrder = sortOrder
        self.framing = framing
        self.firstStep = firstStep
        self.isImportant = isImportant
        self.colorTag = colorTag
    }
}