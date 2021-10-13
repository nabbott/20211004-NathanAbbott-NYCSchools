//
//  Functions.swift
//  NYCSchools
//
//  Created by Nathan Abbott on 10/13/21.
//

import UIKit


//MARK: - UI Functions
@inlinable
func makeSimpleErrorAlert(msg:String, title:String="Error") -> UIAlertController {
    let alert=UIAlertController(title: title, message: msg, preferredStyle: UIAlertController.Style.alert)
    let ok:UIAlertAction=UIAlertAction(title: "Ok", style: .default, handler:nil)
    
    alert.addAction(ok)
    return alert
}
