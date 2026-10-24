import SwiftUI
import UIKit

final class RemoteImageCache {
    static let shared = RemoteImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }
    func store(_ image: UIImage, for url: URL) { cache.setObject(image, forKey: url as NSURL) }
}

/// App icon loaded from the network, cached in memory, with a tidy lettered fallback.
struct RemoteIcon: View {
    let url: URL?
    let name: String
    var cornerRadius: CGFloat = 14

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(SIColor.border.opacity(0.6), lineWidth: 0.5)
        )
        .task(id: url) { await load() }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [SIColor.accent.opacity(0.40), SIColor.accent.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
                .font(.system(.title2, design: .rounded).weight(.bold))
                .minimumScaleFactor(0.4)
                .foregroundStyle(SIColor.accent)
        }
    }

    private func load() async {
        guard let url else { return }
        if let cached = RemoteImageCache.shared.image(for: url) {
            image = cached
            return
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 30
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let loaded = UIImage(data: data) else { return }
        RemoteImageCache.shared.store(loaded, for: url)
        image = loaded
    }
}

/// Coloured rounded-square icon used in settings-style rows.
struct SIIconBadge: View {
    let systemName: String
    var color: Color = SIColor.accent

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SettingsLabel: View {
    let title: LocalizedStringKey
    let icon: String
    var color: Color = SIColor.accent
    var value: String?

    var body: some View {
        HStack(spacing: SISpacing.md) {
            SIIconBadge(systemName: icon, color: color)
            Text(title).foregroundStyle(SIColor.textPrimary)
            Spacer(minLength: 8)
            if let value {
                Text(value).foregroundStyle(SIColor.textSecondary)
            }
        }
    }
}

extension View {
    /// Card-style background for rows inside a Form or List section.
    func siRowBackground() -> some View {
        listRowBackground(SIColor.surface)
    }
}
