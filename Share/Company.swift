//
//	Company.swift
//	Model file generated using JSONExport: https://github.com/Ahmed-Ali/JSONExport

import Foundation

struct Company : Codable {

	let catno : String?
	let entityType : String?
	let entityTypeName : String?
	let id : Int?
	let name : String?
	let resourceUrl : String?


	enum CodingKeys: String, CodingKey {
		case catno = "catno"
		case entityType = "entity_type"
		case entityTypeName = "entity_type_name"
		case id = "id"
		case name = "name"
		case resourceUrl = "resource_url"
	}
	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		catno = try values.decodeIfPresent(String.self, forKey: .catno)
		entityType = try values.decodeIfPresent(String.self, forKey: .entityType)
		entityTypeName = try values.decodeIfPresent(String.self, forKey: .entityTypeName)
		id = try values.decodeIfPresent(Int.self, forKey: .id)
		name = try values.decodeIfPresent(String.self, forKey: .name)
		resourceUrl = try values.decodeIfPresent(String.self, forKey: .resourceUrl)
	}


}