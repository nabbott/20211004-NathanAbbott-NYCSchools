//
//  DetailViewController.swift
//  JPMCPrototype
//
//  Created by Nathan Abbott on 10/2/21.
//

import Foundation
import UIKit
import CoreLocation
import os

class DetailViewController:UIViewController {
    var highschool:HighSchool?
    
    @IBOutlet weak var name:UILabel!
    @IBOutlet weak var mathScores:UILabel!
    @IBOutlet weak var readingScores:UILabel!
    @IBOutlet weak var writingScores:UILabel!
    @IBOutlet weak var overview:UITextView!
    
    @IBOutlet weak var ap:UILabel!
    @IBOutlet weak var language:UILabel!
    @IBOutlet weak var extracurricular:UILabel!
    
    @IBOutlet weak var email:UILabel!
    @IBOutlet weak var phone:UILabel!
    @IBOutlet weak var fax:UILabel!
    @IBOutlet weak var address:UILabel!
    
    override
    func viewDidLoad() {
        setupToolbar()
        populateSATScores()
        populateAcademics()
        populateContactInfo()
    }
    
    func setupToolbar(){
        self.setToolbarItems({
            var items:[UIBarButtonItem]=[]
            if let _ = highschool?.website {
                if #available(iOS 13.0, *) {
                    let bbi=UIBarButtonItem(image: UIImage(systemName: "globe"), style: .plain, target: self, action: #selector(showWebsite(sender:)))
                    items.append(bbi)
                } else {
                    items.append(UIBarButtonItem(title: "Website", style: .plain, target: self, action: #selector(showWebsite(sender:))))
                }
            }
            
            if let addr=highschool?.address, 0 != addr.latitude && 0 != addr.longitude {
                if #available(iOS 13.0, *) {
                    let bbi=UIBarButtonItem(image: UIImage(systemName: "map"), style: .plain, target: self, action: #selector(showLocation(sender:)))
                    items.append(bbi)
                } else {
                    items.append(UIBarButtonItem(title: "Location", style: .plain, target: self, action: #selector(showLocation(sender:))))
                }
            }
            
            return items
        }(), animated: false)
    }
    
    //MARK: - Populate school info
    func populateContactInfo(){
        name.text=highschool?.schoolName ?? "Not Available"
        email.text=highschool?.schoolEmail ?? "Not Available"
        phone.text=highschool?.phoneNumber ?? "Not Available"
        fax.text=highschool?.faxNumber ?? "Not Available"
        address.text=highschool?.address?.primaryAddressLine1 ?? "Not Available"
    }
    
    func populateAcademics(){
        
        ap.text=highschool?.advancedPlacementCourses ?? "Not Available"
        language.text=highschool?.languageClasses ?? "Not Available"
        extracurricular.text=highschool?.extracurricularActivities ?? "Not Available"
        
        if let p=highschool?.overviewParagraph {
            overview.text=p
        }
    }
    
    func populateSATScores(){
        guard let satResult=highschool?.satResults else {
            mathScores.text="Results Unavailable"
            readingScores.text="Results Unavailable"
            writingScores.text="Results Unavailable"
            return
        }
        
        mathScores.text="\(satResult.satMathAvgScore)"
        readingScores.text="\(satResult.satCriticalReadingAvgScore)"
        writingScores.text="\(satResult.satWritingAvgScore)"
    }
    
    
    //MARK: - Segues
    @objc
    func showWebsite(sender:UIControl){
        self.performSegue(withIdentifier: "website", sender: self)
    }
    
    @objc
    func showLocation(sender:UIControl){
        self.performSegue(withIdentifier: "location", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "website":
            if let destination=segue.destination as? WebsiteViewController, let ws=highschool?.website {
                destination.website=ws
                destination.school=highschool?.schoolName
            }
        case "location":
            if let destination=segue.destination as? LocationViewController {
                destination.highSchools.append(highschool!)
                destination.centerOn=CLLocationCoordinate2DMake(highschool!.address!.latitude, highschool!.address!.longitude)
            }
        default:
            return
        }
    }
}
