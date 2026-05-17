//
//    CurrentBidPrice.swift
//    Model file generated using JSONExport: https://github.com/Ahmed-Ali/JSONExport

import Foundation

struct Price : Decodable {

    let currency : String?
    let value : String?


    enum CodingKeys: String, CodingKey {
        case currency = "currency"
        case value = "value"
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        currency = try values.decodeIfPresent(String.self, forKey: .currency)
        value = try values.decodeIfPresent(String.self, forKey: .value)
    }


}
