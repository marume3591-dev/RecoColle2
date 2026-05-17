//
//	Image.swift
//	Model file generated using JSONExport: https://github.com/Ahmed-Ali/JSONExport

import Foundation

struct Image : Codable {

	let height : Int?
	let resourceUrl : String?
	let type : String?
	let uri : String?
	let uri150 : String?
	let width : Int?


	enum CodingKeys: String, CodingKey {
		case height = "height"
		case resourceUrl = "resource_url"
		case type = "type"
		case uri = "uri"
		case uri150 = "uri150"
		case width = "width"
	}
	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		height = try values.decodeIfPresent(Int.self, forKey: .height)
		resourceUrl = try values.decodeIfPresent(String.self, forKey: .resourceUrl)
		type = try values.decodeIfPresent(String.self, forKey: .type)
		uri = try values.decodeIfPresent(String.self, forKey: .uri)
		uri150 = try values.decodeIfPresent(String.self, forKey: .uri150)
		width = try values.decodeIfPresent(Int.self, forKey: .width)
	}


}