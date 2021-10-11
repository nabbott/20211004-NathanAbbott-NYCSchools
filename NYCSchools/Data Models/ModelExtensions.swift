//
//  Extensions.swift
//  NYCSchools
//
//  Created by Nathan Abbott on 10/9/21.
//

import Foundation

extension HighSchool {
    var SATAverage:Int {
        guard let satResults=self.value(forKey: "satResults") as? SATResult else {return 0}
        
        return Int(satResults.satCriticalReadingAvgScore+satResults.satMathAvgScore+satResults.satWritingAvgScore)/3
    }
}
