import Foundation

struct DiscogsRoot: Codable {
    let id: Int?  
    let artists: [DiscogsArtist]?
    let formats: [DiscogsFormat]?
    let images: [DiscogsImage]?
    let labels: [DiscogsLabel]?  // 追加

    let title: String?
    let year: Int?
    let country: String?

}

struct DiscogsArtist: Codable {
    let name: String?
}

struct DiscogsFormat: Codable {
    let name: String?
}

struct DiscogsImage: Codable {
    let uri150: String?
}

// 追加
struct DiscogsLabel: Codable {
    let name: String?
    let catno: String?
}
