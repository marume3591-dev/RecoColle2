//
//	Seller.swift
//	Model file generated using JSONExport: https://github.com/Ahmed-Ali/JSONExport

import Foundation

struct Seller : Decodable {

	let feedbackScore : Int?


	enum CodingKeys: String, CodingKey {
		case feedbackScore = "feedbackScore"
	}
	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		feedbackScore = try values.decodeIfPresent(Int.self, forKey: .feedbackScore)
	}


}
