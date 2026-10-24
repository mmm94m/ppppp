import Foundation
import SwiftUI

struct RepositorySource: Identifiable, Codable, Hashable {
    let id: UUID
    var url: URL
    var name: String
    var subtitle: String?
    var iconURL: URL?
    var addedAt: Date
    var lastRefreshedAt: Date?
    var appCount: Int

    init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        subtitle: String? = nil,
        iconURL: URL? = nil,
        addedAt: Date = Date(),
        lastRefreshedAt: Date? = nil,
        appCount: Int = 0
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.subtitle = subtitle
        self.iconURL = iconURL
        self.addedAt = addedAt
        self.lastRefreshedAt = lastRefreshedAt
        self.appCount = appCount
    }
}

struct RepositoryPayload: Decodable {
    let name: String?
    let identifier: String?
    let subtitle: String?
    let description: String?
    let iconURL: URL?
    let headerURL: URL?
    let website: URL?
    let apps: [RepositoryApp]

    private enum CodingKeys: String, CodingKey {
        case name, identifier, subtitle, description, iconURL, headerURL, website, apps
        case sourceiconURL, sourceicon, icon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        let primaryIcon = try container.decodeIfPresent(URL.self, forKey: .iconURL)
        let altIcon = try container.decodeIfPresent(URL.self, forKey: .sourceiconURL)
        let legacyIcon = try container.decodeIfPresent(URL.self, forKey: .sourceicon)
        let plainIcon = try container.decodeIfPresent(URL.self, forKey: .icon)
        iconURL = primaryIcon ?? altIcon ?? legacyIcon ?? plainIcon
        headerURL = try container.decodeIfPresent(URL.self, forKey: .headerURL)
        website = try container.decodeIfPresent(URL.self, forKey: .website)
        apps = Self.decodeApps(from: container)
    }

    private static func decodeApps(from container: KeyedDecodingContainer<CodingKeys>) -> [RepositoryApp] {
        guard var unkeyedContainer = try? container.nestedUnkeyedContainer(forKey: .apps) else { return [] }
        var apps: [RepositoryApp] = []
        let entryCount = unkeyedContainer.count ?? 0
        var iterations = 0
        while !unkeyedContainer.isAtEnd && iterations < entryCount {
            iterations += 1
            if let app = try? unkeyedContainer.decode(RepositoryApp.self) {
                apps.append(app)
            }
        }
        return apps
    }
}

enum AppCategory: String, CaseIterable, Identifiable, Hashable {
    case all, tools, games, media, social

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .all: return "All"
        case .tools: return "Tools"
        case .games: return "Games"
        case .media: return "Media"
        case .social: return "Social"
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "square.stack.3d.up.fill"
        case .tools: return "wrench.and.screwdriver.fill"
        case .games: return "gamecontroller.fill"
        case .media: return "film.fill"
        case .social: return "bubble.left.and.bubble.right.fill"
        }
    }

    private static let socialKeys = ["instagram", "facebook", "messenger", "whatsapp", "telegra", "tweetie", "twitter", "snap", "picaboo", "reddit", "discord", "barcelona", "threads", "tellm", "jodel", "fun.ask", "nicegram", "turrit", "swiftgram", "teledark", "signal", "viber", "wechat", "linkedin", "pinterest", "tumblr", "bereal", "line.", "social", "messag", "chat"]
    private static let mediaKeys = ["youtube", "musically", "tiktok", "twitch", "music", "spotify", "netflix", "video", "movie", "stream", "podcast", "photo", "camera", "entertain", "media", "player"]

    /// Sorts an app into one of the browse tabs from whatever the source tells us.
    static func classify(category: String?, bundleIdentifier: String, name: String) -> AppCategory {
        let cat = (category ?? "").lowercased()
        if cat.contains("game") || cat.contains("emulat") { return .games }
        let haystack = (bundleIdentifier + " " + name).lowercased()
        if socialKeys.contains(where: { haystack.contains($0) }) { return .social }
        if mediaKeys.contains(where: { haystack.contains($0) }) { return .media }
        if cat.contains("social") || cat.contains("messag") { return .social }
        if cat.contains("entertain") || cat.contains("video") || cat.contains("music") || cat.contains("photo") { return .media }
        return .tools
    }
}

struct RepositoryApp: Decodable, Identifiable, Hashable {
    let name: String
    let bundleIdentifier: String
    let developerName: String?
    let subtitle: String?
    let localizedDescription: String?
    let iconURL: URL?
    let versions: [RepositoryAppVersion]
    let category: String?
    let kind: AppCategory

    var id: String { bundleIdentifier + "|" + name + "|" + (versions.first?.version ?? "") }

    var latest: RepositoryAppVersion? { versions.first }

    private enum CodingKeys: String, CodingKey {
        case name, bundleIdentifier, developerName, subtitle, localizedDescription
        case iconURL, icon, versions, version, downloadURL, size, versionDate
        case minOSVersion, versionDescription, absoluteVersion
        case image, imageURL, logo, iconUrl, iconurl
        case category, type
    }

    private static func lenientURL(_ container: KeyedDecodingContainer<CodingKeys>, _ keys: [CodingKeys]) -> URL? {
        for key in keys {
            guard let raw = try? container.decodeIfPresent(String.self, forKey: key) else { continue }
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if let url = URL(string: text) { return url }
            if let encoded = text.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed.union(CharacterSet(charactersIn: "#"))),
               let url = URL(string: encoded) {
                return url
            }
        }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decode(String.self, forKey: .name)) ?? String(localized: "Untitled app")
        bundleIdentifier = (try? container.decode(String.self, forKey: .bundleIdentifier)) ?? ""
        developerName = try? container.decodeIfPresent(String.self, forKey: .developerName)
        subtitle = try? container.decodeIfPresent(String.self, forKey: .subtitle)
        localizedDescription = try? container.decodeIfPresent(String.self, forKey: .localizedDescription)
        iconURL = Self.lenientURL(container, [.iconURL, .icon, .iconUrl, .iconurl, .imageURL, .image, .logo])
        let rawCategory = (try? container.decodeIfPresent(String.self, forKey: .category))
            ?? (try? container.decodeIfPresent(String.self, forKey: .type))
        category = rawCategory ?? nil
        kind = AppCategory.classify(category: category, bundleIdentifier: bundleIdentifier, name: name)

        if let parsed = try? container.decode([RepositoryAppVersion].self, forKey: .versions), !parsed.isEmpty {
            versions = parsed
        } else if let download = try? container.decode(URL.self, forKey: .downloadURL) {
            let single = RepositoryAppVersion(
                version: (try? container.decode(String.self, forKey: .version)) ?? "1.0",
                date: try? container.decodeIfPresent(String.self, forKey: .versionDate),
                localizedDescription: try? container.decodeIfPresent(String.self, forKey: .versionDescription),
                downloadURL: download,
                size: (try? container.decodeIfPresent(Int64.self, forKey: .size)) ?? nil,
                minOSVersion: try? container.decodeIfPresent(String.self, forKey: .minOSVersion)
            )
            versions = [single]
        } else {
            versions = []
        }
    }
}

struct RepositoryAppVersion: Decodable, Hashable {
    let version: String
    let date: String?
    let localizedDescription: String?
    let downloadURL: URL
    let size: Int64?
    let minOSVersion: String?

    var displaySize: String? {
        guard let size else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var displayDate: String? {
        guard let date else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let parsed = iso.date(from: date) ?? ISO8601DateFormatter().date(from: date)
        guard let parsed else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: parsed)
    }
}
