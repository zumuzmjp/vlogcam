import SwiftUI
import WidgetKit

struct LockScreenProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScreenEntry {
        LockScreenEntry(date: .now, clipCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (LockScreenEntry) -> Void) {
        let data = WidgetDataProvider.loadData()
        completion(LockScreenEntry(date: .now, clipCount: data.totalClips))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenEntry>) -> Void) {
        let data = WidgetDataProvider.loadData()
        let entry = LockScreenEntry(date: .now, clipCount: data.totalClips)
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(300)))
        completion(timeline)
    }
}

struct LockScreenEntry: TimelineEntry {
    let date: Date
    let clipCount: Int
}

struct LockScreenWidget: Widget {
    let kind = "VlogCamLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("VlogCam")
        .description("Quick access to recording")
        .supportedFamilies([.accessoryCircular])
    }
}

struct LockScreenWidgetView: View {
    let entry: LockScreenEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "video.fill")
                    .font(.system(size: 14))
                Text("\(entry.clipCount)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
        }
        .widgetURL(URL(string: "vlogcam://record"))
    }
}
