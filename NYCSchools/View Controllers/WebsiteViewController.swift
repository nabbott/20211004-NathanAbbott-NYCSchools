//
//  ViewController.swift
//  JPMCPrototype
//
//  Created by Nathan Abbott on 10/1/21.
//

import UIKit
import CoreData
import os
import WebKit

class WebsiteViewController: UIViewController {
    var website:String?
    var school:String?
    
    let maxLoadAttempts=2
    lazy var loadAttempts=maxLoadAttempts
    
    @IBOutlet weak var activityIndicatorView:UIView!
    @IBOutlet weak var actitityIndicator:UIActivityIndicatorView!
    @IBOutlet weak var activityLabel:UILabel!
    @IBOutlet weak var webkitView:WKWebView! {
        didSet {
            webkitView.navigationDelegate=self
        }
    }
    
    override
    func viewDidLoad() {
        loadWebsite()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        loadAttempts=maxLoadAttempts
        
        navigationController?.setToolbarHidden(true, animated: animated)
        actitityIndicator.startAnimating()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        navigationController?.setToolbarHidden(false, animated: animated)
    }
    
    func loadWebsite(useHTTPS:Bool=true){
        guard loadAttempts>0 else {
            os_log(.debug,"Load attempt limit exceeded")
            return
        }
        
        guard var ws=website else {
            return
        }
        
        if !ws.starts(with: "http") {
            ws="http\(useHTTPS ? "s":"")://\(ws)"
        }
        
        //FIXME: Occasionally websites fail to load, possible because of a malformed url
        //These errors should be captured and the user given a chance to retry or abandon the operation
        os_log(.debug, "Opening url: %@", "\(ws)")
        let url = URL(string:ws)
        let req = URLRequest(url: url!)
        webkitView.load(req)
        
        loadAttempts -= 1
    }
}

extension WebsiteViewController:WKNavigationDelegate {
    func webView(_ webView: WKWebView, didCommit: WKNavigation!){
        os_log(.error, "Website: %@ did commit",website!)
    }
    
    func webView(_ webView: WKWebView, didFinish: WKNavigation!){
        os_log(.error, "Website: %@ finished loading",website!)
        
        actitityIndicator.stopAnimating()
        UIView.animate(withDuration: 5){[unowned self] in
            self.activityIndicatorView.isHidden=true
            self.webkitView.isHidden=false
        }
    }
    
    //MARK: - Load Failures
    
    func handleLoadFail(){
        if loadAttempts > 0 {
            if let ws=website {
                os_log(.debug,"Attempting to load %@ over http",ws)
                loadWebsite(useHTTPS: false)
            }
            return
        }
        
        actitityIndicator.stopAnimating()
        activityLabel.text="Could not load \(school ?? "") website"
        
        UIView.animate(withDuration: 2){[unowned self] in
            self.actitityIndicator.isHidden=true
            self.activityIndicatorView.isHidden=false
            self.webkitView.isHidden=true
        }
    }
    
    func webView(_ webView: WKWebView, didFail: WKNavigation!, withError: Error){
        os_log(.error, "Website: %@ load failed with error: %@",website!,withError as NSError)
        handleLoadFail()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation: WKNavigation!, withError: Error){
        os_log(.error, "Website: %@ provisional load failed with error: %@",website!,withError as NSError)
        handleLoadFail()
    }
}
