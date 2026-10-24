import Foundation
import Combine
import SwiftUI

final class SourceStore: ObservableObject {
    static let shared = SourceStore()

    @Published private(set) var sources: [RepositorySource] = []
    @Published private(set) var catalog: [UUID: [RepositoryApp]] = [:]
    @Published private(set) var loading: Set<UUID> = []
    @Published private(set) var failed: Set<UUID> = []

    private let defaults = UserDefaults.standard
    private let key = "AshteMobile.repositorySources"

    /// The built-in Ashte source that ships with the app.
    static let defaultSourceURL = URL(string: "https://github.com/ios94/ashtejson/raw/refs/heads/main/ashtemobile94.json")!
    private static let defaultSourceID = UUID(uuidString: "A5470000-0000-4000-8000-000000000094")!
    private let removedKey = "AshteMobile.defaultSourceRemoved"

    private init() {
        sources = load()
        ensureDefaultSource()
        Task { await refreshAll() }
    }

    /// Makes sure the Ashte source is in the list, unless the user deliberately removed it.
    func ensureDefaultSource() {
        guard !defaults.bool(forKey: removedKey) else { return }
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
        let current = await MainActor.run { self.sources }
        await withTaskGroup(of: Void.self) { group in
            for source in current {
                group.addTask { await self.refresh(source) }
            }
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
        if source.url == Self.defaultSourceURL {
            defaults.set(true, forKey: removedKey)
        }
        withAnimation(.easeOut(duration: 0.25)) {
            sources.removeAll { $0.id == source.id }
        }
        catalog.removeValue(forKey: source.id)
        persist()
    }

    func removeAll() {
        defaults.removeObject(forKey: removedKey)
        withAnimation(.easeOut(duration: 0.25)) {
            sources.removeAll()
        }
        catalog.removeAll()
        persist()
        ensureDefaultSource()
        Task { await refreshAll() }
    }

    func refresh(_ source: RepositorySource) async {
        await MainActor.run {
            loading.insert(source.id)
            failed.remove(source.id)
        }
        let payload = try? await RepositoryService.fetch(url: source.url)
        await MainActor.run {
            loading.remove(source.id)
            guard let payload else {
                failed.insert(source.id)
                return
            }
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
