import Foundation

enum JSONStore {
    /// Storage directory name under Application Support. Was "Focus" (the
    /// placeholder app name from PRD §7); renamed to match the shipped app
    /// "Loopin". A one-time migration in `migrateLegacyDirectory()` carries
    /// any pre-existing user data across.
    private static let directoryName = "Loopin"
    private static let legacyDirectoryName = "Focus"
    private static let imagesDirectoryName = "Images"
    private static let documentsDirectoryName = "Documents"

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        migrateLegacyDirectory(base: base, current: dir)
        return dir
    }

    /// One-time migration: if a legacy "Focus" directory exists and the new
    /// "Loopin" directory does not yet carry that data, move the legacy files
    /// over so users don't lose settings/tasks across the rename.
    private static func migrateLegacyDirectory(base: URL, current: URL) {
        let fm = FileManager.default
        let legacy = base.appendingPathComponent(legacyDirectoryName, isDirectory: true)
        guard fm.fileExists(atPath: legacy.path) else { return }
        guard let legacyItems = try? fm.contentsOfDirectory(atPath: legacy.path), !legacyItems.isEmpty else {
            // Empty legacy dir: nothing to migrate.
            return
        }
        for item in legacyItems {
            let src = legacy.appendingPathComponent(item)
            let dst = current.appendingPathComponent(item)
            // Never overwrite something the user created in the new location.
            if fm.fileExists(atPath: dst.path) { continue }
            try? fm.moveItem(at: src, to: dst)
        }
        // Remove the legacy directory only once it's emptied.
        if let remaining = try? fm.contentsOfDirectory(atPath: legacy.path), remaining.isEmpty {
            try? fm.removeItem(at: legacy)
        }
    }

    static var imagesDirectory: URL {
        let dir = directory.appendingPathComponent(imagesDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Directory for generic (non-image) document attachments (§4.3).
    static var documentsDirectory: URL {
        let dir = directory.appendingPathComponent(documentsDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func load<T: Decodable>(_ type: T.Type, from file: String) -> T? {
        let url = directory.appendingPathComponent(file)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func save<T: Encodable>(_ value: T, to file: String) {
        let url = directory.appendingPathComponent(file)
        guard let data = try? JSONEncoder.encoder.encode(value) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    static func writeImage(_ data: Data, named fileName: String) -> Bool {
        let url = imagesDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            return false
        }
    }

    static func readImage(named fileName: String) -> Data? {
        let url = imagesDirectory.appendingPathComponent(fileName)
        return try? Data(contentsOf: url)
    }

    /// Writes a generic document attachment (§4.3). Stores in Documents/.
    static func writeAttachment(_ data: Data, named fileName: String) -> Bool {
        let url = documentsDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            return false
        }
    }

    static func readAttachment(named fileName: String) -> Data? {
        let url = documentsDirectory.appendingPathComponent(fileName)
        return try? Data(contentsOf: url)
    }
}

extension JSONEncoder {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}