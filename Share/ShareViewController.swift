import Social
import CoreData
import UIKit

class ShareViewController: SLComposeServiceViewController {
    
    override func loadPreviewView() -> UIView! {
        DummyPreview()
    }
    
    override func isContentValid() -> Bool {
        
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else { return false }
        
        if provider.hasItemConformingToTypeIdentifier("public.url") {
            self.title = ""
            return true
        }
        
        self.title = "Share Discogs page"
        return false
    }
    
    override func didSelectPost() {
        
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else {
            close()
            return
        }
        
        provider.loadItem(forTypeIdentifier: "public.url", options: nil) { item, error in
            
            guard let url = item as? NSURL else {
                self.close()
                return
            }
            
            let urlString = url.absoluteString ?? ""
            print("===== SHARE START =====")
            print("Shared URL:", urlString)
            
            self.handleDiscogsURL(urlString)
        }
    }
    
    // MARK: URL判定
    func handleDiscogsURL(_ url:String){
        
        // sell/item
        if let listingID = extractListingID(url){
            
            print("Detected SELL page")
            fetchListing(listingID)
            return
        }
        
        // release/master
        if let (type,id) = extractReleaseID(url){
            
            print("Detected RELEASE page")
            let api = "https://api.discogs.com/\(type)/\(id)"
            print("API:",api)
            fetchDiscogs(api)
            return
        }
        
        print("Discogs URL not supported")
        close()
    }
    
    // MARK: sell/item ID取得
    func extractListingID(_ url:String) -> String? {
        
        let pattern = #"/sell/item/(\d+)"#
        
        guard let range = url.range(of: pattern, options: .regularExpression) else {
            print("ListingID not found")
            return nil
        }
        
        let match = String(url[range])
        let id = match.replacingOccurrences(of: "/sell/item/", with: "")
        
        print("ListingID:",id)
        
        return id
    }
    
    // MARK: release/master ID取得
    func extractReleaseID(_ url:String) -> (String,String)? {
        
        let pattern = #"/(release|master)/(\d+)"#
        
        guard let range = url.range(of: pattern, options: .regularExpression) else {
            print("ReleaseID not found")
            return nil
        }
        
        let match = String(url[range])
        let parts = match.split(separator:"/")
        
        if parts.count == 2 {
            
            let type = String(parts[0]) + "s"
            let id = String(parts[1])
            
            print("ReleaseType:",type)
            print("ReleaseID:",id)
            
            return (type,id)
        }
        
        return nil
    }
    
    // MARK: Marketplace API
    func fetchListing(_ listingID:String){
        
        let api = "https://api.discogs.com/marketplace/listings/\(listingID)"
        
        print("Marketplace API:",api)
        
        guard let url = URL(string:api) else {
            close()
            return
        }
        
        var request = URLRequest(url:url)
        request.httpMethod = "GET"
        request.addValue(userAgent(), forHTTPHeaderField:"User-Agent")
        
        URLSession.shared.dataTask(with:request){ data,response,error in
            
            if let error = error {
                print("Listing API Error:",error)
                self.close()
                return
            }
            
            guard let data = data else {
                print("Listing API data nil")
                self.close()
                return
            }
            
            print("Listing API response received")
            
            if let text = String(data:data,encoding:.utf8){
                print("Listing JSON:",text)
            }
            
            do{
                
                let json = try JSONSerialization.jsonObject(with:data) as? [String:Any]
                
                if let release = json?["release"] as? [String:Any],
                   let releaseID = release["id"] as? Int {
                    
                    print("ReleaseID from listing:",releaseID)
                    
                    let api = "https://api.discogs.com/releases/\(releaseID)"
                    self.fetchDiscogs(api)
                    
                }else{
                    
                    print("ReleaseID not found in listing")
                    self.close()
                }
                
            }catch{
                
                print("Listing decode error:",error)
                self.close()
            }
            
        }.resume()
    }
    
    // MARK: Release API
    func fetchDiscogs(_ url:String){
        
        print("Fetching Release:",url)
        
        guard let apiURL = URL(string:url) else {
            close()
            return
        }
        
        var request = URLRequest(url:apiURL)
        request.httpMethod = "GET"
        request.addValue(userAgent(), forHTTPHeaderField:"User-Agent")
        
        URLSession.shared.dataTask(with:request){ data,response,error in
            
            if let error = error {
                print("Release API error:",error)
                self.close()
                return
            }
            
            guard let data = data else {
                print("Release API data nil")
                self.close()
                return
            }
            
            print("Release API success")
            
            do{
                
                let root = try JSONDecoder().decode(DiscogsRoot.self, from:data)
                
                let artist = root.artists?.first?.name ?? ""
                let title = root.title ?? ""
                let format = root.formats?.first?.name ?? ""
                let year = root.year.map{String($0)} ?? ""
                let country = root.country ?? ""
                let imageURL = root.images?.first?.uri150 ?? ""
                
                print("Artist:",artist)
                print("Title:",title)
                
                if artist.isEmpty || title.isEmpty {
                    
                    print("Artist or Title empty -> abort")
                    self.close()
                    return
                }
                let catno = root.labels?.first?.catno ?? ""
                let releaseId = String(root.id ?? 0)

                self.downloadImage(
                    artist:artist,
                    title:title,
                    format:format,
                    year:year,
                    country:country,
                    imageURL:imageURL,
                    catno: catno,
                    releaseId: releaseId
                )
                
            }catch{
                
                print("Release decode error:",error)
                self.close()
            }
            
        }.resume()
    }
    
    // MARK: Image
    func downloadImage(
        artist:String,
        title:String,
        format:String,
        year:String,
        country:String,
        imageURL:String,
        catno: String,
        releaseId: String
    ){
        
        print("ImageURL:",imageURL)
        
        guard let url = URL(string:imageURL) else {
            
            save(
                artist:artist,
                title:title,
                format:format,
                year:year,
                country:country,
                image:nil,
                catno:catno,
                releaseId: releaseId
            )
            
            return
        }
        
        URLSession.shared.dataTask(with:url){ data,_,_ in
            
            var imageData:Data? = nil
            
            if let data = data,
               let image = UIImage(data:data){
                
                let resized = image.resize3(targetSize:CGSize(width:80,height:80))
                imageData = resized.jpegData(compressionQuality:0.1)
            }
            
            self.save(
                artist:artist,
                title:title,
                format:format,
                year:year,
                country:country,
                image:imageData,
                catno:catno,
                releaseId: releaseId
            )
            
        }.resume()
    }
    
    
    // MARK: UserAgent
    func userAgent()->String{
        
        let bundleName = Bundle.main.object(forInfoDictionaryKey:"CFBundleName") ?? ""
        let bundleVersion = Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") ?? ""
        let systemName = UIDevice.current.systemName
        let systemVersion = UIDevice.current.systemVersion
        
        return "\(bundleName)/\(bundleVersion) \(systemName)/\(systemVersion)"
    }
    
    func close(){
        extensionContext?.completeRequest(returningItems:[],completionHandler:nil)
    }
    
    override func configurationItems() -> [Any]! {
        []
    }
    
    func save(
        artist: String,
        title: String,
        format: String,
        year: String,
        country: String,
        image: Data?,
        catno: String,
        releaseId: String
    ) {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.marume3591.RecoColle2") else {
            print("App Group not found")
            close()
            return
        }

        // 既存のJSONを読み込む
        let fileURL = containerURL.appendingPathComponent("pending_records.json")
        var records: [[String: Any]] = []

        if let data = try? Data(contentsOf: fileURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            records = existing
        }

        // 新しいレコードを追加
        var newRecord: [String: Any] = [
            "artistName": artist,
            "albumTitle": title,
            "format": format,
            "releaseDate": year,
            "releaseCountry": country,
            "wantsFlg": "false",
            "id": UUID().uuidString,
            "memo": catno.isEmpty ? "" : "CATNO: \(catno)",
            "discogsReleaseId": releaseId
        ]

        if let image = image {
            newRecord["albumImage"] = image.base64EncodedString()
        }

        records.append(newRecord)

        // JSONファイルに書き込む
        do {
            let data = try JSONSerialization.data(withJSONObject: records)
            try data.write(to: fileURL)
            print("✅ App Group JSON保存成功")
        } catch {
            print("❌ App Group JSON保存失敗:", error)
        }

        DispatchQueue.main.async {
            self.close()
        }
    }
}

extension UIImage {

    func resize3(targetSize:CGSize)->UIImage{

        UIGraphicsImageRenderer(size:targetSize).image{_ in
            draw(in:CGRect(origin:.zero,size:targetSize))
        }
    }
}

class DummyPreview:UIView{

    override var intrinsicContentSize:CGSize{
        CGSize(width:1,height:120)
    }
}
