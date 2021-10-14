
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




//MARK: - View Controller
class DirectoryViewController: UIViewController {
    @IBOutlet weak var directoryView:UIView!
    @IBOutlet weak var highSchools:UITableView!
    
    //Generic message
    @IBOutlet weak var loadingIndicatorView:UIView!
    @IBOutlet weak var loadingIndicator:UIActivityIndicatorView!
    @IBOutlet weak var loadingLabel:UILabel!

    //This is exposed when the user wishes to perform a search
    @IBOutlet weak var searchBar:UISearchBar!
    @IBOutlet weak var seachResultsView:UIView!
    @IBOutlet weak var searchText:UILabel!
    
    //This is exposed when the user wishes to filter the list
    @IBOutlet weak var filterView:UIView!
    @IBOutlet weak var filterText:UILabel!
    
    var searchPredicate:NSPredicate?  {
        didSet {
            loadDataAndRefreshTableView()
        }
    }

    
    //This set during the unwind segue from the filter dialog
    var sortByFilterBy:SortByFilterBy? {
        didSet {
            filterText.text=sortByFilterBy?.description
            if case .some = sortByFilterBy {
                UIView.animate(withDuration: UIAnimations.defaultAnimationDuration){
                    self.filterView.isHidden=false
                }
            } else {
                resetFilterViews()
            }
            
            loadDataAndRefreshTableView()
        }
    }
    
    lazy var schoolsFetchedResultsContoller = fetchedResultsController(fetchRequest: defaultFetchRequest(), moc: (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext)
    
    //FIXME: Prolly not necessary to redo the fetch all the time.
    func loadDataAndRefreshTableView(performFetch:Bool=true){
        var predicate:NSPredicate?
        switch (searchPredicate,sortByFilterBy?.predicate) {
        case (nil,let filterP?):
            predicate=filterP
        case (let searchP?, nil):
            predicate=searchP
        case (let searchP?, let filterP?):
            predicate=NSCompoundPredicate(andPredicateWithSubpredicates: [searchP,filterP])
        default:
            break
        }
        
        let fetchRequest=schoolsFetchedResultsContoller.fetchRequest
        fetchRequest.predicate=predicate
        fetchRequest.sortDescriptors=sortByFilterBy?.sortOrder.sortDescriptors ?? SortByFilterBy.SortOrder.asc.sortDescriptors
 
        do {
            if performFetch {
                try schoolsFetchedResultsContoller.performFetch()
            }
            self.highSchools.reloadData()
        } catch {
            let alertController=makeSimpleErrorAlert(msg: "An error occured during loading.")
            present(alertController, animated: true, completion: nil)
            
            os_log(.error, log: .default, "@%", error.localizedDescription)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(refreshDataAfterMOCUpdate(sender:)),
                                               name: .NSManagedObjectContextDidMergeChangesObjectIDs,
                                               object: (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext)
        self.setupToolbar()
        loadDataAndRefreshTableView()
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
    //FIXME: Set the borough to the curent setting if there is one
    @objc
    func filter(sender:UIControl){
        guard let fc=storyboard?.instantiateViewController(withIdentifier: "filter") as? FilterViewController else {
            return
        }
        
        fc.sortByFilterBy=sortByFilterBy
        
        present(fc, animated: true, completion: nil)
    }
    
    //Target for the unwind segue from the filter dialog
    @IBAction func returnFromFilterPopup(unwindSegue: UIStoryboardSegue) {}
    
    /// Displays the search dialog
    /// - Parameter sender: The toolbar item
    @objc
    func search(sender:UIControl){
        searchBar.text=nil
        UIView.animate(withDuration: UIAnimations.defaultAnimationDuration, animations: {self.searchBar.isHidden=false})
    }
    
    /// Hides the search related dialogs
    func resetSearchViews(){
        searchBar.isHidden=true
        searchBar.text=nil
        
        searchText.text=nil
        seachResultsView.isHidden=true
    }
    
    /// Hides the filter related dialogs
    func resetFilterViews(){
        UIView.animate(withDuration: UIAnimations.defaultAnimationDuration, animations: {
            self.filterView.isHidden=true
        })
    }
    
    @IBAction func showAll(sender:UIControl) {
        sortByFilterBy=nil
        searchPredicate=nil
        loadDataAndRefreshTableView()
        UIView.animate(withDuration: UIAnimations.defaultAnimationDuration, animations: {
            self.resetSearchViews()
        })
    }
    
    /// Removes the search from the table view and hides the search related dialogs
    /// - Parameter sender: The button that calls this function
    @IBAction func removeSearch(sender:UIControl){
        searchPredicate=nil
        loadDataAndRefreshTableView()
        UIView.animate(withDuration: UIAnimations.defaultAnimationDuration, animations: {
            self.resetSearchViews()
        })
    }
    
    /// Removes the filters from the table view fetch controller and hides the filter related dialogs
    /// - Parameter sender: The button that calls this function
    @IBAction func removeFilter(sender:UIControl){
        sortByFilterBy=nil
        loadDataAndRefreshTableView()
        UIView.animate(withDuration: UIAnimations.defaultAnimationDuration, animations: {
            self.resetFilterViews()
        })
    }
    
    @objc
    func showMap(sender:UIControl){
        self.performSegue(withIdentifier: "showLocations", sender: self)
    }
    
    //MARK: - Loading Dialog
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
    
    func showLoadingView(){
        self.navigationController?.setToolbarHidden(true, animated: true)
        UIView.animate(withDuration: UIAnimations.defaultAnimationDuration, animations: {[unowned self] in
            self.loadingIndicator.startAnimating()
            self.loadingIndicatorView.isHidden=false
            self.directoryView.isHidden=true
        })
    }
    
    func hideLoadingView(){
        self.navigationController?.setToolbarHidden(false, animated: true)
        UIView.animate(withDuration: UIAnimations.defaultAnimationDuration, animations: {[unowned self] in
            self.loadingIndicatorView.isHidden=true
            self.loadingIndicator.stopAnimating()
            self.directoryView.isHidden=false
        })
    }
    
    //MARK: - Handling changes in the context
    @objc
    func refreshDataAfterMOCUpdate(sender:NSNotification){
        //This is called via notifications that the managed object context has persisted changes
        //which may not occur on the main thread.
        DispatchQueue.main.async {
            self.loadDataAndRefreshTableView()
            
            self.resetSearchViews()
            self.hideLoadingView()
        }
    }
}

//MARK: - Table View Datasource Extension
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
        let cell=tableView.dequeueReusableCell(withIdentifier:"HSName", for:indexPath)
        
        let school=self.schoolsFetchedResultsContoller.object(at: indexPath)
        if #available(iOS 14, *) {
            var config=cell.defaultContentConfiguration()
            config.text=school.schoolName ?? "Not Available"
            if school.SATAverage >= 500 {
                config.image=UIImage(systemName: "star.fill")
            }
            cell.contentConfiguration=config
        } else {
            cell.textLabel!.text = school.schoolName ?? "Not Available"
        }
        
        return cell
    }
}

//MARK: - Table View Delegate
extension DirectoryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {}
}

//MARK: - Search Bar Delegate
extension DirectoryViewController:UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        defer {
            searchBar.resignFirstResponder()
            UIView.animate(withDuration: UIAnimations.defaultAnimationDuration, animations: {
                searchBar.isHidden=true
                self.searchText.text=searchBar.text
                self.seachResultsView.isHidden = (searchBar.text?.isEmpty ?? true)
            })
        }
        
        guard let sText=searchBar.text, !sText.isEmpty else {
            searchPredicate=nil
            return
        }
        
        searchPredicate=NSPredicate(format: "schoolName like[c] %@", "*\(sText)*")
    }
}

//MARK: - Segue Handlers
extension DirectoryViewController {
    
    func segueToDetail(_ segue: UIStoryboardSegue){
        guard let selectedIndex=self.highSchools.indexPathForSelectedRow else {
            return
        }
        
        let oid=self.schoolsFetchedResultsContoller.object(at: selectedIndex).objectID
        
        if let destination=segue.destination as? DetailViewController {
            let moc=(UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
            let hs=moc.object(with: oid) as! HighSchool
            destination.highschool=hs
        }
    }
    
    func segueToMap(_ segue: UIStoryboardSegue){
        if let destination=segue.destination as? LocationViewController {
            let fr=schoolsFetchedResultsContoller.fetchRequest.copy() as! NSFetchRequest<HighSchool>
            fr.resultType = .managedObjectResultType
            fr.relationshipKeyPathsForPrefetching=["address"]
            
            do {
                let results=try (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext.fetch(fr)
                destination.highSchools.append(contentsOf: results)
            } catch {
                let alertController=makeSimpleErrorAlert(msg: "An error occured building the map.")
                present(alertController, animated: true, completion: nil)
                
                os_log(.error,"%@",error as NSError)
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "detail":
            segueToDetail(segue)
        case "showLocations":
            segueToMap(segue)
        default:
            return
        }
    }
}
