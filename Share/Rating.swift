//
//	Rating.swift
//	Model file generated using JSONExport: https://github.com/Ahmed-Ali/JSONExport

import Foundation

struct Rating : Codable {

	let average : Float?
	let count : Int?


	enum CodingKeys: String, CodingKey {
		case average = "average"
		case count = "count"
	}
	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		average = try values.decodeIfPresent(Float.self, forKey: .average)
		count = try values.decodeIfPresent(Int.self, forKey: .count)
	}


}