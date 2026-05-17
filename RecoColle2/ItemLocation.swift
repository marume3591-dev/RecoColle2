//
//	ItemLocation.swift
//	Model file generated using JSONExport: https://github.com/Ahmed-Ali/JSONExport

import Foundation

struct ItemLocation : Decodable {

	let country : String?


	enum CodingKeys: String, CodingKey {
		case country = "country"
	}
	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		country = try values.decodeIfPresent(String.self, forKey: .country)
	}


}
