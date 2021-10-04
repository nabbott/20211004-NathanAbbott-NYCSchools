//
//  JSONParseTests.swift
//  JPMCPrototypeTests
//
//  Created by Nathan Abbott on 10/2/21.
//

import XCTest
import CoreData
@testable import JPMCPrototype

class JSONParseTests: XCTestCase {
    lazy var schoolJSON:Array<Dictionary<String,String>>={
        let bundle=Bundle(for: JSONParseTests.self)
        let path = bundle.path(forResource: "School", ofType: "json")!
        let fileHandle=FileHandle.init(forReadingAtPath: path)!
        defer {
            try! fileHandle.close()
        }
        
        let unserialized=try! JSONSerialization.jsonObject(with: fileHandle.availableData, options: .allowFragments)
        return (unserialized as? Array<Dictionary<String, String>>)!
    }()
    
    lazy var addressJSON:Array<Dictionary<String,String>>={
        let bundle=Bundle(for: JSONParseTests.self)
        let path = bundle.path(forResource: "Address", ofType: "json")!
        let fileHandle=FileHandle.init(forReadingAtPath: path)!
        defer {
            try! fileHandle.close()
        }

        
        let unserialized=try! JSONSerialization.jsonObject(with: fileHandle.availableData, options: .allowFragments)
        return (unserialized as? Array<Dictionary<String, String>>)!
    }()
    
    lazy var satJSON:Array<Dictionary<String,String>>={
        let bundle=Bundle(for: JSONParseTests.self)
        let path = bundle.path(forResource: "SAT", ofType: "json")!
        let fileHandle=FileHandle.init(forReadingAtPath: path)!
        defer {
            try! fileHandle.close()
        }

        
        let unserialized=try! JSONSerialization.jsonObject(with: fileHandle.availableData, options: .allowFragments)
        return (unserialized as? Array<Dictionary<String, String>>)!
    }()
    
    lazy var psc:NSPersistentContainer = {
        guard let modelURL = Bundle.main.url(forResource: "JPMCPrototype", withExtension: "momd") else {
            fatalError("Failed to find data model")
        }
        guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to create model from file: \(modelURL)")
        }
        
        let psc=NSPersistentContainer(name: "Test Container", managedObjectModel: mom)
        try! psc.persistentStoreCoordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
        
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

    func testStringToString(){
        let newline = """
foo
 bar
"""
        let whitespace=" foo bar  "
        let good="foo bar"
        
        XCTAssertEqual("foo bar", stringToString(newline)!)
        XCTAssertEqual("foo bar", stringToString(whitespace)!)
        XCTAssertEqual("foo bar", stringToString(good)!)
    }
    
    func testStringToBool(){
        let falseN="N"
        let falseNo="no"
        let false0="0"
        let falseNil:String? = nil
        XCTAssertFalse(stringToBool(falseN))
        XCTAssertFalse(stringToBool(falseNo))
        XCTAssertFalse(stringToBool(false0))
        XCTAssertFalse(stringToBool(falseNil))
        
        let trueAny1=""
        let trueAny2="ahe"
        
        XCTAssertTrue(stringToBool(trueAny1))
        XCTAssertTrue(stringToBool(trueAny2))
    }
    
    func testStringToFloat(){
        XCTAssertEqual(0.0, stringToFloat(nil))
        XCTAssertEqual(0.0, stringToFloat(""))
        XCTAssertEqual(0.0, stringToFloat("foo"))
        
        XCTAssertEqual(-73.9252, stringToFloat("-73.9252"))
        XCTAssertEqual(0.958000004, stringToFloat("0.958000004"))
    }
    
    func testStringToDouble(){
        XCTAssertEqual(0.0, stringToDouble(nil))
        XCTAssertEqual(0.0, stringToDouble(""))
        XCTAssertEqual(0.0, stringToDouble("foo"))
        
        XCTAssertEqual(-73.9252, stringToDouble("-73.9252"))
        XCTAssertEqual(0.958000004, stringToDouble("0.958000004"))
    }
    
    func testStringToInt(){
        XCTAssertEqual(0, stringToInt(nil))
        XCTAssertEqual(0, stringToInt(""))
        XCTAssertEqual(0, stringToInt("foo"))
        
        XCTAssertEqual(828, stringToInt("828"))
    }
    
    /// Test to ensure that we're capturing all of the relevant fields from the JSON data.
    func testSchool() {
        let parser=HSDataImporter(moc:moc)
        let hs=parser.insertHS(schoolData: schoolJSON.first!)
        
        
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

    func testAddress() {
        let parser=HSDataImporter(moc:moc)
        let addr=parser.insertAddress(schoolData: addressJSON.first!)
        
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
    
    func testSAT() {
        let parser=HSDataImporter(moc:moc)
        let satResults=parser.insertSATResult(satData: satJSON.first!)

        XCTAssertEqual("01M458", satResults.dbn)
        XCTAssertEqual("FORSYTH SATELLITE ACADEMY", satResults.schoolName)
        XCTAssertEqual(7, satResults.numOfSatTestTakers)
        XCTAssertEqual(414, satResults.satCriticalReadingAvgScore)
        XCTAssertEqual(401, satResults.satMathAvgScore)
        XCTAssertEqual(359, satResults.satWritingAvgScore)
     }
}
