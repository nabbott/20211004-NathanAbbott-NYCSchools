//
//  NYCSchoolsTests
//
//  Created by Nathan Abbott on 10/2/21.
//

import XCTest
import CoreData
@testable import NYCSchools

class TestCoreData: XCTestCase {
    let ascendingSort:[NSSortDescriptor]=[
        NSSortDescriptor(key: "address.borough", ascending: true),
        NSSortDescriptor(key: "schoolName", ascending: true)
    ]
    
    let descendingSort:[NSSortDescriptor]=[
        NSSortDescriptor(key: "address.borough", ascending: false),
        NSSortDescriptor(key: "schoolName", ascending: false)
    ]
    
    lazy var highSchoolsFR:NSFetchRequest<HighSchool> = {
        let request:NSFetchRequest<HighSchool>=NSFetchRequest(entityName: "HighSchool")
        
        request.resultType = .managedObjectResultType
        request.sortDescriptors=ascendingSort
        request.propertiesToFetch=["schoolName","address"]
        request.relationshipKeyPathsForPrefetching=["address"]
        request.returnsObjectsAsFaults=false
        
        return request
    }()
    
    lazy var psc:NSPersistentContainer = {
        guard let modelURL = Bundle.main.url(forResource: "NYCSchools", withExtension: "momd") else {
            fatalError("Failed to find data model")
        }
        
        guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to create model from file: \(modelURL)")
        }

        guard let containerURL:URL=FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.sundaylogic.NYCSchools") else {
            fatalError("Could not instantiate url for persistent store coordinator")
        }
        
        print(containerURL.path)
        let dbURL:URL=URL(fileURLWithPath: "NYCSchools.sqlite", relativeTo: containerURL)
        
        let psc=NSPersistentContainer(name: "Test Container", managedObjectModel: mom)
        try! psc.persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: dbURL, options: nil)
        
        return psc
    }()
    
    lazy var moc:NSManagedObjectContext = {
        let context:NSManagedObjectContext=NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
         context.persistentStoreCoordinator=psc.persistentStoreCoordinator
        return context
    }()
      
        
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testFetchRequest(){
        let fReq:NSFetchRequest<HighSchool>=NSFetchRequest()
        fReq.entity=NSEntityDescription.entity(forEntityName: "HighSchool", in: moc)
        fReq.returnsObjectsAsFaults=false
        
        if let s=try? moc.persistentStoreCoordinator?.execute(fReq, with: moc) as? Array<HighSchool> {
            s.forEach {
                print($0.schoolName ?? "No Name!!!")
            }
        }
    }
}
