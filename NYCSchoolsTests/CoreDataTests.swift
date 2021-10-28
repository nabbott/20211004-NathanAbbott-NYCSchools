//
//  NYCSchoolsTests
//
//  Created by Nathan Abbott on 10/2/21.
//

import XCTest
import CoreData
@testable import NYCSchools

class TestCoreData: XCTestCase {
    lazy var schoolJSON:Array<Dictionary<String,String>>={
        return parseJSON(data:loadJSONFile(fileName: "School"))
    }()
    
    lazy var satJSON:Array<Dictionary<String,String>>={
        return parseJSON(data:loadJSONFile(fileName: "SAT"))
    }()
    
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
        request.relationshipKeyPathsForPrefetching=["address","programs","satResults"]
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
        
        let psc=NSPersistentContainer(name: "Test Container", managedObjectModel: mom)
        try! psc.persistentStoreCoordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
        
        return psc

        
//        guard let modelURL = Bundle.main.url(forResource: "NYCSchools", withExtension: "momd") else {
//            fatalError("Failed to find data model")
//        }
//
//        guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
//            fatalError("Failed to create model from file: \(modelURL)")
//        }
//
//        guard let containerURL:URL=FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.sundaylogic.NYCSchools") else {
//            fatalError("Could not instantiate url for persistent store coordinator")
//        }
//
//        print(containerURL.path)
//        let dbURL:URL=URL(fileURLWithPath: "NYCSchools.sqlite", relativeTo: containerURL)
//
//        let psc=NSPersistentContainer(name: "Test Container", managedObjectModel: mom)
//        try! psc.persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: dbURL, options: nil)
//
//        return psc

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
    
    func testImport(){
        do {
            var transformers:[DataTransformer]=[
                try MappingTransformer(mappingFile: "HighSchool", entityName: "HighSchool")!,
                try MappingTransformer(mappingFile: "Address", entityName: "Address")!,
                try ProgramTransformer(mappingFile: "Program", entityName: "Program")!,
                ProgReqsTransformer(entityName: "ProgramAdmissionReqs"),
                AdmissionsPriorityTransformer(entityName: "ProgramAdmissionsPriority")
            ]
            var transformed=transformDeserializedData(records: AnyCollection(schoolJSON), transformations: transformers)
            XCTAssertEqual(19, transformed["ProgramAdmissionsPriority"]!.count)
            XCTAssertEqual(4, transformed["ProgramAdmissionReqs"]!.count)
            XCTAssertEqual(1, transformed["Address"]!.count)
            XCTAssertEqual(1, transformed["HighSchool"]!.count)
            XCTAssertEqual(1, transformed["Program"]!.count)
            
            transformed.forEach {typeAndValues in
                do {
                    try persistNewEntities(entityProperties: typeAndValues.value, entityName: typeAndValues.key, ctx: moc, batchInsert: false)
                } catch {
                    XCTFail("Error thrown trying to import data: \(error)")
                }
            }
            
            transformers=[
                try MappingTransformer(mappingFile: "SATResults", entityName: "SATResult")!
            ]
            transformed=transformDeserializedData(records: AnyCollection(satJSON), transformations: transformers)
            XCTAssertEqual(1, transformed["SATResult"]!.count)
            
            transformed.forEach {typeAndValues in
                do {
                    try persistNewEntities(entityProperties: typeAndValues.value, entityName: typeAndValues.key, ctx: moc, batchInsert: false)
                } catch {
                    XCTFail("Error thrown trying to import data: \(error)")
                }
            }
            
            try establishProgramRelationships(ctx: moc)
            try establishSchoolRelationships(ctx: moc)
            
            let school=(try! moc.fetch(highSchoolsFR)).first!
            
            XCTAssertEqual("30Q501", school.dbn)
            XCTAssertEqual("30Q501", school.address!.dbn)
            XCTAssertEqual("30Q501", school.satResults!.dbn)
            
            XCTAssertEqual(2, (school.programs!.allObjects.first as! Program).admissionPriority!.count)
            XCTAssertEqual(4, (school.programs!.allObjects.first as! Program).admissionReqs!.count)
        } catch {
            XCTFail("Error thrown trying to import data: \(error)")
        }
    }
    
//    func testDelete(){
//        deleteAll(entityName: "HighSchool", ctx: moc)
//    }
}
