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
    @IBOutlet weak var satScoreSlider:UISlider! 
    @IBOutlet weak var satScore:UILabel!
    
    @IBOutlet weak var filter:UIButton!
    
    var sortByFilterBy:SortByFilterBy?

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        guard let sbfb=sortByFilterBy else { return }
        
        if let b=sbfb.borough, let i=SortByFilterBy.boroughs.firstIndex(of: b) {
            boroughPicker.selectRow(i, inComponent: 0, animated: false)
        }
        
        sortOrder.selectedSegmentIndex=0
        if case .desc = sbfb.sortOrder {
            sortOrder.selectedSegmentIndex=1
        }
        
        satScore.text="\(sbfb.minCombinedSAT)"
        satScoreSlider.value=Float(sbfb.minCombinedSAT)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let targetVC=segue.destination as? DirectoryViewController else {return}
        
        if let filterButton=sender as? UIButton, filter===filterButton {
            let selectedRow=boroughPicker.selectedRow(inComponent: 0)
            let borough:String? = selectedRow>0 ? SortByFilterBy.boroughs[selectedRow] : nil
            
            let isAsc=sortOrder.selectedSegmentIndex==0 ? SortByFilterBy.SortOrder.asc : SortByFilterBy.SortOrder.desc
            let minSAT=Int(satScoreSlider.value)
            
            sortByFilterBy=SortByFilterBy(sortOrder: isAsc, borough: borough, minCombinedSAT: minSAT)
            targetVC.sortByFilterBy=sortByFilterBy
        } else {
            targetVC.sortByFilterBy=nil
        }
    }
    
    @IBAction func reset(sender:UIControl) {
        boroughPicker.selectRow(0, inComponent: 0, animated: false)
        sortOrder.selectedSegmentIndex=0
        satScoreSlider.value=0
        satScore.text="0"
        sortByFilterBy=nil
    }
    
    @IBAction func cancel(sender:UIControl){
        dismiss(animated: true)
    }
    
    @IBAction func satSliderDragged(sender:UISlider) {
        satScore.text="\(Int(sender.value))"
    }
}

extension FilterViewController:UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if component==0 {return SortByFilterBy.boroughs.count}
        
        return 0
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        guard component==0 else {return nil}
        
        return SortByFilterBy.boroughs[row]
    }
}
