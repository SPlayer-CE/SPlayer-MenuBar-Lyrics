import AppKit
import SwiftUI

/// 歌词项弹出的歌曲信息面板
@MainActor
final class TrackInfoPopoverController {
    private let popover = NSPopover()

    init(client: SPlayerClient) {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 340, height: 220)
        popover.contentViewController = NSHostingController(
            rootView: TrackInfoView(client: client)
        )
    }

    func show(relativeTo button: NSStatusBarButton) {
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    var isShown: Bool { popover.isShown }

    func close() {
        popover.performClose(nil)
    }
}

private struct TrackInfoView: View {
    @ObservedObject var client: SPlayerClient

    var body: some View {
        Group {
            if let track = client.track {
                content(for: track)
            } else {
                Text(L10n.t(.statusConnectedIdle))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
        .frame(width: 340, height: 220)
    }

    private func content(for track: Track) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                artwork(for: track)
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(2)
                    Text(track.artistsText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(track.albumText)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    if let comment = track.comment, !comment.isEmpty {
                        Text(comment)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }

            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                VStack(spacing: 4) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                    HStack {
                        Text(format(client.currentPositionMs))
                        Spacer()
                        Text(format(durationMs(for: track)))
                    }
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 14) {
                Button {
                    client.previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                }
                Button {
                    client.togglePlayback()
                } label: {
                    Image(systemName: client.isPlaying ? "pause.fill" : "play.fill")
                }
                Button {
                    client.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                }
                Spacer()
                Button(L10n.t(.openSPlayer)) {
                    SPlayerConfigReader.activate()
                }
                .controlSize(.small)
            }
            .buttonStyle(.borderless)
        }
    }

    private func artwork(for track: Track) -> some View {
        Group {
            if let url = track.artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }
        }
        .frame(width: 76, height: 76)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
    }

    private var placeholderArtwork: some View {
        ZStack {
            Color.secondary.opacity(0.12)
            Image(systemName: "music.note")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var progress: Double {
        guard let track = client.track,
              let duration = track.durationSeconds,
              duration > 0 else { return 0 }
        return min(max(client.currentPositionMs / 1000 / duration, 0), 1)
    }

    private func durationMs(for track: Track) -> Double {
        (track.durationSeconds ?? 0) * 1000
    }

    private func format(_ milliseconds: Double) -> String {
        let total = max(0, Int(milliseconds / 1000))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
