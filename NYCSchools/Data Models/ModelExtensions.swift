//
//  Extensions.swift
//  NYCSchools
//
//  Created by Nathan Abbott on 10/9/21.
//

import Foundation
import CoreData

// Schools with multiple programs:
// select zborough, ZSCHOOLNAME from ZHIGHSCHOOL h inner join ZADDRESS a on h.z_pk=a.zhighschool where h.z_pk in (select ZHIGHSCHOOL from ZPROGRAM group by ZHIGHSCHOOL having count(*) > 1) order by zborough, ZSCHOOLNAME;

extension HighSchool {
    var SATAverage:Int {
        guard let satResults=self.satResults else {return 0}
        
        return Int(satResults.satCriticalReadingAvgScore+satResults.satMathAvgScore+satResults.satWritingAvgScore)/3
    }
    
    var programsByNumber:[Program] {
        let fr=NSFetchRequest<Program>(entityName: "Program")
        fr.sortDescriptors=[NSSortDescriptor(key: "programNumber", ascending: true)]
        fr.predicate=NSPredicate(format: "highSchool=%@", self)

        return (try? managedObjectContext?.fetch(fr)) ?? []
    }
}
