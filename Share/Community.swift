//
//	Community.swift
//	Model file generated using JSONExport: https://github.com/Ahmed-Ali/JSONExport

import Foundation

struct Community : Codable {

	let contributors : [Contributor]?
	let dataQuality : String?
	let have : Int?
	let rating : Rating?
	let status : String?
	let submitter : Contributor?
	let want : Int?


	enum CodingKeys: String, CodingKey {
		case contributors = "contributors"
		case dataQuality = "data_quality"
		case have = "have"
		case rating
		case status = "status"
		case submitter
		case want = "want"
	}
	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		contributors = try values.decodeIfPresent([Contributor].self, forKey: .contributors)
		dataQuality = try values.decodeIfPresent(String.self, forKey: .dataQuality)
		have = try values.decodeIfPresent(Int.self, forKey: .have)
		rating = try Rating(from: decoder)
		status = try values.decodeIfPresent(String.self, forKey: .status)
		submitter = try Contributor(from: decoder)
		want = try values.decodeIfPresent(Int.self, forKey: .want)
	}


}