//
//  JSONParseTests.swift
//  JPMCPrototypeTests
//
//  Created by Nathan Abbott on 10/2/21.
//

import XCTest
import CoreData
@testable import NYCSchools

func parseJSON(data:Data) -> Array<Dictionary<String,String>> {
    let unserialized=try! JSONSerialization.jsonObject(with: data, options: .allowFragments)
    return (unserialized as? Array<Dictionary<String, String>>)!
}

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
    
    lazy var satJSON:Array<Dictionary<String,String>>={
        return parseJSON(data:loadJSONFile(fileName: "SAT"))
    }()

    
    override func setUpWithError() throws {
//        psc = {
//            guard let modelURL = Bundle.main.url(forResource: "NYCSchools", withExtension: "momd") else {
//                fatalError("Failed to find data model")
//            }
//            guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
//                fatalError("Failed to create model from file: \(modelURL)")
//            }
//
//            let psc=NSPersistentContainer(name: "Test Container", managedObjectModel: mom)
//            try! psc.persistentStoreCoordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
//
//            return psc
//        }()
        
//        moc = {
//            let context:NSManagedObjectContext=NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
//             context.persistentStoreCoordinator=psc.persistentStoreCoordinator
//            return context
//        }()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    /// Test to ensure that we're capturing all of the relevant fields from the JSON data.
    func testSchoolTransform() {
        
        do {
            guard let hsImporter=try MappingTransformer(mappingFile: "HighSchool", entityName: "HighSchool") else {
                XCTFail("Could not instantiate the high school importer")
                return
            }
            
            let transformed=hsImporter.transform(record: schoolJSON.first!)
            XCTAssertEqual(1, transformed.count)
            let school=transformed.first!
            
            
            XCTAssertEqual("Community Service Expected; Internships", school["additionalInfo"] as! String)
            XCTAssertEqual("AP Calculus, AP English, AP US History, AP World History", school["advancedPlacementCourses"]  as! String)
            XCTAssertEqual(0.949999988, school["attendanceRate"] as! Float)
            XCTAssertTrue(school["boys"] as! Bool)
            XCTAssertEqual(0.958000004, school["collegeCareerRate"] as! Float)
            XCTAssertEqual("30Q501", school["dbn"] as! String)
            XCTAssertEqual("Arts, Math, Science", school["diplomaEndorsements"] as! String)
            XCTAssertEqual("English as a New Language", school["ellPrograms"] as! String)
            XCTAssertEqual("3:15pm", school["endTime"] as! String)
            XCTAssertEqual("After-School and Saturday Tutoring", school["extracurricularActivities"] as! String)
            XCTAssertEqual("718-361-9995",school["faxNumber"] as! String)
            XCTAssertEqual("9-12",school["finalGrades"] as! String)
            XCTAssertEqual("Open only to Bronx students/residents",school["geoEligibility"] as! String)
            XCTAssertTrue(school["girls"] as! Bool)
            XCTAssertEqual("9-12", school["finalGrades"] as! String)
            XCTAssertEqual(0.633000016, school["graduationRate"] as! Float)
            XCTAssertTrue(school["international"] as! Bool)
            XCTAssertEqual("Spanish", school["languageClasses"] as! String)
            XCTAssertEqual("It is the policy of Frank Sinatra School...",school["overviewParagraph"] as! String)
            XCTAssertTrue(school["pbat"] as! Bool)
            XCTAssertEqual(0.980000019, school["pctStuSafe"] as! Float)
            XCTAssertEqual(0.800000012, school["pctStuEnoughVariety"] as! Float)
            XCTAssertEqual("718-361-9920", school["phoneNumber"] as! String)
            XCTAssertEqual("Baseball, Basketball", school["psalSportsBoys"] as! String)
            XCTAssertEqual("Outdoor Track", school["psalSportsCoed"] as! String)
            XCTAssertEqual("Basketball, Outdoor Track, Soccer, Softball", school["psalSportsGirls"] as! String)
            XCTAssertTrue(school["ptech"] as! Bool)
            XCTAssertTrue(school["school10thSeats"] as! Bool)
            XCTAssertTrue(school["schoolAccessibilityDescription"] as! Bool)
            XCTAssertEqual("cmarchetta@schools.nyc.gov", school["schoolEmail"] as! String)
            XCTAssertEqual("Frank Sinatra School of the Arts High School", school["schoolName"] as! String)
            XCTAssertEqual("Basketball, Cheerleading, Flag Football, Volleyball, Swimming", school["schoolSports"] as! String)
            XCTAssertTrue(school["sharedSpace"] as! Bool)
            XCTAssertTrue(school["specialized"] as! Bool)
            XCTAssertEqual("7:45am", school["startTime"] as! String)
            XCTAssertEqual(828, school["totalStudents"] as! Int16)
            XCTAssertTrue(school["transfer"] as! Bool)
            XCTAssertEqual("www.FrankSinatraSchoolOfTheArts.org", school["website"] as! String)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func matchAddress(addr:[String:Any]){
        XCTAssertEqual("4006390016", addr["bbl"] as! String)
        XCTAssertEqual("4009594", addr["bin"] as! String)
        XCTAssertEqual("Q", addr["boro"] as! String)
        XCTAssertEqual("QUEENS", addr["borough"] as! String)
        XCTAssertEqual("Q570", addr["buildingCode"] as! String)
        XCTAssertEqual("Q101, Q102, Q104, Q66", addr["bus"] as! String)
        XCTAssertEqual("Spring Creek Educational Campus", addr["campusName"] as! String)
        XCTAssertEqual(57, addr["censusTract"] as! Int16)
        XCTAssertEqual("Astoria", addr["city"] as! String)
        XCTAssertEqual(1,addr["communityBoard"] as! Int16)
        XCTAssertEqual(26,addr["councilDistrict"] as! Int16)
        XCTAssertEqual("30Q501", addr["dbn"] as! String)
        XCTAssertEqual(40.7561,addr["latitude"] as! Double)
        XCTAssertEqual("35-12 35th Avenue, Astoria NY 11106 (40.756099, -73.925182)",addr["location"] as! String)
        XCTAssertEqual(-73.9252,addr["longitude"] as! Double)
        XCTAssertEqual("Astoria", addr["neighborhood"] as! String)
        XCTAssertEqual("Astoria", addr["nta"] as! String)
        XCTAssertEqual("35-12 35th Avenue", addr["primaryAddressLine1"] as! String)
        XCTAssertEqual("NY", addr["stateCode"] as! String)
        XCTAssertEqual("M, R to Steinway St ; N, Q to 36 Ave-Washington Ave", addr["subway"] as! String)
        XCTAssertEqual("11106", addr["zip"] as! String)
    }
    
    func testAddressImport() {
        do {
            guard let addrTransformer=try MappingTransformer(mappingFile: "Address", entityName: "Address") else {
                XCTFail("Could not instantiate the high school importer")
                return
            }
            
            let transformed=addrTransformer.transform(record: schoolJSON.first!)
            XCTAssertEqual(1, transformed.count)
            let address=transformed.first!
            
            
            matchAddress(addr: address)
        } catch {
            XCTFail(error.localizedDescription)
        }
     }
    
    func testProgramImport() {
        
        do {
            guard let programTransformer=try ProgramTransformer(mappingFile: "Program", entityName: "Program") else {
                XCTFail("Could not instantiate the high school importer")
                return
            }
            
            let transformed=programTransformer.transform(record: schoolJSON.first!)
            XCTAssertEqual(1, transformed.count)
            let program=transformed.first!
            
            XCTAssertEqual("International Baccalaureate (IB): ... Diploma Programme.", program["academicOpportunities"] as! String)
            XCTAssertEqual("Unscreened", program["admissionsMethod"] as! String)
            XCTAssertEqual("During the audition, ... do to resolve them?", program["auditionInfo"] as! String)
            XCTAssertTrue(program["auditionIsCommon"] as! Bool)
            XCTAssertEqual("R19A", program["code"] as! String)
            XCTAssertEqual("30Q501", program["dbn"] as! String)
            XCTAssertEqual("The Computer Business Institute offers ...", program["desc"] as! String)
            XCTAssertEqual("Please contact the school about the on-site requirement.", program["directions"] as! String)
            XCTAssertEqual("Admissions eligibility for school's 1st program", program["eligibility"] as! String)
            XCTAssertEqual(249,program["grade9Applicants"] as! Int16)
            XCTAssertEqual(4,program["grade9ApplicantsPerSeat"] as! Int16)
            XCTAssertEqual(68,program["grade9Seats"] as! Int16)
            XCTAssertFalse(program["grade9SeatsFilled"] as! Bool)
            XCTAssertEqual(78, program["grade9SWDApplicants"] as! Int16)
            XCTAssertEqual(5, program["grade9SWDApplicantsPerSeat"] as! Int16)
            XCTAssertEqual(17, program["grade9SWDSeats"] as! Int16)
            XCTAssertTrue(program["grade9SWDSeatsFilled"] as! Bool)
            XCTAssertEqual("No",program["grade10Seats"] as! String)
            XCTAssertEqual("Computer Science & Technology", program["interestArea"] as! String)
            XCTAssertEqual("Computer Business Institute", program["name"] as! String)
            XCTAssertEqual("Â—99% of offers went to this group", program["offerRate"] as! String)
            XCTAssertEqual(1, program["programNumber"] as! Int16)
            XCTAssertEqual(2006, program["specializedApplicants"] as! Int16)
            XCTAssertEqual(34, program["specializedApplicantsPerSeat"] as! Int16)
            XCTAssertEqual(59, program["specializedSeats"] as! Int16)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testProgramReqImport() {
        
        let reqsTransformer=ProgReqsTransformer(entityName: "ProgramAdmissionReqs")
        let reqs=reqsTransformer.transform(record: schoolJSON.first!)
        XCTAssertEqual(4, reqs.count)

        var i=0
        XCTAssertEqual("30Q501", reqs[i]["dbn"] as! String)
        XCTAssertEqual("Course Grades: English (76-100), Math (75-100), Social Studies (75-100), Science (77-100)", reqs[i]["requirement"] as! String)
        XCTAssertEqual(1, reqs[i]["requirementNo"] as! Int16)
        XCTAssertEqual(1, reqs[i]["programNo"] as! Int16)

        i += 1
        XCTAssertEqual("Standardized Test Scores: English Language Arts (2.3-4.5), Math (2.1-4.5)", reqs[i]["requirement"] as! String)
        XCTAssertEqual(2, reqs[i]["requirementNo"] as! Int16)
        XCTAssertEqual(1, reqs[i]["programNo"] as! Int16)

        i += 1
        XCTAssertEqual("Attendance and Punctuality", reqs[i]["requirement"] as! String)
        XCTAssertEqual(3, reqs[i]["requirementNo"] as! Int16)
        XCTAssertEqual(1, reqs[i]["programNo"] as! Int16)

        i += 1
        XCTAssertEqual("Math and English Test (On-site)", reqs[i]["requirement"] as! String)
        XCTAssertEqual(4, reqs[i]["requirementNo"] as! Int16)
        XCTAssertEqual(1, reqs[i]["programNo"] as! Int16)
   
    }

    func testProgramPriorityImport() {
        let priorityTransformer=AdmissionsPriorityTransformer(entityName: "ProgramAdmissionsPriority")
        let priorities=priorityTransformer.transform(record: schoolJSON.first!)
        XCTAssertEqual(19, priorities.count)
        var pNo:Int16=1
        
        priorities[0..<9].forEach { p in
            XCTAssertEqual("30Q501", p["dbn"] as! String)
            XCTAssertEqual("Priority to Staten Island students or residents",p["priority"] as! String)
            XCTAssertEqual(pNo, p["programNo"] as! Int16)
            XCTAssertEqual(1, p["priorityNo"] as! Int16)
            pNo += 1
        }

        XCTAssertEqual("30Q501", priorities[9]["dbn"] as! String)
        XCTAssertEqual("Guaranteed offer to students who apply and live in the zoned area",priorities[9]["priority"] as! String)
        XCTAssertEqual(10, priorities[9]["programNo"] as! Int16)
        XCTAssertEqual(1, priorities[9]["priorityNo"] as! Int16)

        pNo=1
        priorities[10...].forEach { p in
            XCTAssertEqual("30Q501", p["dbn"] as! String)
            XCTAssertEqual("Then to New York City residents",p["priority"] as! String)
            XCTAssertEqual(pNo, p["programNo"] as! Int16)
            XCTAssertEqual(2, p["priorityNo"] as! Int16)
            pNo += 1
        }
    }
    
    func matchSAT(satResults:[String:Any]){
        XCTAssertEqual("30Q501", satResults["dbn"] as! String)
        XCTAssertEqual(7, satResults["numOfSatTestTakers"] as! Int16)
        XCTAssertEqual(414, satResults["satCriticalReadingAvgScore"] as! Int16)
        XCTAssertEqual(401, satResults["satMathAvgScore"] as! Int16)
        XCTAssertEqual(359, satResults["satWritingAvgScore"] as! Int16)
    }
    
    func testSATImport() {
        do {
            guard let programTransformer=try MappingTransformer(mappingFile: "SATResults", entityName: "SATResults") else {
                XCTFail("Could not instantiate the SAT transformer")
                return
            }
            
            let transformed=programTransformer.transform(record: satJSON.first!)
            XCTAssertEqual(1, transformed.count)
            let satResult=transformed.first!
            
            matchSAT(satResults: satResult)
            
        } catch {
            XCTFail(error.localizedDescription)
        }
     }
}
