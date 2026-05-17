//
//    AdditionalImage.swift
//    Model file generated using JSONExport: https://github.com/Ahmed-Ali/JSONExport

import Foundation

struct Image : Decodable {

    let imageUrl : String?


    enum CodingKeys: String, CodingKey {
        case imageUrl = "imageUrl"
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        imageUrl = try values.decodeIfPresent(String.self, forKey: .imageUrl)
    }


}
