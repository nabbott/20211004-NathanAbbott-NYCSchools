//
//  FilterViewController.swift
//  NYCSchools
//
//  Created by Nathan Abbott on 10/6/21.
//

import UIKit


class FilterViewController:UIViewController {
    @IBOutlet weak var boroughPicker:UIPickerView!
    @IBOutlet weak var sortOrder:UISegmentedControl!

    let boroughs=["All","Bronx","Brooklyn","Manhattan","Queens","Staten Is"]

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let targetVC=segue.destination as? DirectoryViewController else {return}
        
        let selectedRow=boroughPicker.selectedRow(inComponent: 0)
        let borough:[String]?=selectedRow>0 ? [boroughs[selectedRow].uppercased()] : nil
        
        var isAsc=true
        if sortOrder.selectedSegmentIndex==1 {
            isAsc=false
        }
        
        if case .none=borough, isAsc {
            targetVC.sortByFilterBy=nil
        } else {
            targetVC.sortByFilterBy=SortByFilterBy(sortAscending: isAsc, filterByBorough: borough)
        }
        
    }
}

extension FilterViewController:UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if component==0 {return boroughs.count}
        
        return 0
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        guard component==0 else {return nil}
        
        return boroughs[row]
    }
}
