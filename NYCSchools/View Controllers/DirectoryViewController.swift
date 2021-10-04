//
//  ViewController.swift
//  JPMCPrototype
//
//  Created by Nathan Abbott on 10/1/21.
//

import UIKit
import CoreData
import os

class DirectoryViewController: UIViewController {
    @IBOutlet weak var highSchools:UITableView!
    
    lazy var highSchoolsFR:NSFetchRequest<NSDictionary> = {
        let sortDescriptors:[NSSortDescriptor]=[
            NSSortDescriptor(key: "address.borough", ascending: true),
            NSSortDescriptor(key: "schoolName", ascending: true)
        ],
        request:NSFetchRequest<NSDictionary>=NSFetchRequest(entityName: "HighSchool"),
        oid:NSExpressionDescription={
            let expr=NSExpressionDescription()
            expr.expressionResultType=NSAttributeType.objectIDAttributeType
            expr.expression=NSExpression.expressionForEvaluatedObject()
            expr.name="objectID"
            return expr
        }()
        
        request.resultType = .dictionaryResultType
        request.sortDescriptors=sortDescriptors
        request.returnsObjectsAsFaults=false
        request.propertiesToFetch=["schoolName","address.borough",oid]
        
        return request
    }()
    
    lazy var data:NSFetchedResultsController<NSDictionary>={
        let moc:NSManagedObjectContext=(UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let fetchRequest:NSFetchRequest<NSDictionary>=highSchoolsFR
        let frc:NSFetchedResultsController<NSDictionary>=NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: moc,
            sectionNameKeyPath: "address.borough",
            cacheName: "schools")

        return frc
    }()
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.setToolbarItems({
            return [
                UIBarButtonItem(title: "Map", style: .plain, target: self, action: #selector(showMap(sender:)))
            ]
        }(), animated: false)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadData(sender:)),
                                               name: .NSManagedObjectContextDidSave,
                                               object: (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext)
        
        self.performFetch()
    }
    
    func performFetch() {
        do {
            try self.data.performFetch()
        } catch {
            os_log(.error, log: .default, "@%", error.localizedDescription)
        }
    }
    
    @objc
    func deleteAndImportHSData(sender:UIControl){
        let alert=UIAlertController(title: "Reload", message: "Reloading will delete the entire database and re-import the data from a known good source", preferredStyle: UIAlertController.Style.alert)
        let cancel:UIAlertAction=UIAlertAction(title: "Cancel", style: .cancel, handler:{(_)->() in })
        let ok:UIAlertAction=UIAlertAction(title: "Ok", style: .default, handler:{(_)->() in
            (UIApplication.shared.delegate as! AppDelegate).clearAndReloadData()
        })
        
        alert.addAction(ok)
        alert.addAction(cancel)
        self.present(alert, animated: true, completion: nil)
    }
    
    @objc
    func showMap(sender:UIControl){
        self.performSegue(withIdentifier: "showLocations", sender: self)
    }
    
    @objc
    func reloadData(sender:UIControl){
        self.performFetch()
        self.highSchools.reloadData()
    }
}

extension DirectoryViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.data.sections?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sections=self.data.sections, sections.count > section else {return nil}
        
        return sections[section].name
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.data.sections?[section].numberOfObjects ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell=tableView.dequeueReusableCell(withIdentifier:"HSName", for:indexPath) as! HSTableCellView 
        cell.name.text = (self.data.object(at: indexPath)["schoolName"] as? String) ?? "Not Available"
        
        return cell
        
    }
}

extension DirectoryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "detail", sender: self)
    }
}

extension DirectoryViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "detail":
            guard let selectedIndex=self.highSchools.indexPathForSelectedRow else {
                return
            }
            
            guard let oid=self.data.object(at: selectedIndex)["objectID"] as? NSManagedObjectID else {
                return
            }
            
            if let destination=segue.destination as? DetailViewController {
                let moc=(UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
                let hs=moc.object(with: oid) as! HighSchool
                destination.highschool=hs
            }
        case "showLocations":
            if let destination=segue.destination as? LocationViewController {
                let fr=NSFetchRequest<HighSchool>(entityName: "HighSchool")
                fr.resultType = .managedObjectResultType
                let results=try! (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext.fetch(fr)
                destination.highSchools.append(contentsOf: results)
            }
        default:
            return
        }
    }
}
