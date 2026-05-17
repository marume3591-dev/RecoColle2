//
//  WebViewController.swift
//  RecoColle2
//
//  Created by 丸田信一 on 2024/08/16.
//

import UIKit
import WebKit

class WebViewController: UIViewController {

    @IBOutlet weak var wkWebView: WKWebView!
    var url: String!

    @IBAction func close(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    @IBAction func back(_ sender: UIButton) {
        wkWebView.goBack()
    }
    override func viewDidLoad() {
        print("55555")
        print(url as Any)
        let url = URL(string: url)
        let request = URLRequest(url: url!)
        wkWebView.load(request)
        super.viewDidLoad()

        // Do any additional setup after loading the view.
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
