//
//	Contributor.swift
//	Model file generated using JSONExport: https://github.com/Ahmed-Ali/JSONExport

import Foundation

struct Contributor : Codable {

	let resourceUrl : String?
	let username : String?


	enum CodingKeys: String, CodingKey {
		case resourceUrl = "resource_url"
		case username = "username"
	}
	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		resourceUrl = try values.decodeIfPresent(String.self, forKey: .resourceUrl)
		username = try values.decodeIfPresent(String.self, forKey: .username)
	}


}