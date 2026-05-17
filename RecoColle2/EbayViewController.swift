//
//  EbayViewController.swift
//  RecoColle2
//
//  Created by 丸田信一 on 2024/05/30.
//

import UIKit

class EbayViewController: UIViewController, UIViewControllerTransitioningDelegate {
    
    var noimage = UIImage(named:"noimage")!
    var recordList: RecordList2!
    var accessToken: String = ""
    var Count = 0
    var itemSummary : [ItemSummary] = []{
        didSet{
            TableView.reloadData()
        }
    }
    var pageCnt = 0
    var pageMax = 0
    /// セマフォ
    var semaphore : DispatchSemaphore!
    var sortName = ""
    var aucName = "ALL"
    
    @IBOutlet weak var TableView: UITableView!

    @IBOutlet weak var Total: UILabel!
    @IBOutlet weak var StepperCnt: UILabel!
    @IBOutlet weak var mystepper: UIStepper!
    @IBAction func MyStepper(_ sender: UIStepper) {
            StepperCnt.text = String(format: "%.0f", (1 + sender.value))
            StepperCnt.text = "Page " + String(pageMax) + " / " + StepperCnt.text!
            pageCnt = Int(sender.value)
            syncHttpRequest()
    }
    @IBAction func tapButton2(_ sender: UIButton) {
        StepperCnt.text = ""
        pageCnt = 0
        pageMax = 0
        mystepper.value = 0
        // モーダル作成
        let ModalVC = self.storyboard?.instantiateViewController(identifier: "ModalViewController") as? ModalViewController
        // トランジションの実装
        ModalVC?.transitioningDelegate = self
        ModalVC?.modalPresentationStyle = .pageSheet
        // リスト、クロージャーを設定
        let list = ["ALL", "AUCTION", "FIXED_PRICE"]
        ModalVC?.list = list
        ModalVC?.closure = { index in
            let name = list[index]
            self.aucName = list[index]
            sender.setTitle("\(name)", for: .normal)

            self.syncHttpRequest()
        }
        self.present(ModalVC!, animated: true, completion: nil)

    }
    @IBAction func tapButton(_ sender: UIButton) {
        StepperCnt.text = ""
        pageCnt = 0
        pageMax = 0
        mystepper.value = 0
        // モーダル作成
        let ModalVC = self.storyboard?.instantiateViewController(identifier: "ModalViewController") as? ModalViewController
        // トランジションの実装
        ModalVC?.transitioningDelegate = self
        ModalVC?.modalPresentationStyle = .pageSheet
        // リスト、クロージャーを設定
        let list = ["lowest first", "highest first", "ending soonest", "newly listed"]
        ModalVC?.list = list
        ModalVC?.closure = { index in
            let name = list[index]
            self.sortName = list[index]
            sender.setTitle("\(name)", for: .normal)

            self.syncHttpRequest()
        }
        self.present(ModalVC!, animated: true, completion: nil)

    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        TableView.showsVerticalScrollIndicator = false
        syncHttpRequest()
    }
    func syncHttpRequest()
    {
        semaphore = DispatchSemaphore(value: 0)

        // Httpリクエストの生成
        let apiURL = "https://api.ebay.com/identity/v1/oauth2/token"
        let api = apiURL.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)!
        let url: URL = URL(string: api)!
        var request = URLRequest(url: url)
        // ②リクエストのプロパティを記入
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.addValue("Basic c2hpbmljaGktUmVjb0NvbGwtUFJELTM1ZWZjY2FkMC03ZjdiOTIzMDpQUkQtNWVmY2NhZDA2MjVmLTQ3MGYtNGNkOC1hYTBkLTk2MTQ=", forHTTPHeaderField: "Authorization")
        
        //POST、PUTの場合
        //クエリデータの作成
        let data : Data = "grant_type=client_credentials&scope=https%3A%2F%2Fapi.ebay.com%2Foauth%2Fapi_scope".data(using: .utf8)!

        request.httpBody = data

        // HTTPリクエスト実行
        URLSession.shared.dataTask(with: request, completionHandler: requestCompleteHandler).resume()

        // requestCompleteHandler内でsemaphore.signal()が呼び出されるまで待機する
        semaphore.wait()
        print("request completed")
        ebaySearch()
    }

    func requestCompleteHandler(data:Data?,response:URLResponse?,error:Error?)
    {
        print("response recieve")
        if let error = error {
            print("Failed to get item info: \(error)")
        }
        if let response = response as? HTTPURLResponse {
            if !(200...299).contains(response.statusCode) {
                print("Response status code does not indicate success: \(response.statusCode)")
            }
        }
        if let data = data {
            do {
                //jsonDictはサーバーにある情報をjson型で取得
                let jsonDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                
                self.accessToken = jsonDict!["access_token"] as! String
                
             } catch {
                 print("Error parsing the response.")
             }
         } else {
             print("Unexpected error.")
         }
        semaphore.signal()
    }
    
    func ebaySearch(){
        let keywords = recordList.artistName! + " " + recordList.albumTitle!
        let cnt = pageCnt * 200
        var sort = ""
        switch sortName {
          case "lowest first":
            sort = "price"
          case "highest first":
            sort = "-price"
          case "ending soonest":
            sort = "endingSoonest"
        default:
            sort = "newlyListed"
        }
        var api = ""
        if aucName == "ALL" {
            let apiURL = "https://api.ebay.com/buy/browse/v1/item_summary/search?q=\(keywords)&category_ids=11233&filter=buyingOptions:{AUCTION|FIXED_PRICE}&limit=200&offset=\(cnt)&sort=\(sort)"
            api = apiURL.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)!
        }else{
            let apiURL = "https://api.ebay.com/buy/browse/v1/item_summary/search?q=\(keywords)&category_ids=11233&filter=buyingOptions:{\(aucName)}&limit=200&offset=\(cnt)&sort=\(sort)"
            api = apiURL.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)!
        }
        //apiURLをURl型に変換する
        let url: URL = URL(string: api)!
        var request = URLRequest(url: url)
        // ②リクエストのプロパティを記入
        request.httpMethod = "GET"
        request.setValue( "Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        //URLSessionでサーバーにアクセス
        URLSession.shared.dataTask(with: request) { [self](data, response, error) in
            if let error = error {
                print("Failed to get item info: \(error)")
                return;
            }
            
            if let response = response as? HTTPURLResponse {
                if !(200...299).contains(response.statusCode) {
                    print("Response status code does not indicate success: \(response.statusCode)")
                    return
                }
            }
            
            if let data = data {
                do {
                    let RootClass:RootClass = try JSONDecoder().decode(RootClass.self, from: data)
                    DispatchQueue.main.async() { () -> Void in
                        self.itemSummary = RootClass.itemSummaries ?? []
                    if RootClass.total == 0 {
                        self.Total.text = "0"
                        self.StepperCnt.text = "There are no items"
                        self.Count = self.itemSummary.count
                        self.TableView.reloadData()
                    }else{
                        self.Total.text = String(RootClass.total!)
                        self.pageMax = RootClass.total! / 200
                        if (RootClass.total! % 200) != 0 {
                            self.pageMax = self.pageMax + 1
                        }
                        self.mystepper.maximumValue = Double(self.pageMax) - 1
                        self.mystepper.wraps = false
                        self.mystepper.autorepeat = true

                        if self.StepperCnt.text == "" {
                            self.StepperCnt.text = "Page " + String(self.pageMax) + " / 1"
                            self.pageCnt = 1
                        }
                        self.Count = self.itemSummary.count
                        self.TableView.reloadData()
                        }
                    }
                } catch {
                    print("Error parsing the response.")
                }
            } else {
                print("Unexpected error.")
            }
        }.resume()
        
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension EbayViewController: UITableViewDelegate, UITableViewDataSource {
    
    /// データの数（＝セルの数）を返すメソッド
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    // セクションの数
    func numberOfSections(in tableView: UITableView) -> Int {
        return Count
    }
    //
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        return 100
    }
    // 各セルの内容を返すメソッド
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = TableView.dequeueReusableCell(withIdentifier: "TableViewCell", for: indexPath)
        
        let albumImage = cell.contentView.viewWithTag(1) as! UIImageView
        //albumImage.image = UIImage(data: "".data(using: String.Encoding.utf8)! as Data)
        if itemSummary[indexPath.section].image?.imageUrl != nil {
            let imageData = itemSummary[indexPath.section].image?.imageUrl
            let url = URL(string: imageData!)
            albumImage.loadImageAsynchronously(url: url, defaultUIImage: nil)
        }else{
            albumImage.image = noimage
        }
        let title = cell.contentView.viewWithTag(2) as! UILabel
        title.text = itemSummary[indexPath.section].title
        let options = cell.contentView.viewWithTag(3) as! UILabel
        options.text = itemSummary[indexPath.section].buyingOptions?.first
        let currency = cell.contentView.viewWithTag(4) as! UILabel
        let value = cell.contentView.viewWithTag(5) as! UILabel
        if options.text == "AUCTION" {
            currency.text = itemSummary[indexPath.section].currentBidPrice?.currency
            value.text = itemSummary[indexPath.section].currentBidPrice?.value
        }else{
            currency.text = itemSummary[indexPath.section].price?.currency
            value.text = itemSummary[indexPath.section].price?.value
        }

        let bid = cell.contentView.viewWithTag(6) as! UILabel
        if itemSummary[indexPath.section].bidCount == nil{
            bid.text = ""
        }else{
            let bidCount = Int(itemSummary[indexPath.section].bidCount!)
            bid.text = "bid " + "\(String(describing: bidCount))"
        }
        let endDate = cell.contentView.viewWithTag(7) as! UILabel
        
        if itemSummary[indexPath.section].itemEndDate != nil {
            
            let startIndex = itemSummary[indexPath.section].itemEndDate!.index(itemSummary[indexPath.section].itemEndDate!.startIndex, offsetBy: 11)
            let endIndex = itemSummary[indexPath.section].itemEndDate!.index(itemSummary[indexPath.section].itemEndDate!.endIndex,offsetBy: -6)
            let datetxt2 = itemSummary[indexPath.section].itemEndDate![startIndex...endIndex]
            let datetxt1 = itemSummary[indexPath.section].itemEndDate!.prefix(10)
            endDate.text = datetxt1 + " " + datetxt2
        }else{
            endDate.text = ""
        }
        
        
//        endDate.text = itemSummary[indexPath.section].itemEndDate


        let indexLabel = cell.contentView.viewWithTag(8) as! UILabel
        indexLabel.text = String(indexPath.section + 1)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let ebayUrl = itemSummary[indexPath.section].itemWebUrl
//        let url = NSURL(string: ebayUrl!)
//        print("wwwwww")
//        print(url as Any)
//        if UIApplication.shared.canOpenURL(url! as URL){
//            UIApplication.shared.open(url! as URL, options: [:], completionHandler: nil)
//        }
        
        
        let webView = self.storyboard?.instantiateViewController(withIdentifier: "MyWebView") as! WebViewController
        webView.url = ebayUrl ?? ""
        print("wwwwww")
        print(webView.url as String)
        
        self.present(webView, animated: true, completion: nil)
    }

}

// defaultUIImageには、URLからの読込に失敗した時の画像を指定する
extension UIImageView {
  func loadImageAsynchronously(url: URL?, defaultUIImage: UIImage? = nil) -> Void {
    if url == nil {
      self.image = defaultUIImage
      return
    }
 
    DispatchQueue.global().async {
      do {
        let imageData: Data? = try Data(contentsOf: url!)
        DispatchQueue.main.async {
          if let data = imageData {
            self.image = UIImage(data: data)
          } else {
            self.image = defaultUIImage
          }
        }
      }
      catch {
        DispatchQueue.main.async {
          self.image = defaultUIImage
        }
      }
    }
  }
}
