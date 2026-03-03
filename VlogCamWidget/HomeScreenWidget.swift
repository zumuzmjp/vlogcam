import SwiftUI
import WidgetKit

struct HomeScreenProvider: TimelineProvider {
    func placeholder(in context: Context) -> HomeScreenEntry {
        HomeScreenEntry(date: .now, albumTitle: "My Vlog", clipCount: 0, totalDuration: 0, albumID: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (HomeScreenEntry) -> Void) {
        let data = WidgetDataProvider.loadData()
        let album = data.albums.first
        completion(HomeScreenEntry(
            date: .now,
            albumTitle: album?.title ?? "No Album",
            clipCount: album?.clipCount ?? 0,
            totalDuration: album?.totalDuration ?? 0,
            albumID: album?.id
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HomeScreenEntry>) -> Void) {
        let data = WidgetDataProvider.loadData()
        let album = data.albums.first
        let entry = HomeScreenEntry(
            date: .now,
            albumTitle: album?.title ?? "No Album",
            clipCount: album?.clipCount ?? 0,
            totalDuration: album?.totalDuration ?? 0,
            albumID: album?.id
        )
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(300)))
        completion(timeline)
    }
}

struct HomeScreenEntry: TimelineEntry {
    let date: Date
    let albumTitle: String
    let clipCount: Int
    let totalDuration: Double
    let albumID: String?
}

struct HomeScreenWidget: Widget {
    let kind = "VlogCamHomeScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HomeScreenProvider()) { entry in
            HomeScreenWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("VlogCam Album")
        .description("View your latest album")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HomeScreenWidgetView: View {
    let entry: HomeScreenEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "video.fill")
                    .foregroundStyle(.orange)
                Text("VlogCam")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text(entry.albumTitle)
                .font(.system(size: 16, weight: .bold, design: .serif))
                .lineLimit(2)

            Spacer()

            HStack {
                Label("\(entry.clipCount)", systemImage: "film")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                Spacer()
                Text(String(format: "%.0fs", entry.totalDuration))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(entry.albumID.map { URL(string: "vlogcam://album/\($0)") } ?? URL(string: "vlogcam://record"))
    }
}
