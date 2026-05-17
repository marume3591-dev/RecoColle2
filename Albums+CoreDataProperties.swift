//
//  Albums+CoreDataProperties.swift
//  RecoColle2
//
//  Created by 丸田信一 on 2024/02/27.
//
//

import Foundation
import CoreData


extension Albums {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Albums> {
        return NSFetchRequest<Albums>(entityName: "Albums")
    }

    @NSManaged public var id: String?
    @NSManaged public var albumName: String?
    @NSManaged public var idRecordList2: String?
    @NSManaged public var sortOrder: Int32

}

extension Albums : Identifiable {

}
