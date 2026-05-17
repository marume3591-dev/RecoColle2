

////
////    RootClass.swift
////    Model file generated using JSONExport: https://github.com/Ahmed-Ali/JSONExport
//
//import Foundation
//
//struct Root : Decodable {
//
//    let artists : [Artist]?
//    let community : Community?
//    let companies : [Company]?
//    let country : String?
//    let dataQuality : String?
//    let dateAdded : String?
//    let dateChanged : String?
//    let estimatedWeight : Int?
//    let extraartists : [Artist]?
//    let formatQuantity : Int?
//    let formats : [Format]?
//    let genres : [String]?
//    let id : Int?
//    let identifiers : [Identifier]?
//    let images : [Image]?
//    let labels : [Label]?
//    let lowestPrice : Float?
//    let masterId : Int?
//    let masterUrl : String?
//    let notes : String?
//    let numForSale : Int?
//    let released : String?
//    let releasedFormatted : String?
//    let resourceUrl : String?
//    let series : [String]?
//    let status : String?
//    let styles : [String]?
//    let thumb : String?
//    let title : String?
//    let tracklist : [Tracklist]?
//    let uri : String?
//    let videos : [Video]?
//    let year : Int?
//
//
//    enum CodingKeys: String, CodingKey {
//        case artists = "artists"
//        case community
//        case companies = "companies"
//        case country = "country"
//        case dataQuality = "data_quality"
//        case dateAdded = "date_added"
//        case dateChanged = "date_changed"
//        case estimatedWeight = "estimated_weight"
//        case extraartists = "extraartists"
//        case formatQuantity = "format_quantity"
//        case formats = "formats"
//        case genres = "genres"
//        case id = "id"
//        case identifiers = "identifiers"
//        case images = "images"
//        case labels = "labels"
//        case lowestPrice = "lowest_price"
//        case masterId = "master_id"
//        case masterUrl = "master_url"
//        case notes = "notes"
//        case numForSale = "num_for_sale"
//        case released = "released"
//        case releasedFormatted = "released_formatted"
//        case resourceUrl = "resource_url"
//        case series = "series"
//        case status = "status"
//        case styles = "styles"
//        case thumb = "thumb"
//        case title = "title"
//        case tracklist = "tracklist"
//        case uri = "uri"
//        case videos = "videos"
//        case year = "year"
//    }
//    init(from decoder: Decoder) throws {
//        let values = try decoder.container(keyedBy: CodingKeys.self)
//        artists = try values.decodeIfPresent([Artist].self, forKey: .artists)
//        community = try Community(from: decoder)
//        companies = try values.decodeIfPresent([Company].self, forKey: .companies)
//        country = try values.decodeIfPresent(String.self, forKey: .country)
//        dataQuality = try values.decodeIfPresent(String.self, forKey: .dataQuality)
//        dateAdded = try values.decodeIfPresent(String.self, forKey: .dateAdded)
//        dateChanged = try values.decodeIfPresent(String.self, forKey: .dateChanged)
//        estimatedWeight = try values.decodeIfPresent(Int.self, forKey: .estimatedWeight)
//        extraartists = try values.decodeIfPresent([Artist].self, forKey: .extraartists)
//        formatQuantity = try values.decodeIfPresent(Int.self, forKey: .formatQuantity)
//        formats = try values.decodeIfPresent([Format].self, forKey: .formats)
//        genres = try values.decodeIfPresent([String].self, forKey: .genres)
//        id = try values.decodeIfPresent(Int.self, forKey: .id)
//        identifiers = try values.decodeIfPresent([Identifier].self, forKey: .identifiers)
//        images = try values.decodeIfPresent([Image].self, forKey: .images)
//        labels = try values.decodeIfPresent([Label].self, forKey: .labels)
//        lowestPrice = try values.decodeIfPresent(Float.self, forKey: .lowestPrice)
//        masterId = try values.decodeIfPresent(Int.self, forKey: .masterId)
//        masterUrl = try values.decodeIfPresent(String.self, forKey: .masterUrl)
//        notes = try values.decodeIfPresent(String.self, forKey: .notes)
//        numForSale = try values.decodeIfPresent(Int.self, forKey: .numForSale)
//        released = try values.decodeIfPresent(String.self, forKey: .released)
//        releasedFormatted = try values.decodeIfPresent(String.self, forKey: .releasedFormatted)
//        resourceUrl = try values.decodeIfPresent(String.self, forKey: .resourceUrl)
//        series = try values.decodeIfPresent([String].self, forKey: .series)
//        status = try values.decodeIfPresent(String.self, forKey: .status)
//        styles = try values.decodeIfPresent([String].self, forKey: .styles)
//        thumb = try values.decodeIfPresent(String.self, forKey: .thumb)
//        title = try values.decodeIfPresent(String.self, forKey: .title)
//        tracklist = try values.decodeIfPresent([Tracklist].self, forKey: .tracklist)
//        uri = try values.decodeIfPresent(String.self, forKey: .uri)
//        videos = try values.decodeIfPresent([Video].self, forKey: .videos)
//        year = try values.decodeIfPresent(Int.self, forKey: .year)
//    }
//
//
//}
