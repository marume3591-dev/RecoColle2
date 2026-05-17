//
//	Tracklist.swift
//	Model file generated using JSONExport: https://github.com/Ahmed-Ali/JSONExport

import Foundation

struct Tracklist : Codable {

	let duration : String?
	let position : String?
	let title : String?
	let type : String?


	enum CodingKeys: String, CodingKey {
		case duration = "duration"
		case position = "position"
		case title = "title"
		case type = "type_"
	}
	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		duration = try values.decodeIfPresent(String.self, forKey: .duration)
		position = try values.decodeIfPresent(String.self, forKey: .position)
		title = try values.decodeIfPresent(String.self, forKey: .title)
		type = try values.decodeIfPresent(String.self, forKey: .type)
	}


}