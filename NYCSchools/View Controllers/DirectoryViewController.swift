
//
//  ViewController.swift
//  JPMCPrototype
//
//  Created by Nathan Abbott on 10/1/21.
//

import UIKit
import CoreData
import os
import Dispatch

struct SortByFilterBy {
    var sortAscending:Bool
    var filterByBorough:[String]?
}

fileprivate
let ascendingSort:[NSSortDescriptor]=[
    NSSortDescriptor(key: "address.borough", ascending: true),
    NSSortDescriptor(key: "schoolName", ascending: true)
]

fileprivate
let descendingSort:[NSSortDescriptor]=[
    NSSortDescriptor(key: "address.borough", ascending: false),
    NSSortDescriptor(key: "schoolName", ascending: false)
]

fileprivate
func defaultFetchRequest()->NSFetchRequest<HighSchool> {
    let request:NSFetchRequest<HighSchool>=NSFetchRequest(entityName: "HighSchool")
    
    request.resultType = .managedObjectResultType
    request.sortDescriptors=ascendingSort
    request.propertiesToFetch=["schoolName","address"]
    request.relationshipKeyPathsForPrefetching=["address"]
    request.returnsObjectsAsFaults=false
    
    return request
}

fileprivate
func searchFetchRequest(_ searchText:String, fetchReq:NSFetchRequest<HighSchool>? = nil)->NSFetchRequest<HighSchool> {
    let req=fetchReq ?? defaultFetchRequest()
    guard searchText.count >  0 else {
        return  req
    }
    
    req.predicate=NSPredicate(format: "schoolName like[c] %@", "*\(searchText)*")
    return req
}

fileprivate
func fetchedResultsController<E>(_ fetchRequest:NSFetchRequest<E>) -> NSFetchedResultsController<E> where E:NSManagedObject {
    let moc:NSManagedObjectContext=(UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    let fetchRequest:NSFetchRequest<E>=fetchRequest
    let frc:NSFetchedResultsController<E>=NSFetchedResultsController(
        fetchRequest: fetchRequest,
        managedObjectContext: moc,
        sectionNameKeyPath: "address.borough",
        cacheName: "schools")

    return frc
}

class DirectoryViewController: UIViewController {
    @IBOutlet weak var directoryView:UIView!
    @IBOutlet weak var highSchools:UITableView!
    
    @IBOutlet weak var loadingIndicatorView:UIView!
    @IBOutlet weak var loadingIndicator:UIActivityIndicatorView!
    @IBOutlet weak var loadingLabel:UILabel!

    
    @IBOutlet weak var searchBar:UISearchBar!
    @IBOutlet weak var seachResultsView:UIView!
    @IBOutlet weak var searchText:UILabel!
    
    
    var sortByFilterBy:SortByFilterBy? {
        didSet {
            if case .none = sortByFilterBy {
                schoolsFetchedResultsContoller = fetchedResultsController(defaultFetchRequest())
            } else {
                let sfr=schoolsFetchedResultsContoller.fetchRequest
                sfr.sortDescriptors=sortByFilterBy!.sortAscending ? ascendingSort:descendingSort
                if let b=sortByFilterBy?.filterByBorough {
                    var filterPredicate=NSPredicate(format: "address.borough in %@", b)
                    if let predicate=sfr.predicate {
                        filterPredicate=NSCompoundPredicate(andPredicateWithSubpredicates: [filterPredicate,predicate])
                    }
                    
                    sfr.predicate=filterPredicate
                } else {
                    sfr.predicate=nil
                }
                schoolsFetchedResultsContoller = fetchedResultsController(sfr)
            }
        }
    }
    
    lazy var schoolsFetchedResultsContoller = fetchedResultsController(defaultFetchRequest()) {
        didSet {
            do {
                try schoolsFetchedResultsContoller.performFetch()
                self.highSchools.reloadData()
            } catch {
                os_log(.error, log: .default, "@%", error.localizedDescription)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(refreshDataAfertMOCUpdate(sender:)),
                                               name: .NSManagedObjectContextObjectsDidChange,
                                               object: (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext)
        self.setupToolbar()
        do {
            try schoolsFetchedResultsContoller.performFetch()
            self.highSchools.reloadData()
        } catch {
            os_log(.error, log: .default, "@%", error.localizedDescription)
        }
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        if (UIApplication.shared.delegate as! AppDelegate).isLoadingSchools {
            showLoadingView()
        }
    }
    
    func setupToolbar(){
        self.setToolbarItems({
            var items:[UIBarButtonItem]=[]
            #if DEBUG
            if #available(iOS 13.0, *) {
                let bbi=UIBarButtonItem(image:UIImage(systemName: "arrow.2.circlepath.circle.fill"), style: .plain, target: self, action: #selector(deleteAndImportHSData(sender:)))
                bbi.possibleTitles=["Reload"]
                items.append(bbi)
            } else {
                items.append(UIBarButtonItem(title: "Reload", style: .plain, target: self, action: #selector(deleteAndImportHSData(sender:))))
            }
            #endif

            if #available(iOS 13.0, *) {
                let bbi=UIBarButtonItem(image: UIImage(systemName: "map"), style: .plain, target: self, action: #selector(showMap(sender:)))
                bbi.possibleTitles=["Map"]
                items.append(bbi)
            } else {
                items.append(UIBarButtonItem(title: "Map", style: .plain, target: self, action: #selector(showMap(sender:))))
            }
            
            if #available(iOS 13.0, *) {
                let bbi=UIBarButtonItem(image: UIImage(systemName: "line.horizontal.3.decrease.circle"), style: .plain, target: self, action: #selector(filter(sender:)))
                bbi.possibleTitles=["Filter"]
                items.append(bbi)
            } else {
                items.append(UIBarButtonItem(title: "Filter", style: .plain, target: self, action: #selector(filter(sender:))))
            }
            
            if #available(iOS 13.0, *) {
                let bbi=UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(search(sender:)))
                bbi.possibleTitles=["Search"]
                items.append(bbi)
            } else {
                items.append(UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(search(sender:))))
            }
            
            return items
        }(), animated: false)
    }
    
    //MARK: - Toolbar actions
    @objc
    func deleteAndImportHSData(sender:UIControl){
        let alert=UIAlertController(title: "Reload", message: "Reloading will delete the entire database and re-import the data from a known good source", preferredStyle: UIAlertController.Style.alert)
        let cancel:UIAlertAction=UIAlertAction(title: "Cancel", style: .cancel, handler:{(_)->() in })
        let ok:UIAlertAction=UIAlertAction(title: "Ok", style: .default, handler:{[weak self](_)->() in
            self?.showLoadingView()
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
    
    //FIXME: Set the borough to the curent setting if there is one
    @objc
    func filter(sender:UIControl){
        guard let filterController=storyboard?.instantiateViewController(withIdentifier: "filter") else {return}
        present(filterController, animated: true, completion: nil)
    }
    
    @objc
    func search(sender:UIControl){
        searchBar.text=nil
        UIView.animate(withDuration: view.defaultAnimationDuration, animations: {self.searchBar.isHidden=false})
    }
    
    //Target for the unwind segue from the filter dialog
    @IBAction func returnFromFilterPopup(unwindSegue: UIStoryboardSegue) {}
    
    @IBAction func showAll(sender:UIControl) {
        schoolsFetchedResultsContoller=fetchedResultsController(defaultFetchRequest())
        UIView.animate(withDuration: view.defaultAnimationDuration, animations: {
            self.resetSearchViews()
        })
    }
    
    //MARK: - Handling changes in the context
    //FIXME: Change this to "reload in response to changes in context"
    @objc
    func refreshDataAfertMOCUpdate(sender:NSNotification){
        //This is called via notifications that the managed object context has persisted changes
        //which may not occur on the main thread.
        DispatchQueue.main.async {
            self.schoolsFetchedResultsContoller=fetchedResultsController(defaultFetchRequest())
            
            self.resetSearchViews()
            self.hideLoadingView()
        }
    }
    
    func showLoadingView(){
        UIView.animate(withDuration: view.defaultAnimationDuration, animations: {[unowned self] in
            self.loadingIndicator.startAnimating()
            self.loadingIndicatorView.isHidden=false
            self.directoryView.isHidden=true
        })
    }
    
    func hideLoadingView(){
        UIView.animate(withDuration: view.defaultAnimationDuration, animations: {[unowned self] in
            self.loadingIndicatorView.isHidden=true
            self.loadingIndicator.stopAnimating()
            self.directoryView.isHidden=false
        })
    }
    
    func resetSearchViews(){
        searchBar.isHidden=true
        searchBar.text=nil
        
        searchText.text=nil
        seachResultsView.isHidden=true
    }
}

extension DirectoryViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.schoolsFetchedResultsContoller.sections?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sections=self.schoolsFetchedResultsContoller.sections, sections.count > section else {return nil}
        return sections[section].name
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.schoolsFetchedResultsContoller.sections?[section].numberOfObjects ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell=tableView.dequeueReusableCell(withIdentifier:"HSName", for:indexPath) as! HSTableCellView
        cell.name.text = self.schoolsFetchedResultsContoller.object(at: indexPath).schoolName ?? "Not Available"
        return cell
    }
}

extension DirectoryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {}
}

//MARK: - Search Handlers
extension DirectoryViewController:UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        os_log(.debug,"Search text did change")
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        defer {
            searchBar.resignFirstResponder()
            UIView.animate(withDuration: view.defaultAnimationDuration, animations: {
                searchBar.isHidden=true
                self.searchText.text=searchBar.text
                self.seachResultsView.isHidden = (searchBar.text?.isEmpty ?? true)
            })
        }
        
        guard let sText=searchBar.text, !sText.isEmpty else {
            return
        }
        
        let searchFR=searchFetchRequest(sText, fetchReq: schoolsFetchedResultsContoller.fetchRequest)
        self.schoolsFetchedResultsContoller=fetchedResultsController(searchFR)
    }
}

//MARK: - Segue Handlers
extension DirectoryViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "detail":
            guard let selectedIndex=self.highSchools.indexPathForSelectedRow else {
                return
            }
            
            let oid=self.schoolsFetchedResultsContoller.object(at: selectedIndex).objectID
            
            if let destination=segue.destination as? DetailViewController {
                let moc=(UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
                let hs=moc.object(with: oid) as! HighSchool
                destination.highschool=hs
            }
        case "showLocations":
            if let destination=segue.destination as? LocationViewController {
                let fr=schoolsFetchedResultsContoller.fetchRequest.copy() as! NSFetchRequest<HighSchool>
                fr.resultType = .managedObjectResultType
                fr.relationshipKeyPathsForPrefetching=["address"]
                
                let results=try! (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext.fetch(fr)
                destination.highSchools.append(contentsOf: results)
            }
        default:
            return
        }
    }
}
