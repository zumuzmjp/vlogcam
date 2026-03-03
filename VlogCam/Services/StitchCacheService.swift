import Foundation
import CryptoKit

struct StitchCacheEntry: Codable, Identifiable {
    var id: String { cacheKey }
    let cacheKey: String
    let albumTitle: String
    let pageLabel: String?
    let clipCount: Int
    let totalDuration: Double
    let fileName: String
    let createdAt: Date

    var fileURL: URL {
        URL.stitchedDirectory.appending(component: fileName)
    }

    var fileExists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path())
    }
}

final class StitchCacheService {
    static let shared = StitchCacheService()

    private let manifestURL = URL.stitchedDirectory.appending(component: "manifest.json")
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        try? URL.ensureDirectoryExists(URL.stitchedDirectory)
    }

    // MARK: - Cache Key

    func cacheKey(for clips: [VideoClip]) -> String {
        let joined = clips.map(\.fileName).joined(separator: "|")
        let hash = SHA256.hash(data: Data(joined.utf8))
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Lookup

    func cachedEntry(for clips: [VideoClip]) -> StitchCacheEntry? {
        let key = cacheKey(for: clips)
        let entries = loadManifest()
        guard let entry = entries.first(where: { $0.cacheKey == key }), entry.fileExists else {
            return nil
        }
        return entry
    }

    // MARK: - Save

    func save(cacheKey: String, albumTitle: String, pageLabel: String?, clipCount: Int, totalDuration: Double, fileURL: URL) {
        let fileName = fileURL.lastPathComponent
        let entry = StitchCacheEntry(
            cacheKey: cacheKey,
            albumTitle: albumTitle,
            pageLabel: pageLabel,
            clipCount: clipCount,
            totalDuration: totalDuration,
            fileName: fileName,
            createdAt: .now
        )
        var entries = loadManifest()
        entries.removeAll { $0.cacheKey == cacheKey }
        entries.insert(entry, at: 0)
        saveManifest(entries)
    }

    // MARK: - History

    func history() -> [StitchCacheEntry] {
        loadManifest().filter(\.fileExists)
    }

    // MARK: - Delete

    func delete(_ entry: StitchCacheEntry) {
        try? FileManager.default.removeItem(at: entry.fileURL)
        var entries = loadManifest()
        entries.removeAll { $0.cacheKey == entry.cacheKey }
        saveManifest(entries)
    }

    func clearAll() {
        let entries = loadManifest()
        for entry in entries {
            try? FileManager.default.removeItem(at: entry.fileURL)
        }
        saveManifest([])
    }

    // MARK: - Manifest I/O

    private func loadManifest() -> [StitchCacheEntry] {
        guard let data = try? Data(contentsOf: manifestURL),
              let entries = try? decoder.decode([StitchCacheEntry].self, from: data) else {
            return []
        }
        return entries
    }

    private func saveManifest(_ entries: [StitchCacheEntry]) {
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: manifestURL, options: .atomic)
    }
}
