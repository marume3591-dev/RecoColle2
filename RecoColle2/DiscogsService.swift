import Foundation

struct PriceStats {
    let lowest: Double?
    let highest: Double?
    let currency: String
}

// MARK: - モデル

struct DiscographyItem: Identifiable, Decodable {
    let id: Int
    let title: String
    let year: Int?
    let type: String
    let role: String?
    let thumb: String?
    let format: String?
    
    var displayYear: String { year.map(String.init) ?? "—" }
}

struct DiscographyResult: Decodable {
    let releases: [DiscographyItem]
    let pagination: DiscographyPagination
}

struct DiscographyPagination: Decodable {
    let page: Int
    let pages: Int
    let items: Int
}

struct DiscogsSearchResult: Decodable {
    let results: [DiscogsSearchItem]
}

struct DiscogsSearchItem: Decodable {
    let id: Int
}

// MARK: - 為替レートキャッシュ

class ExchangeRateCache {
    static let shared = ExchangeRateCache()
    
    private var rates: [String: Double] = [:]
    private var lastUpdated: Date?
    private let cacheKey = "exchangeRates"
    private let dateKey = "exchangeRatesDate"
    
    init() {
        load()
    }
    
    func rate(from: String, to: String) -> Double? {
        if from == to { return 1.0 }
        return rates[to]
    }
    
    func needsUpdate() -> Bool {
        guard let lastUpdated = lastUpdated else { return true }
        return Date().timeIntervalSince(lastUpdated) > 86400
    }
    
    func update(rates: [String: Double]) {
        self.rates = rates
        self.lastUpdated = Date()
        save()
    }
    
    private func save() {
        UserDefaults.standard.set(rates, forKey: cacheKey)
        UserDefaults.standard.set(lastUpdated, forKey: dateKey)
    }
    
    private func load() {
        rates = UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: Double] ?? [:]
        lastUpdated = UserDefaults.standard.object(forKey: dateKey) as? Date
    }
}

// MARK: - DiscogsService

struct DiscogsService {
    private let key = "VTvQRnPmaaybKvVDYsej"
    private let secret = "VKFSjBMuqcgsAdmMvUzfoeLlsQbGYqdE"
    private let userAgent = "RecoColle2/1.0 (marume3591@icloud.com)"
    
    func updateExchangeRateIfNeeded() async {
        guard ExchangeRateCache.shared.needsUpdate() else { return }
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rates = json["rates"] as? [String: Double] {
                ExchangeRateCache.shared.update(rates: rates)
                print("✅ 為替レート更新完了")
            }
        } catch {
            print("❌ 為替レート取得失敗:", error)
        }
    }
    
    func fetchPriceStats(releaseId: String) async throws -> PriceStats? {
        let urlString = "https://api.discogs.com/marketplace/stats/\(releaseId)?key=\(key)&secret=\(secret)"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📦 APIレスポンス:", jsonString)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        let lowestPrice = json["lowest_price"] as? [String: Any]
        let currency = lowestPrice?["currency"] as? String ?? "USD"
        let lowest = lowestPrice?["value"] as? Double
        let highest = (json["highest_price"] as? [String: Any])?["value"] as? Double
        
        return PriceStats(lowest: lowest, highest: highest, currency: currency)
    }

    func fetchArtistDiscography(artistId: Int, page: Int = 1) async throws -> DiscographyResult {
        let urlString = "https://api.discogs.com/artists/\(artistId)/releases?sort=year&sort_order=asc&per_page=20&page=\(page)&key=\(key)&secret=\(secret)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(DiscographyResult.self, from: data)
    }
}

// MARK: - リリース詳細取得

struct ReleaseDetail {
    let title: String
    let artists: [String]
    let artistId: Int?
    let label: String?
    let year: String?
    let country: String?
    let genres: [String]
    let styles: [String]
    let tracklist: [String]
    let extraArtists: [String]
    let notes: String?
}

extension DiscogsService {
    func fetchReleaseDetail(releaseId: String) async throws -> ReleaseDetail? {
        let urlString = "https://api.discogs.com/releases/\(releaseId)?key=\(key)&secret=\(secret)"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        
        let title = json["title"] as? String ?? ""
        
        let artistsRaw = json["artists"] as? [[String: Any]] ?? []
        let artists = artistsRaw.compactMap { $0["name"] as? String }
        let artistId = artistsRaw.first?["id"] as? Int
        
        let labelsRaw = json["labels"] as? [[String: Any]] ?? []
        let label = labelsRaw.first?["name"] as? String
        
        let year = (json["year"] as? Int).map { String($0) }
        let country = json["country"] as? String
        
        let genres = json["genres"] as? [String] ?? []
        let styles = json["styles"] as? [String] ?? []
        
        let tracklistRaw = json["tracklist"] as? [[String: Any]] ?? []
        let tracklist = tracklistRaw.compactMap { track -> String? in
            guard let title = track["title"] as? String else { return nil }
            let pos = track["position"] as? String ?? ""
            return pos.isEmpty ? title : "\(pos). \(title)"
        }
        
        let extraRaw = json["extraartists"] as? [[String: Any]] ?? []
        let extraArtists = extraRaw.compactMap { artist -> String? in
            guard let name = artist["name"] as? String else { return nil }
            let role = artist["role"] as? String ?? ""
            return role.isEmpty ? name : "\(name) (\(role))"
        }
        
        let notes = json["notes"] as? String
        
        return ReleaseDetail(
            title: title,
            artists: artists,
            artistId: artistId,
            label: label,
            year: year,
            country: country,
            genres: genres,
            styles: styles,
            tracklist: tracklist,
            extraArtists: extraArtists,
            notes: notes
        )
    }
}
