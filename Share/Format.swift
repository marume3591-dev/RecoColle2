//
//	Format.swift
//	Model file generated using JSONExport: https://github.com/Ahmed-Ali/JSONExport

import Foundation

struct Format : Codable {

	let descriptions : [String]?
	let name : String?
	let qty : String?


	enum CodingKeys: String, CodingKey {
		case descriptions = "descriptions"
		case name = "name"
		case qty = "qty"
	}
	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		descriptions = try values.decodeIfPresent([String].self, forKey: .descriptions)
		name = try values.decodeIfPresent(String.self, forKey: .name)
		qty = try values.decodeIfPresent(String.self, forKey: .qty)
	}


}