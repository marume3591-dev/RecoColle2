import SwiftUI
import CoreData
import Charts

// MARK: - メイン統計画面
struct CollectionStatsView: View {
    @State private var records: [RecordList2] = []
    @State private var selectedTitle: String? = nil
    @State private var selectedCategory: String = ""
    @State private var selectedKey: String = ""
    @State private var isNavigating = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summarySection
                
                DecadeStatsCard(title: NSLocalizedString("stats_format", comment: ""),
                                data: formatData) { key in
                    navigate(title: key, category: "format", key: key)
                }
                
                DecadeStatsCard(title: NSLocalizedString("stats_decade", comment: ""),
                                data: decadeData) { key in
                    navigate(title: key, category: "decade", key: key)
                }
                
                DecadeStatsCard(title: NSLocalizedString("stats_country", comment: ""),
                                data: countryData) { key in
                    navigate(title: key, category: "country", key: key)
                }
                
                DecadeStatsCard(title: NSLocalizedString("stats_label", comment: ""),
                                data: labelData) { key in
                    navigate(title: key, category: "label", key: key)
                }
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("collection_stats_menu", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadRecords() }
        .background(
            NavigationLink(
                destination: StatsDetailView(title: selectedTitle ?? "", category: selectedCategory, key: selectedKey),
                isActive: $isNavigating
            ) { EmptyView() }
        )
    }
    
    func navigate(title: String, category: String, key: String) {
        selectedTitle = title
        selectedCategory = category
        selectedKey = key
        isNavigating = true
    }
    
    // MARK: - サマリー
    var summarySection: some View {
        HStack(spacing: 12) {
            SummaryCard(
                title: NSLocalizedString("stats_total", comment: ""),
                value: "\(records.count)",
                icon: "square.stack"
            )
            SummaryCard(
                title: NSLocalizedString("stats_artists", comment: ""),
                value: "\(Set(records.compactMap { $0.artistName }).count)",
                icon: "person.2"
            )
            SummaryCard(
                title: NSLocalizedString("stats_labels", comment: ""),
                value: "\(Set(records.compactMap { $0.label }).count)",
                icon: "music.note.list"
            )
        }
    }
    
    // MARK: - データ集計
    var formatData: [(String, Int)] {
        counted(records.compactMap { $0.format })
    }
    
    var decadeData: [(String, Int)] {
        counted(records.compactMap { decadeString($0) })
    }
    
    var countryData: [(String, Int)] {
        counted(records.compactMap { $0.releaseCountry })
    }
    
    var labelData: [(String, Int)] {
        counted(records.compactMap { $0.label })
    }
    
    func decadeString(_ record: RecordList2) -> String? {
        guard let date = record.releaseDate, date.count >= 4,
              let year = Int(date.prefix(4)) else { return nil }
        let decade = (year / 10) * 10
        return "\(decade)s"
    }
    
    func counted(_ items: [String]) -> [(String, Int)] {
        var counts: [String: Int] = [:]
        for item in items {
            let key = item.trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            counts[key, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }
    }
    
    func loadRecords() {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let request = RecordList2.fetchRequest()
        request.predicate = NSPredicate(format: "wantsFlg != 'true'")
        records = (try? context.fetch(request)) ?? []
    }
}

// MARK: - サマリーカード
struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            SwiftUI.Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
            Text(value)
                .font(.system(size: 22, weight: .semibold))
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - バー
struct StatsBar: View {
    let value: Int
    let total: Int
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor)
                    .frame(width: total > 0 ? geo.size.width * CGFloat(value) / CGFloat(total) : 0, height: 8)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - 統計カード
struct StatsCard: View {
    let title: String
    let data: [(String, Int)]
    let onTap: (String) -> Void
    
    var total: Int { data.reduce(0) { $0 + $1.1 } }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            
            if data.isEmpty {
                Text(NSLocalizedString("stats_no_data", comment: ""))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    Button(action: { onTap(item.0) }) {
                        HStack(spacing: 8) {
                            Text(item.0)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                                .frame(width: 120, alignment: .leading)
                                .lineLimit(1)
                            StatsBar(value: item.1, total: total)
                            Text("\(item.1)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .trailing)
                            SwiftUI.Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - 円グラフ
struct DecadePieChart: View {
    let data: [(String, Int)]
    let total: Int
    let colors: [Color]
    
    var body: some View {
        HStack(spacing: 16) {
            Chart(Array(data.enumerated()), id: \.offset) { index, item in
                SectorMark(
                    angle: .value("count", item.1),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(colors[index % colors.count])
                .annotation(position: .overlay) {
                    if Double(item.1) / Double(total) > 0.05 {
                        Text(item.0)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(width: 160, height: 160)
            
            DecadeLegend(data: data, colors: colors)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 凡例
struct DecadeLegend: View {
    let data: [(String, Int)]
    let colors: [Color]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(data.prefix(8).enumerated()), id: \.offset) { index, item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(colors[index % colors.count])
                        .frame(width: 8, height: 8)
                    Text(item.0)
                        .font(.system(size: 11))
                    Text("\(item.1)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - 年代別カード（円グラフ付き）
struct DecadeStatsCard: View {
    let title: String
    let data: [(String, Int)]
    let onTap: (String) -> Void
    
    var total: Int { data.reduce(0) { $0 + $1.1 } }
    
    let colors: [Color] = [
        .blue, .orange, .green, .red, .purple,
        .yellow, .pink, .teal, .indigo, .mint
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            
            if data.isEmpty {
                Text(NSLocalizedString("stats_no_data", comment: ""))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            } else {
                DecadePieChart(data: data, total: total, colors: colors)
                
                Divider()
                
                ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                    Button(action: { onTap(item.0) }) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(colors[index % colors.count])
                                .frame(width: 8, height: 8)
                            Text(item.0)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                                .frame(width: 112, alignment: .leading)
                                .lineLimit(1)
                            StatsBar(value: item.1, total: total)
                            Text("\(item.1)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .trailing)
                            SwiftUI.Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - 詳細画面
struct StatsDetailView: View {
    let title: String
    let category: String
    let key: String
    @State private var records: [RecordList2] = []
    
    var sortedRecords: [RecordList2] {
        records.sorted { ($0.artistName ?? "") < ($1.artistName ?? "") }
    }
    
    var body: some View {
        Group {
            if records.isEmpty {
                Text(NSLocalizedString("stats_no_data", comment: ""))
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(Array(sortedRecords.enumerated()), id: \.offset) { _, record in
                        NavigationLink(destination: RecordEditView(record: record)) {
                            HStack(spacing: 12) {
                                if let imageData = record.albumImage,
                                   let uiImage = UIImage(data: imageData) {
                                    SwiftUI.Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 56, height: 56)
                                        .cornerRadius(4)
                                        .clipped()
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 56, height: 56)
                                        .overlay(
                                            SwiftUI.Image(systemName: "music.note")
                                                .foregroundColor(.secondary)
                                        )
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.albumTitle ?? "")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(record.artistName ?? "")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    if let date = record.releaseDate, !date.isEmpty {
                                        Text(date)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadRecords() }
    }
    
    func loadRecords() {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let request = RecordList2.fetchRequest()
        
        switch category {
        case "format":
            request.predicate = NSPredicate(format: "wantsFlg != 'true' AND format == %@", key)
        case "country":
            request.predicate = NSPredicate(format: "wantsFlg != 'true' AND releaseCountry == %@", key)
        case "label":
            request.predicate = NSPredicate(format: "wantsFlg != 'true' AND label == %@", key)
        case "decade":
            let decade = Int(key.replacingOccurrences(of: "s", with: "")) ?? 0
            let nextDecade = decade + 10
            request.predicate = NSPredicate(format: "wantsFlg != 'true' AND releaseDate >= %@ AND releaseDate < %@", "\(decade)", "\(nextDecade)")
        default:
            break
        }
        
        records = (try? context.fetch(request)) ?? []
    }
}

// MARK: - AddViewController2ラッパー
struct RecordEditView: UIViewControllerRepresentable {
    let record: RecordList2
    
    func makeUIViewController(context: Context) -> AddViewController2 {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "AddViewController2") as! AddViewController2
        vc.mode = .edit
        vc.record = record
        return vc
    }
    
    func updateUIViewController(_ uiViewController: AddViewController2, context: Context) {}
}
