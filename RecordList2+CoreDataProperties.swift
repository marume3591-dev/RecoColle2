//
//  RecordList2+CoreDataProperties.swift
//  RecoColle2
//
//  Created by 丸田信一 on 2023/01/31.
//
//

import Foundation
import CoreData


extension RecordList2 {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RecordList2> {
        
        return NSFetchRequest<RecordList2>(entityName: "RecordList2")
    }

    @NSManaged public var format: String?
    @NSManaged public var artistName: String?
    @NSManaged public var albumTitle: String?
    @NSManaged public var albumImage: Data?
    @NSManaged public var wantsFlg: String?
    @NSManaged public var releaseCountry: String?
    @NSManaged public var memo: String?
    @NSManaged public var releaseDate: String?
    @NSManaged public var id: String?
    @NSManaged public var discogsReleaseId: String?
    @NSManaged public var priceLow: Double
    @NSManaged public var priceUpdatedAt: Date?
    @NSManaged public var label: String?
    @NSManaged public var catno: String?

}

extension RecordList2 : Identifiable {

}

