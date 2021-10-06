//
//  ViewController.swift
//  JPMCPrototype
//
//  Created by Nathan Abbott on 10/1/21.
//

import UIKit
import CoreData
import os

struct SortByFilterBy {
    var sortAscending:Bool
    var filterByBorough:[String]?
}

class DirectoryViewController: UIViewController {
    @IBOutlet weak var highSchools:UITableView!
    
    var sortByFilterBy:SortByFilterBy? {
        didSet {
            if case .none = sortByFilterBy {
                highSchoolsFR.predicate=nil
                highSchoolsFR.sortDescriptors=ascendingSort
            } else {
                highSchoolsFR.sortDescriptors=sortByFilterBy!.sortAscending ? ascendingSort:descendingSort
                if let b=sortByFilterBy?.filterByBorough {
                    let predicate=NSPredicate(format: "address.borough in %@", b)
                    highSchoolsFR.predicate=predicate
                } else {
                    highSchoolsFR.predicate=nil
                }
            }
            
            self.performFetch()
            self.highSchools.reloadData()
        }
    }
    
    let ascendingSort:[NSSortDescriptor]=[
        NSSortDescriptor(key: "address.borough", ascending: true),
        NSSortDescriptor(key: "schoolName", ascending: true)
    ]
    
    let descendingSort:[NSSortDescriptor]=[
        NSSortDescriptor(key: "address.borough", ascending: false),
        NSSortDescriptor(key: "schoolName", ascending: false)
    ]
    
    lazy var highSchoolsFR:NSFetchRequest<HighSchool> = {
        let request:NSFetchRequest<HighSchool>=NSFetchRequest(entityName: "HighSchool"),
        oid:NSExpressionDescription={
            let expr=NSExpressionDescription()
            expr.expressionResultType=NSAttributeType.objectIDAttributeType
            expr.expression=NSExpression.expressionForEvaluatedObject()
            expr.name="objectID"
            return expr
        }()
        
        request.resultType = .managedObjectResultType
        request.sortDescriptors=ascendingSort
        request.propertiesToFetch=["schoolName"]
        
        return request
    }()
    
    lazy var data:NSFetchedResultsController<HighSchool>={
        let moc:NSManagedObjectContext=(UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let fetchRequest:NSFetchRequest<HighSchool>=highSchoolsFR
        let frc:NSFetchedResultsController<HighSchool>=NSFetchedResultsController(
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
            var items:[UIBarButtonItem]=[]
            #if DEBUG
            if #available(iOS 13.0, *) {
                let bbi=UIBarButtonItem(image:UIImage(systemName: "arrow.2.circlepath.circle.fill"), style: .plain, target: self, action: #selector(deleteAndImportHSData(sender:)))
                items.append(bbi)
            } else {
                items.append(UIBarButtonItem(title: "Reload", style: .plain, target: self, action: #selector(deleteAndImportHSData(sender:))))
            }
            #endif

            if #available(iOS 13.0, *) {
                let bbi=UIBarButtonItem(image: UIImage(systemName: "map"), style: .plain, target: self, action: #selector(showMap(sender:)))
                items.append(bbi)
            } else {
                items.append(UIBarButtonItem(title: "Map", style: .plain, target: self, action: #selector(showMap(sender:))))
            }
            
            if #available(iOS 13.0, *) {
                let bbi=UIBarButtonItem(image: UIImage(systemName: "line.horizontal.3.decrease.circle"), style: .plain, target: self, action: #selector(filter(sender:)))
                items.append(bbi)
            } else {
                items.append(UIBarButtonItem(title: "Filter", style: .plain, target: self, action: #selector(filter(sender:))))
            }
            
            return items
        }(), animated: false)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadData(sender:)),
                                               name: .NSManagedObjectContextObjectsDidChange,
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
    func filter(sender:UIControl){
        guard let filterController=storyboard?.instantiateViewController(withIdentifier: "filter") else {return}
        present(filterController, animated: true, completion: nil)
    }
    
    @IBAction func returnFromFilterPopup(unwindSegue: UIStoryboardSegue) {
        
    }

    
    @objc
    func reloadData(sender:NSNotification){
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
        cell.name.text = self.data.object(at: indexPath).schoolName ?? "Not Available"
        
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
            
            let oid=self.data.object(at: selectedIndex).objectID
            
            if let destination=segue.destination as? DetailViewController {
                let moc=(UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
                let hs=moc.object(with: oid) as! HighSchool
                destination.highschool=hs
            }
        case "showLocations":
            if let destination=segue.destination as? LocationViewController {
                let fr=highSchoolsFR.copy() as! NSFetchRequest<HighSchool>
                fr.relationshipKeyPathsForPrefetching=["address"]
                
                let results=try! (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext.fetch(fr)
                destination.highSchools.append(contentsOf: results)
            }
        default:
            return
        }
    }
}
