import Foundation

enum LinkMetadataFetcher {
    /// Fetches a page title and favicon data for a link attachment.
    /// Runs off the main thread; on failure leaves the attachment unchanged
    /// (never blocks capture).
    static func fetch(for url: URL) async -> (title: String?, favicon: Data?) {
        let title = await fetchTitle(for: url)
        let faviconData = await fetchFavicon(for: url)
        return (title, faviconData)
    }

    private static func fetchTitle(for url: URL) async -> String? {
        guard let htmlData = try? await fetchData(from: url),
              let html = String(data: htmlData, encoding: .utf8) else {
            return nil
        }
        return parseTitle(from: html)
    }

    private static func fetchFavicon(for url: URL) async -> Data? {
        guard let faviconURL = URL(string: "/favicon.ico", relativeTo: url)?.standardized else {
            return nil
        }
        return try? await fetchData(from: faviconURL)
    }

    private static func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 8
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    private static func parseTitle(from html: String) -> String? {
        let nsText = html as NSString
        guard let regex = try? NSRegularExpression(
            pattern: "<title[^>]*>(.*?)</title>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }

        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: html, options: [], range: range) else { return nil }

        let inner = nsText.substring(with: match.range(at: 1))
        let stripped = inner.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}