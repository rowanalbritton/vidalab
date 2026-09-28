import Foundation
import Supabase

/// Fetches guide recordings from the public `meditation-audio` bucket and
/// keeps them in Caches, so a session heard once plays offline after that.
///
/// Nothing about the member is sent: these are plain downloads of the same
/// files everyone gets, with no account token attached.
@MainActor
@Observable
final class GuideAudioService {
    static let shared = GuideAudioService()

    private(set) var manifest: VoicedManifest?

    private let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("meditation-audio", isDirectory: true)

    private var manifestFile: URL { cacheRoot.appendingPathComponent("manifest.json") }

    enum AudioError: Error { case unavailable }

    func publicURL(_ path: String) -> URL? {
        try? vidaSupabase.storage.from(VoicedLibrary.bucket).getPublicURL(path: path)
    }

    /// The newest manifest, or the cached one when offline.
    func loadManifest() async -> VoicedManifest? {
        if let manifest { return manifest }
        if let url = publicURL("manifest.json") {
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
            if let (data, response) = try? await URLSession.shared.data(for: request),
               (response as? HTTPURLResponse)?.statusCode == 200,
               let decoded = try? JSONDecoder().decode(VoicedManifest.self, from: data) {
                try? FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
                try? data.write(to: manifestFile, options: .atomic)
                manifest = decoded
                return decoded
            }
        }
        if let data = try? Data(contentsOf: manifestFile),
           let cached = try? JSONDecoder().decode(VoicedManifest.self, from: data) {
            manifest = cached
            return cached
        }
        return nil
    }

    /// A local file for this guide and session, downloading it if needed.
    func audio(guide: String, session: String) async throws -> (file: URL, entry: VoicedManifest.Entry) {
        guard let entry = await loadManifest()?.entry(guide: guide, session: session) else { throw AudioError.unavailable }
        let local = cacheRoot.appendingPathComponent(entry.path)
        if FileManager.default.fileExists(atPath: local.path) { return (local, entry) }

        guard let remote = publicURL(entry.path) else { throw AudioError.unavailable }
        let request = URLRequest(url: remote, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25)
        let (download, response) = try await URLSession.shared.download(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AudioError.unavailable }
        try FileManager.default.createDirectory(at: local.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: local)
        try FileManager.default.moveItem(at: download, to: local)
        return (local, entry)
    }

    /// Previews stream the start of Arrive for a guide.
    func previewURL(guide: String) -> URL? {
        publicURL("\(guide)/arrive.m4a")
    }
}
