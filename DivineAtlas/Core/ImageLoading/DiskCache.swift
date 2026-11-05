import CryptoKit
import Foundation

/// Size-bounded file cache with least-recently-used eviction.
///
/// Not synchronised itself; callers serialise access (`ImagePipeline` is an
/// actor). Failures are non-fatal: a broken cache behaves like an empty one.
struct DiskCache: Sendable {
    let directory: URL
    let maxBytes: Int

    init(directory: URL, maxBytes: Int) {
        self.directory = directory
        self.maxBytes = maxBytes
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// `Library/Caches/<name>` — the system may purge it under storage pressure.
    static func inCachesDirectory(named name: String, maxBytes: Int) -> DiskCache? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        return DiskCache(directory: caches.appending(path: name, directoryHint: .isDirectory), maxBytes: maxBytes)
    }

    func data(forKey key: String) -> Data? {
        let url = fileURL(forKey: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        // Touch the file so eviction treats it as recently used.
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path())
        return data
    }

    func store(_ data: Data, forKey key: String) throws {
        guard data.count <= maxBytes else { return }
        try data.write(to: fileURL(forKey: key), options: .atomic)
        trim()
    }

    /// Deletes least-recently-used files until the cache fits within `maxBytes`.
    func trim() {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys) else { return }

        var entries = files.compactMap { url -> (url: URL, size: Int, date: Date)? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }
        var total = entries.reduce(0) { $0 + $1.size }
        guard total > maxBytes else { return }

        entries.sort { $0.date < $1.date }
        for entry in entries where total > maxBytes {
            try? FileManager.default.removeItem(at: entry.url)
            total -= entry.size
        }
    }

    var totalBytes: Int {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(forKey key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appending(path: digest, directoryHint: .notDirectory)
    }
}
