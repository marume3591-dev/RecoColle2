//
//	ShippingOption.swift
//	Model file generated using JSONExport: https://github.com/Ahmed-Ali/JSONExport

import Foundation

struct ShippingOption : Decodable {

	let shippingCost : CurrentBidPrice?
	let shippingCostType : String?


	enum CodingKeys: String, CodingKey {
		case shippingCost
		case shippingCostType = "shippingCostType"
	}
	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		shippingCost = try CurrentBidPrice(from: decoder)
		shippingCostType = try values.decodeIfPresent(String.self, forKey: .shippingCostType)
	}


}
