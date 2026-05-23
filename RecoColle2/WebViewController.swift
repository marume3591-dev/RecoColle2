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
        super.viewDidLoad()
        wkWebView.navigationDelegate = self
        wkWebView.uiDelegate = self
        let url = URL(string: url)
        let request = URLRequest(url: url!)
        wkWebView.load(request)
    }

    private var safeAreaAdjusted = false

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        guard !safeAreaAdjusted else { return }
        safeAreaAdjusted = true
        let statusBarHeight = view.safeAreaInsets.top
        if statusBarHeight > 20 {
            additionalSafeAreaInsets = UIEdgeInsets(top: statusBarHeight - 20, left: 0, bottom: 0, right: 0)
        }
    }
}

// MARK: - WKNavigationDelegate
extension WebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
}

// MARK: - WKUIDelegate（_blankリンク対応）
extension WebViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // _blank等で新規ウィンドウを開こうとした場合、同じWebViewで読み込む
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
}
