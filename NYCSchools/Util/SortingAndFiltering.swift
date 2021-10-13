//
//  SortingAndFiltering.swift
//  NYCSchools
//
//  Created by Nathan Abbott on 10/13/21.
//

import CoreData

func defaultFetchRequest()->NSFetchRequest<HighSchool> {
    let request:NSFetchRequest<HighSchool>=NSFetchRequest(entityName: "HighSchool")
    
    request.resultType = .managedObjectResultType
    request.sortDescriptors=SortByFilterBy.SortOrder.asc.sortDescriptors
    
    request.propertiesToFetch=["schoolName","address","satResults"]
    request.relationshipKeyPathsForPrefetching=["address","satResults"]
    request.returnsObjectsAsFaults=false
    
    return request
}

func fetchedResultsController<E>(fetchRequest:NSFetchRequest<E>, moc:NSManagedObjectContext) -> NSFetchedResultsController<E> where E:NSManagedObject {
    let fetchRequest:NSFetchRequest<E>=fetchRequest
    let frc:NSFetchedResultsController<E>=NSFetchedResultsController(
        fetchRequest: fetchRequest,
        managedObjectContext: moc,
        sectionNameKeyPath: "address.borough",
        cacheName: "schools")

    return frc
}

//MARK - Data types for filtering
struct SortByFilterBy {
    static let boroughs=["All","Bronx","Brooklyn","Manhattan","Queens","Staten Is"]
    
    enum SortOrder {
        case asc, desc
        
        var sortDescriptors:[NSSortDescriptor] {
            var isAsc=true
            if case .desc = self {
                isAsc=false
            }
            
            return [
                NSSortDescriptor(key: "address.borough", ascending: isAsc),
                NSSortDescriptor(key: "schoolName", ascending: isAsc)
            ]
        }
    }
    
    var sortOrder:SortOrder = .asc
    var borough:String?
    var minCombinedSAT:Int=0
    
    var description:String {
        var desc="Borough: \(borough ?? "All")"
        if minCombinedSAT > 0 {
            desc.append(", SAT >= \(minCombinedSAT)")
        }
        
        desc.append(", order: ")
        if case .asc = sortOrder {
            desc.append("asc")
        } else {
            desc.append("desc")
        }
        
        
        return desc
    }
    
    var predicate:NSPredicate? {
        var predicate:NSPredicate?
        if let borough=borough?.uppercased() {
            predicate=NSPredicate(format: "address.borough=%@", borough)
        }
        
        if minCombinedSAT > 0 {
            let sat="$s.satMathAvgScore+$s.satCriticalReadingAvgScore"
            let satPredicate=NSPredicate(format: "SUBQUERY(satResults, $s, (\(sat)) > %@).@count > 0", NSNumber(value: minCombinedSAT))
            
            if let p=predicate {
                predicate=NSCompoundPredicate(andPredicateWithSubpredicates: [satPredicate,p])
            } else {
                predicate=satPredicate
            }
        }
        return predicate
    }
}
