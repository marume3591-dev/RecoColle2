//
//  AboutViewController.swift
//  RecoColle2
//
//  Created by 丸田信一 on 2023/10/09.
//

import UIKit
import WebKit

class AboutViewController: UIViewController, WKNavigationDelegate {

    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("about_title", comment: "")
        view.backgroundColor = .systemBackground
        
        // WebView設定
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(webView)
        
        // AutoLayout
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // URL読み込み
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().removeData(ofTypes: dataTypes, modifiedSince: Date(timeIntervalSince1970: 0)) { [weak self] in
            if let url = URL(string: "https://recocolle2.web.fc2.com/index.htm") {
                let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
                self?.webView.load(request)
            }
        }
    }
    
    // 読み込み失敗時
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showErrorAlert()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showErrorAlert()
    }
    
    private func showErrorAlert() {
        let alert = UIAlertController(
            title: NSLocalizedString("connection_error_title", comment: ""),
            message: NSLocalizedString("connection_error_message", comment: ""),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok_button", comment: ""), style: .default))
        present(alert, animated: true)
    }
}
