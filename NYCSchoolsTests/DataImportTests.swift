//
//  JSONParseTests.swift
//  JPMCPrototypeTests
//
//  Created by Nathan Abbott on 10/2/21.
//

import XCTest
import CoreData
@testable import NYCSchools

fileprivate
func parseJSON(data:Data) -> Array<Dictionary<String,String>> {
    let unserialized=try! JSONSerialization.jsonObject(with: data, options: .allowFragments)
    return (unserialized as? Array<Dictionary<String, String>>)!
}

fileprivate
func loadJSONFile(fileName fn:String) -> Data {
    let bundle=Bundle(for: JSONParseTests.self)
    let path = bundle.path(forResource: fn, ofType: "json")!
    let fileHandle=FileHandle.init(forReadingAtPath: path)!
    defer {
        try! fileHandle.close()
    }
    
    return fileHandle.availableData
}

class DataImportTests: XCTestCase {
    lazy var schoolJSON:Array<Dictionary<String,String>>={
        return parseJSON(data:loadJSONFile(fileName: "School"))
    }()
    
//    lazy var addressJSON:Array<Dictionary<String,String>>={
//        return parseJSON(data:loadJSONFile(fileName: "Address"))
//    }()
    
    lazy var satJSON:Array<Dictionary<String,String>>={
        return parseJSON(data:loadJSONFile(fileName: "SAT"))
    }()
    
    lazy var completeSchoolData:Data={
        return loadJSONFile(fileName: "CompleteSchoolRecords")
    }()
    
    lazy var completeSchoolSATData:Data={
        return loadJSONFile(fileName: "CompleteSchoolSATRecords")
    }()
    
    var psc:NSPersistentContainer!
    var moc:NSManagedObjectContext!
      
    override func setUpWithError() throws {
        psc = {
            guard let modelURL = Bundle.main.url(forResource: "NYCSchools", withExtension: "momd") else {
                fatalError("Failed to find data model")
            }
            guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
                fatalError("Failed to create model from file: \(modelURL)")
            }
            
            let psc=NSPersistentContainer(name: "Test Container", managedObjectModel: mom)
            try! psc.persistentStoreCoordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
            
            return psc
        }()
        
        moc = {
            let context:NSManagedObjectContext=NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
             context.persistentStoreCoordinator=psc.persistentStoreCoordinator
            return context
        }()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    
    func testCorruptedFile(){
        let badSchoolFile=loadJSONFile(fileName: "CorruptedSchoolFile")
        let badSATFile=loadJSONFile(fileName: "CorruptedSATFile")
        
        let parser=HSDataImporter()
        XCTAssertThrowsError(try parser.importAllDataAndEstablishRelationships(highSchools: badSchoolFile, satResults: badSATFile, ctx: moc))
    }
    
    /// Test to ensure that we're capturing all of the relevant fields from the JSON data.
    func testSchool() {
        let parser=HSDataImporter()
        XCTAssertNoThrow(try parser.importSchools(schools: schoolJSON, ctx: moc))
        
        let hs:HighSchool={
            let fr=NSFetchRequest<HighSchool>(entityName: "HighSchool")
            fr.returnsObjectsAsFaults=false
            return try! moc.fetch(fr).first!
        }()
        
        XCTAssertEqual("Community Service Expected; Internships", hs.additionalInfo)
        XCTAssertEqual("AP Calculus, AP English, AP US History, AP World History", hs.advancedPlacementCourses)
        XCTAssertEqual(0.949999988, hs.attendanceRate)
        XCTAssertTrue(hs.boys)
        XCTAssertEqual(0.958000004, hs.collegeCareerRate)
        XCTAssertEqual("30Q501", hs.dbn)
        XCTAssertEqual("Arts, Math, Science", hs.diplomaEndorsements)
        XCTAssertEqual("English as a New Language", hs.ellPrograms)
        XCTAssertEqual("3:15pm", hs.endTime)
        XCTAssertEqual("After-School and Saturday Tutoring", hs.extracurricularActivities)
        XCTAssertEqual("718-361-9995",hs.faxNumber)
        XCTAssertEqual("9-12",hs.finalGrades)
        XCTAssertEqual("Open only to Bronx students/residents",hs.geoEligibility)
        XCTAssertTrue(hs.girls)
        XCTAssertEqual("9-12", hs.finalGrades)
        XCTAssertEqual(0.633000016, hs.graduationRate)
        XCTAssertTrue(hs.international)
        XCTAssertEqual("Spanish", hs.languageClasses)
        XCTAssertEqual("It is the policy of Frank Sinatra School...",hs.overviewParagraph)
        XCTAssertTrue(hs.pbat)
        XCTAssertEqual(0.980000019, hs.pctStuSafe)
        XCTAssertEqual(0.800000012, hs.pctStuEnoughVariety)
        XCTAssertEqual("718-361-9920", hs.phoneNumber)
        XCTAssertEqual("Baseball, Basketball", hs.psalSportsBoys)
        XCTAssertEqual("Outdoor Track", hs.psalSportsCoed)
        XCTAssertEqual("Basketball, Outdoor Track, Soccer, Softball", hs.psalSportsGirls)
        XCTAssertTrue(hs.ptech)
        XCTAssertTrue(hs.school10thSeats)
        XCTAssertTrue(hs.schoolAccessibilityDescription)
        XCTAssertEqual("cmarchetta@schools.nyc.gov", hs.schoolEmail)
        XCTAssertEqual("Frank Sinatra School of the Arts High School", hs.schoolName)
        XCTAssertEqual("Basketball, Cheerleading, Flag Football, Volleyball, Swimming", hs.schoolSports)
        XCTAssertTrue(hs.sharedSpace)
        XCTAssertTrue(hs.specialized)
        XCTAssertEqual("7:45am", hs.startTime)
        XCTAssertEqual(828, hs.totalStudents)
        XCTAssertTrue(hs.transfer)
        XCTAssertEqual("www.FrankSinatraSchoolOfTheArts.org", hs.website)
    }

    
    func matchAddress(addr:Address){
        XCTAssertEqual("4006390016", addr.bbl)
        XCTAssertEqual("4009594", addr.bin)
        XCTAssertEqual("Q", addr.boro)
        XCTAssertEqual("QUEENS", addr.borough)
        XCTAssertEqual("Q570", addr.buildingCode)
        XCTAssertEqual("Q101, Q102, Q104, Q66", addr.bus)
        XCTAssertEqual("Spring Creek Educational Campus", addr.campusName)
        XCTAssertEqual(57, addr.censusTract)
        XCTAssertEqual("Astoria", addr.city)
        XCTAssertEqual(1,addr.communityBoard)
        XCTAssertEqual(26,addr.councilDistrict)
        XCTAssertEqual("30Q501", addr.dbn)
        XCTAssertEqual(40.7561,addr.latitude)
        XCTAssertEqual("35-12 35th Avenue, Astoria NY 11106 (40.756099, -73.925182)",addr.location)
        XCTAssertEqual(-73.9252,addr.longitude)
        XCTAssertEqual("Astoria", addr.neighborhood)
        XCTAssertEqual("Astoria", addr.nta)
        XCTAssertEqual("35-12 35th Avenue", addr.primaryAddressLine1)
        XCTAssertEqual("NY", addr.stateCode)
        XCTAssertEqual("M, R to Steinway St ; N, Q to 36 Ave-Washington Ave", addr.subway)
        XCTAssertEqual("11106", addr.zip)
    }
    
    func testAddress() {
        let parser=HSDataImporter()
        XCTAssertNoThrow(try parser.importAddresses(addresses: schoolJSON, ctx: moc))
        
        let addr:Address={
            let fr=NSFetchRequest<Address>(entityName: "Address")
            fr.returnsObjectsAsFaults=false
            return try! moc.fetch(fr).first!
        }()
        
        matchAddress(addr: addr)
     }
    
    func matchSAT(satResults:SATResult){
        XCTAssertEqual("30Q501", satResults.dbn)
        XCTAssertEqual(7, satResults.numOfSatTestTakers)
        XCTAssertEqual(414, satResults.satCriticalReadingAvgScore)
        XCTAssertEqual(401, satResults.satMathAvgScore)
        XCTAssertEqual(359, satResults.satWritingAvgScore)
    }
    
    func testSAT() {
        let parser=HSDataImporter()
        XCTAssertNoThrow(try parser.importSATResults(satResults: satJSON, ctx: moc))
        
        let satResults:SATResult={
            let fr=NSFetchRequest<SATResult>(entityName: "SATResult")
            fr.returnsObjectsAsFaults=false
            return try! moc.fetch(fr).first!
        }()

        matchSAT(satResults: satResults)
     }
    
    func testImport(){
        let parser=HSDataImporter()
        try! parser.importAllDataAndEstablishRelationships(highSchools: schoolJSON, satResults: satJSON, ctx:moc)
        
              
        let hs:HighSchool={
            let fr=NSFetchRequest<HighSchool>(entityName: "HighSchool")
            fr.returnsObjectsAsFaults=false
            fr.relationshipKeyPathsForPrefetching=["address","satResults"]
            return try! moc.fetch(fr).first!
        }()
        
        
        XCTAssertNotNil(hs.satResults)
        matchSAT(satResults: hs.satResults!)
        
        XCTAssertNotNil(hs.address)
        matchAddress(addr: hs.address!)
    }
    
    func testDelete(){
        let parser=HSDataImporter()
        try! parser.importAllDataAndEstablishRelationships(highSchools: schoolJSON, satResults: satJSON, ctx:moc)
        XCTAssertNoThrow(try parser.deleteAllHSData(ctx: moc))
        
        do {
            let addrFR=NSFetchRequest<Address>(entityName: "Address")
            let count=try moc.count(for: addrFR)
            XCTAssertEqual(0,count)
        } catch {
            XCTFail("Failed with error: \(error)")
        }
        
        do {
            let satFR=NSFetchRequest<SATResult>(entityName: "SATResult")
            let count=try moc.count(for: satFR)
            XCTAssertEqual(0,count)
        } catch {
            XCTFail("Failed with error: \(error)")
        }
       
        do {
            let hsFR=NSFetchRequest<HighSchool>(entityName: "HighSchool")
            let count=try moc.count(for: hsFR)
            XCTAssertEqual(0,count)
        } catch {
            XCTFail("Failed with error: \(error)")
        }
    }
}
