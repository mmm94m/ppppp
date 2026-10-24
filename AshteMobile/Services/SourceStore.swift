import Foundation
import Combine
import SwiftUI

final class SourceStore: ObservableObject {
    static let shared = SourceStore()

    @Published private(set) var sources: [RepositorySource] = []
    @Published private(set) var catalog: [UUID: [RepositoryApp]] = [:]

    private let defaults = UserDefaults.standard
    private let key = "AshteMobile.repositorySources"

    /// The built-in Ashte source that ships with the app.
    static let defaultSourceURL = URL(string: "https://github.com/ios94/ashtejson/raw/refs/heads/main/ashtemobile94.json")!
    private static let defaultSourceID = UUID(uuidString: "A5470000-0000-4000-8000-000000000094")!
    private let seededKey = "AshteMobile.defaultSourceSeeded"

    private init() {
        sources = load()
        seedDefaultSourceIfNeeded()
        Task { await refreshAll() }
    }

    /// Adds the Ashte source once, on first launch. If the user removes it later, it stays removed.
    private func seedDefaultSourceIfNeeded() {
        guard !defaults.bool(forKey: seededKey) else { return }
        defaults.set(true, forKey: seededKey)
        guard !sources.contains(where: { $0.url == Self.defaultSourceURL }) else { return }
        let source = RepositorySource(
            id: Self.defaultSourceID,
            url: Self.defaultSourceURL,
            name: "AshteMobile",
            subtitle: "ios94"
        )
        sources.insert(source, at: 0)
        persist()
    }

    /// Catalogs live in memory only, so reload every source's apps at launch.
    func refreshAll() async {
        for source in sources {
            await refresh(source)
        }
    }

    @discardableResult
    func addSource(url: URL) async throws -> RepositorySource {
        let payload = try await RepositoryService.fetch(url: url)
        let source = RepositorySource(
            url: url,
            name: payload.name ?? url.host ?? url.absoluteString,
            subtitle: payload.subtitle ?? payload.description,
            iconURL: payload.iconURL,
            lastRefreshedAt: Date(),
            appCount: payload.apps.count
        )
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.25)) {
                sources.append(source)
            }
            catalog[source.id] = payload.apps
            persist()
        }
        return source
    }

    func removeSource(_ source: RepositorySource) {
        withAnimation(.easeOut(duration: 0.25)) {
            sources.removeAll { $0.id == source.id }
        }
        catalog.removeValue(forKey: source.id)
        persist()
    }

    func removeAll() {
        withAnimation(.easeOut(duration: 0.25)) {
            sources.removeAll()
        }
        catalog.removeAll()
        persist()
    }

    func refresh(_ source: RepositorySource) async {
        guard let payload = try? await RepositoryService.fetch(url: source.url) else { return }
        await MainActor.run {
            guard let index = sources.firstIndex(where: { $0.id == source.id }) else { return }
            sources[index].lastRefreshedAt = Date()
            sources[index].appCount = payload.apps.count
            if let name = payload.name, !name.isEmpty { sources[index].name = name }
            if let subtitle = payload.subtitle ?? payload.description { sources[index].subtitle = subtitle }
            if let icon = payload.iconURL { sources[index].iconURL = icon }
            catalog[source.id] = payload.apps
            persist()
        }
    }

    func apps(for source: RepositorySource) -> [RepositoryApp] {
        catalog[source.id] ?? []
    }

    private func load() -> [RepositorySource] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([RepositorySource].self, from: data)) ?? []
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(sources) else { return }
        defaults.set(data, forKey: key)
    }
}
