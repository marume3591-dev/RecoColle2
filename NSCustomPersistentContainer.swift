import Foundation
import CoreData

//class NSCustomPersistentContainer: NSPersistentCloudKitContainer {
//
//    override class func defaultDirectoryURL() -> URL {
//        guard let url = FileManager.default
//            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.marume3591.RecoColle2")
//        else {
//            fatalError("App Group container not found")
//        }
//
//        return url.appendingPathComponent("DataModel.sqlite")
//    }
//}
class NSCustomPersistentContainer: NSPersistentCloudKitContainer, @unchecked Sendable {
    override class func defaultDirectoryURL() -> URL {
        return super.defaultDirectoryURL()
    }
}

