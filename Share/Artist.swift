//
//	Artist.swift
//	Model file generated using JSONExport: https://github.com/Ahmed-Ali/JSONExport

import Foundation

struct Artist : Codable {

	let anv : String?
	let id : Int?
	let join : String?
	let name : String?
	let resourceUrl : String?
	let role : String?
	let tracks : String?


	enum CodingKeys: String, CodingKey {
		case anv = "anv"
		case id = "id"
		case join = "join"
		case name = "name"
		case resourceUrl = "resource_url"
		case role = "role"
		case tracks = "tracks"
	}
	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		anv = try values.decodeIfPresent(String.self, forKey: .anv)
		id = try values.decodeIfPresent(Int.self, forKey: .id)
		join = try values.decodeIfPresent(String.self, forKey: .join)
		name = try values.decodeIfPresent(String.self, forKey: .name)
		resourceUrl = try values.decodeIfPresent(String.self, forKey: .resourceUrl)
		role = try values.decodeIfPresent(String.self, forKey: .role)
		tracks = try values.decodeIfPresent(String.self, forKey: .tracks)
	}


}