import WidgetKit
import SwiftUI

struct RecordEntry: TimelineEntry {
    let date: Date
    let title: String
    let artist: String
    let artwork: UIImage?
    let recordId: String
}

struct RecordProvider: TimelineProvider {
    
    func loadEntry() -> RecordEntry {
        let defaults = UserDefaults(suiteName: "group.com.marume3591.RecoColle2")
        let title = defaults?.string(forKey: "widgetRecordTitle") ?? "レコードを追加しよう"
        let artist = defaults?.string(forKey: "widgetRecordArtist") ?? ""
        let recordId = defaults?.string(forKey: "widgetRecordId") ?? ""
        
        var artwork: UIImage? = nil
        if let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.marume3591.RecoColle2") {
            let imageURL = containerURL.appendingPathComponent("widgetArtwork.jpg")
            if let data = try? Data(contentsOf: imageURL) {
                artwork = UIImage(data: data)
            }
        }
        return RecordEntry(date: Date(), title: title, artist: artist, artwork: artwork, recordId: recordId)
    }
    
    func placeholder(in context: Context) -> RecordEntry {
        RecordEntry(date: Date(), title: "Kind of Blue", artist: "Miles Davis", artwork: nil, recordId: "")
    }
    
    func getSnapshot(in context: Context, completion: @escaping (RecordEntry) -> ()) {
        completion(loadEntry())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<RecordEntry>) -> ()) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct RecoColleWidgetEntryView: View {
    var entry: RecordEntry
    
    var body: some View {
        Link(destination: URL(string: "recocolle2://record?id=\(entry.recordId)")!) {
            HStack(spacing: 14) {
                if let artwork = entry.artwork {
                    SwiftUI.Image(uiImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .cornerRadius(6)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .overlay(Text("🎵").font(.system(size: 32)))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("今日の1枚")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(entry.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(2)
                    Text(entry.artist)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
        }
    }
}

struct RecoColleWidget: Widget {
    let kind: String = "RecoColleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecordProvider()) { entry in
            if #available(iOS 17.0, *) {
                RecoColleWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                RecoColleWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("今日の1枚")
        .description("コレクションからランダムに1枚表示します")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    RecoColleWidget()
} timeline: {
    RecordEntry(date: .now, title: "Kind of Blue", artist: "Miles Davis", artwork: nil, recordId: "")
}

