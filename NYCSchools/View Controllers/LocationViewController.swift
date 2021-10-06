//
//  ViewController.swift
//  JPMCPrototype
//
//  Created by Nathan Abbott on 10/1/21.
//

import UIKit
import CoreData
import os
import MapKit
import CoreLocation

class LocationViewController: UIViewController {
    
    var highSchools:[HighSchool]=[]
    var centerOn:CLLocationCoordinate2D?
    
    @IBOutlet weak var mapView:MKMapView!
    
    override
    func viewDidLoad() {
        let schools=highSchools.filter {
            guard let lat=$0.address?.latitude, let long=$0.address?.longitude else {return false}
            return 0 != lat && 0 != long
        }
        
        schools.forEach {
            let annotation=HSLocation(coordinate: CLLocationCoordinate2DMake($0.address!.latitude, $0.address!.longitude), title: $0.schoolName, subtitle: nil)
            
            annotation.school=$0
            mapView.addAnnotation(annotation)
        }
        
        if let center=centerOn {
            let distance=UnitLength.miles.converter.baseUnitValue(fromValue: 0.5)
            mapView.setCenter(center, animated: true)
            mapView.setRegion(MKCoordinateRegion(center: center, latitudinalMeters: distance, longitudinalMeters: distance), animated: true)
        } else if let school = schools.first {
            let distance=UnitLength.miles.converter.baseUnitValue(fromValue: 20)
            let center=CLLocationCoordinate2D(latitude: school.address!.latitude, longitude: school.address!.longitude)
            mapView.setRegion(MKCoordinateRegion(center: center, latitudinalMeters: distance, longitudinalMeters: distance), animated: true)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setToolbarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        navigationController?.setToolbarHidden(false, animated: animated)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let mapView=sender as? MKMapView else {return}
        guard let selectedAnnotation=mapView.selectedAnnotations.first as? HSLocation else {return}
        
        if let destination=segue.destination as? DetailViewController, let school=selectedAnnotation.school {
            destination.highschool=school
        }
    }
}

class HSLocation:NSObject, MKAnnotation {
    var coordinate:CLLocationCoordinate2D
    var title:String?
    var subtitle:String?
    weak var school:HighSchool?
    
    init(coordinate:CLLocationCoordinate2D, title:String?, subtitle:String?) {
        self.coordinate=coordinate
        self.title=title
        self.subtitle=subtitle
    }
}

extension LocationViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let vc=navigationController?.viewControllers, vc.contains(where: {$0 is DetailViewController}) {
            return
        }
        
        performSegue(withIdentifier: "locationToDetail", sender: mapView)
    }
}
