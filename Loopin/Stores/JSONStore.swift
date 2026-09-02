import Foundation

enum JSONStore {
    private static let directoryName = "Focus"
    private static let imagesDirectoryName = "Images"

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var imagesDirectory: URL {
        let dir = directory.appendingPathComponent(imagesDirectoryName, isDirectory: true)
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