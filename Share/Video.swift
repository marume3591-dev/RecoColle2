//
//	Video.swift
//	Model file generated using JSONExport: https://github.com/Ahmed-Ali/JSONExport

import Foundation

struct Video : Codable {

	let descriptionField : String?
	let duration : Int?
	let embed : Bool?
	let title : String?
	let uri : String?


	enum CodingKeys: String, CodingKey {
		case descriptionField = "description"
		case duration = "duration"
		case embed = "embed"
		case title = "title"
		case uri = "uri"
	}
	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		descriptionField = try values.decodeIfPresent(String.self, forKey: .descriptionField)
		duration = try values.decodeIfPresent(Int.self, forKey: .duration)
		embed = try values.decodeIfPresent(Bool.self, forKey: .embed)
		title = try values.decodeIfPresent(String.self, forKey: .title)
		uri = try values.decodeIfPresent(String.self, forKey: .uri)
	}


}