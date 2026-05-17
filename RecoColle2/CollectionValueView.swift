import SwiftUI
import CoreData
import Charts

// MARK: - ランキング行
struct ValueRankingRow: View {
    let index: Int
    let record: RecordList2
    let formatValue: (Double) -> String
    
    var body: some View {
        HStack {
            Text("\(index + 1)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(record.albumTitle ?? "")
                    .font(.headline)
                Text(record.artistName ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let format = record.format, !format.isEmpty {
                    Text(format)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(formatValue(record.priceLow))
                .font(.headline)
                .foregroundColor(.green)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            NotificationCenter.default.post(
                name: .showRecordDetail,
                object: record
            )
        }
    }
}

// MARK: - 価値順リスト画面
struct ValueRankingView: View {
    let records: [RecordList2]
    
    var sortedRecords: [RecordList2] {
        records.sorted { $0.priceLow > $1.priceLow }
    }
    
    var body: some View {
        List {
            ForEach(Array(sortedRecords.enumerated()), id: \.offset) { index, record in
                ValueRankingRow(index: index, record: record, formatValue: formatValue)
            }
        }
        .navigationTitle("Value Ranking")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func formatValue(_ value: Double) -> String {
        let targetCurrency = Locale.current.currency?.identifier ?? "USD"
        if targetCurrency == "USD" {
            return String(format: "USD %.2f", value)
        }
        if let rate = ExchangeRateCache.shared.rate(from: "USD", to: targetCurrency) {
            let converted = value * rate
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = targetCurrency
            formatter.maximumFractionDigits = targetCurrency == "JPY" ? 0 : 2
            return formatter.string(from: NSNumber(value: converted)) ?? String(format: "\(targetCurrency) %.2f", converted)
        }
        return String(format: "USD %.2f", value)
    }
}

// MARK: - アーティストランキング画面
struct ArtistValueRankingView: View {
    let artistSummaries: [CollectionValueView.ArtistSummary]
    let formatValue: (Double) -> String
    
    var body: some View {
        List {
            ForEach(Array(artistSummaries.enumerated()), id: \.offset) { index, summary in
                HStack {
                    Text("\(index + 1)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(summary.artist)
                            .font(.headline)
                        Text("\(summary.pricedCount) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(formatValue(summary.total))
                        .font(.headline)
                        .foregroundColor(.green)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Artist Ranking")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 平均ランキング画面
struct ArtistAvgRankingView: View {
    let artistSummaries: [CollectionValueView.ArtistSummary]
    let formatValue: (Double) -> String
    
    var sortedByAvg: [CollectionValueView.ArtistSummary] {
        artistSummaries
            .filter { $0.pricedCount > 0 }
            .sorted { ($0.total / Double($0.pricedCount)) > ($1.total / Double($1.pricedCount)) }
    }
    
    var body: some View {
        List {
            ForEach(Array(sortedByAvg.enumerated()), id: \.offset) { index, summary in
                HStack {
                    Text("\(index + 1)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(summary.artist)
                            .font(.headline)
                        Text("\(summary.pricedCount) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("avg \(formatValue(summary.total / Double(summary.pricedCount)))")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Avg per Item Ranking")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 総合計セクション
struct TotalSection: View {
    let totalFormatted: String
    let pricedCount: Int
    let unpricedCount: Int
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Total Value (Min)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(totalFormatted)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 8)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Priced")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(pricedCount) items")
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("No Price")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(unpricedCount) items")
                        .font(.headline)
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

// MARK: - ハイライトセクション
struct HighlightsSection: View {
    let pricedRecords: [RecordList2]
    let mostValuableItem: RecordList2?
    let mostValuableArtist: CollectionValueView.ArtistSummary?
    let highestAvgArtist: CollectionValueView.ArtistSummary?
    let allArtistSummaries: [CollectionValueView.ArtistSummary]
    let formatValue: (Double) -> String
    
    var body: some View {
        Section("Highlights") {
            NavigationLink(destination: ValueRankingView(records: pricedRecords)) {
                if let item = mostValuableItem {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("💎 Most Valuable Item")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(item.albumTitle ?? "")
                            .font(.headline)
                        Text(item.artistName ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(formatValue(item.priceLow))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            if let artist = mostValuableArtist {
                NavigationLink(destination: ArtistValueRankingView(artistSummaries: allArtistSummaries, formatValue: formatValue)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🎵 Most Valuable Artist")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(artist.artist)
                            .font(.headline)
                        Text("\(artist.pricedCount) items · \(formatValue(artist.total))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            if let avgArtist = highestAvgArtist {
                NavigationLink(destination: ArtistAvgRankingView(artistSummaries: allArtistSummaries, formatValue: formatValue)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("⭐️ Highest Avg per Item")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(avgArtist.artist)
                            .font(.headline)
                        Text("avg \(formatValue(avgArtist.total / Double(avgArtist.pricedCount)))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - アーティスト別セクション
struct ByArtistSection: View {
    let artistSummaries: [CollectionValueView.ArtistSummary]
    let pricedRecords: [RecordList2]
    let allRecords: [RecordList2]
    let formatValue: (Double) -> String
    
    var body: some View {
        Section("By Artist") {
            ForEach(artistSummaries, id: \.artist) { summary in
                let artistRecords = allRecords.filter { $0.artistName == summary.artist }
                
                Group {
                    if artistRecords.count == 1, let record = artistRecords.first {
                        // 1枚の場合は直接Edit画面へ
                        Button {
                            NotificationCenter.default.post(
                                name: .showRecordDetail,
                                object: record
                            )
                        } label: {
                            ArtistRowContent(summary: summary, formatValue: formatValue)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // 複数枚の場合はValue Ranking経由
                        NavigationLink(destination: ValueRankingView(records: artistRecords)) {
                            ArtistRowContent(summary: summary, formatValue: formatValue)
                        }
                    }
                }
            }
        }
    }
}

struct ArtistRowContent: View {
    let summary: CollectionValueView.ArtistSummary
    let formatValue: (Double) -> String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(summary.artist)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text("\(summary.totalCount) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if summary.pricedCount < summary.totalCount {
                        Text("(\(summary.totalCount - summary.pricedCount) No Price)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            Spacer()
            Text(summary.total > 0 ? formatValue(summary.total) : "―")
                .font(.headline)
                .foregroundColor(summary.total > 0 ? .primary : .secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - メイン画面
struct CollectionValueView: View {
    
    @State private var records: [RecordList2] = []
    
    var body: some View {
            List {
                TotalSection(
                    totalFormatted: totalFormatted,
                    pricedCount: pricedCount,
                    unpricedCount: unpricedCount
                )
                
                HighlightsSection(
                    pricedRecords: pricedRecords,
                    mostValuableItem: mostValuableItem,
                    mostValuableArtist: artistSummaries.first,
                    highestAvgArtist: highestAverageArtist,
                    allArtistSummaries: artistSummaries,
                    formatValue: formatValue
                )
                
                if !top10.isEmpty {
                    Section("Top 10 Artists") {
                        Chart(top10, id: \.artist) { summary in
                            BarMark(
                                x: .value("Value", summary.total),
                                y: .value("Artist", summary.artist)
                            )
                            .foregroundStyle(.blue)
                            .annotation(position: .trailing) {
                                Text(formatValue(summary.total))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(height: CGFloat(top10.count) * 40)
                        .chartXAxis(.hidden)
                    }
                }
                
                ByArtistSection(
                    artistSummaries: artistSummaries,
                    pricedRecords: pricedRecords,
                    allRecords: records,
                    formatValue: formatValue
                )
            }
            .navigationTitle("Collection Value")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadRecords()
            }
    }
    
    // MARK: - データ取得
    
    func loadRecords() {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let request = NSFetchRequest<RecordList2>(entityName: "RecordList2")
        request.predicate = NSPredicate(format: "wantsFlg == %@", "false")
        records = (try? context.fetch(request)) ?? []
    }
    
    // MARK: - 計算
    
    var pricedRecords: [RecordList2] {
        records.filter { $0.priceUpdatedAt != nil }
    }
    
    var pricedCount: Int { pricedRecords.count }
    var unpricedCount: Int { records.count - pricedRecords.count }
    
    var total: Double {
        pricedRecords.reduce(0) { $0 + $1.priceLow }
    }
    
    var totalFormatted: String {
        formatValue(total)
    }
    
    var mostValuableItem: RecordList2? {
        pricedRecords.max(by: { $0.priceLow < $1.priceLow })
    }
    
    var highestAverageArtist: ArtistSummary? {
        artistSummaries
            .filter { $0.pricedCount > 0 }
            .max(by: {
                ($0.total / Double($0.pricedCount)) < ($1.total / Double($1.pricedCount))
            })
    }
    
    struct ArtistSummary {
        let artist: String
        let totalCount: Int
        let pricedCount: Int
        let total: Double
    }
    
    var artistSummaries: [ArtistSummary] {
        let grouped = Dictionary(grouping: records) { $0.artistName ?? "Unknown" }
        return grouped.map { artist, records in
            let priced = records.filter { $0.priceUpdatedAt != nil }
            let total = priced.reduce(0) { $0 + $1.priceLow }
            return ArtistSummary(
                artist: artist,
                totalCount: records.count,
                pricedCount: priced.count,
                total: total
            )
        }
        .sorted { $0.total > $1.total }
    }
    
    var top10: [ArtistSummary] {
        Array(artistSummaries.prefix(10))
    }
    
    // MARK: - フォーマット
    
    func formatValue(_ value: Double) -> String {
        let targetCurrency = Locale.current.currency?.identifier ?? "USD"
        if targetCurrency == "USD" {
            return String(format: "USD %.2f", value)
        }
        if let rate = ExchangeRateCache.shared.rate(from: "USD", to: targetCurrency) {
            let converted = value * rate
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = targetCurrency
            formatter.maximumFractionDigits = targetCurrency == "JPY" ? 0 : 2
            return formatter.string(from: NSNumber(value: converted)) ?? String(format: "\(targetCurrency) %.2f", converted)
        }
        return String(format: "USD %.2f", value)
    }
}
