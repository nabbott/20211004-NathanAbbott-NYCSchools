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
    
    @IBOutlet weak var webkitView:WKWebView!
    
    override
    func viewDidLoad() {
        guard var ws=website else {
            return
        }
        
        
        if !ws.starts(with: "http") {
            ws="https://\(ws)"
        }
        
        //FIXME: Occasionally websites fail to load, possible because of a malformed url
        //These errors should be captured and the user given a chance to retry or abandon the operation
        os_log(.debug, "Opening url: %@", "\(ws)")
        let url = URL(string:ws)
        let req = URLRequest(url: url!)
        webkitView.load(req)
    }
}

