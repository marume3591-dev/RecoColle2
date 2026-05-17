//
//	RootClass.swift
//	Model file generated using JSONExport: https://github.com/Ahmed-Ali/JSONExport

import Foundation

struct RootClass : Decodable {

	let href : String?
	let itemSummaries : [ItemSummary]?
	let limit : Int?
	let offset : Int?
	let total : Int?


	enum CodingKeys: String, CodingKey {
		case href = "href"
		case itemSummaries = "itemSummaries"
		case limit = "limit"
		case offset = "offset"
		case total = "total"
	}
	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		href = try values.decodeIfPresent(String.self, forKey: .href)
		itemSummaries = try values.decodeIfPresent([ItemSummary].self, forKey: .itemSummaries)
		limit = try values.decodeIfPresent(Int.self, forKey: .limit)
		offset = try values.decodeIfPresent(Int.self, forKey: .offset)
		total = try values.decodeIfPresent(Int.self, forKey: .total)
	}


}
