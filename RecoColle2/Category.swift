//
//	Category.swift
//	Model file generated using JSONExport: https://github.com/Ahmed-Ali/JSONExport

import Foundation

struct Category : Decodable {

	let categoryId : String?
	let categoryName : String?


	enum CodingKeys: String, CodingKey {
		case categoryId = "categoryId"
		case categoryName = "categoryName"
	}
	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		categoryId = try values.decodeIfPresent(String.self, forKey: .categoryId)
		categoryName = try values.decodeIfPresent(String.self, forKey: .categoryName)
	}


}
