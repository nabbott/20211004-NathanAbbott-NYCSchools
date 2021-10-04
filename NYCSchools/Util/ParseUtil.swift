//
//  ParseUtil.swift
//  JPMCPrototype
//
//  Created by Nathan Abbott on 10/2/21.
//

import Foundation
import CoreData
import OSLog

//MARK: - Utility functions to handle data type conversions, cleaning, and defaults
internal
func log(_ msg:String, logType:OSLogType = .debug){
    if #available(iOS 14, *) {
        let log=OSLog(subsystem: Bundle.main.bundleIdentifier ?? "NYHS_Directory", category: "Data Import")
        os_log(logType, log: log, "\(msg)")
    } else {
        os_log(logType, "%@", msg)
    }
}

internal
func stringToString(_ str:String?) -> String? {
    guard let s=str, 0 < s.count else {return nil}
    
    return s.trimmingCharacters(in: .whitespacesAndNewlines).filter({
        !$0.isNewline
    })
}

internal
func stringToBool(_ str:String?)->Bool {
    if let input=str {
        switch input.lowercased() {
        case "n","0","no": return false
        default: return true
        }
    }

    log("Using default value for boolean conversion.", logType: .info)
    return false
}

internal
func stringToTime(input:String)->Date {
    let df=DateFormatter()
    df.locale=Locale.current
    df.setLocalizedDateFormatFromTemplate("hh:mm a")
        //.dateFormat(fromTemplate: "h:mma", options: 0, locale: Locale.current)
    return df.date(from: input)!
}

internal
func stringToFloat(_ str:String?)->Float{
    if let input=str {
        guard let float=Float(input), !float.isNaN else {
            log("Using default value for floating point conversion.", logType: .info)
            return 0.0
        }
        return float
    }

    log("Using default value for floating point conversion.", logType: .info)
    return 0.0
}

internal
func stringToDouble(_ str:String?)->Double {
    if let input=str {
        guard let double=Double(input), !double.isNaN else {
            log("Using default value for double precision conversion.", logType: .info)
            return 0.0
        }
        return double
    }

    log("Using default value for double precision conversion.", logType: .info)
    return 0.0
}

internal
func stringToInt(_ str:String?)->Int16 {
    if let input=str {
        guard let int=Int16(input) else {
            log("Using default value for double precision conversion.", logType: .info)
            return 0
        }
        return int
    }

    log("Using default value for Integer conversion.", logType: .info)
    return 0
}

//MARK: - The data import engine. Parses a data object containing JSON.
class HSDataImporter {
    private let moc:NSManagedObjectContext
    private let includeChildEntities:Bool
    
    /// Creates a new importor
    /// - Parameters:
    ///   - moc: The context the new entities should be created in.
    ///   - includeChildEntities: If this is true, the child entities of High School (address, etc) will be created. Set to false to make testing easier
    init(moc:NSManagedObjectContext, includeChildEntities:Bool=false){
        self.moc=moc
        self.includeChildEntities=includeChildEntities
    }
    
    func importSchools(json:Data, batchLoad:Bool=false){
        let unserialized=try! JSONSerialization.jsonObject(with: json, options: .allowFragments)
        let schools:Array<Dictionary<String, String>>=unserialized as! Array<Dictionary<String, String>>
        
        schools.forEach { school in
            if batchLoad {
                batchInsertHS(schoolData: school)
            } else {
                insertHS(schoolData: school)
            }
        }
    }
    
    func importSATResults(json:Data, batchLoad:Bool=false){
        let unserialized=try! JSONSerialization.jsonObject(with: json, options: .allowFragments)
        let data:Array<Dictionary<String, String>>=unserialized as! Array<Dictionary<String, String>>
        
        data.forEach { satResult in
            if batchLoad {
                batchInsertSATResults(satData: satResult)
            } else {
                insertSATResult(satData: satResult)
            }
        }
    }

    
    func populateAddress(schoolData:Dictionary<String, String>, address:Address){
        address.bbl=stringToString(schoolData["bbl"])
        address.bin=stringToString(schoolData["bin"])
        address.zip=stringToString(schoolData["zip"])
        address.bus=stringToString(schoolData["bus"])
        address.nta=stringToString(schoolData["nta"])
        address.boro=stringToString(schoolData["boro"])
        address.city=stringToString(schoolData["city"])
        address.subway=stringToString(schoolData["subway"])
        address.borough=stringToString(schoolData["borough"])
        address.location=stringToString(schoolData["location"])
        address.stateCode=stringToString(schoolData["state_code"])
        address.campusName=stringToString(schoolData["campus_name"])
        address.neighborhood=stringToString(schoolData["neighborhood"])
        address.buildingCode=stringToString(schoolData["building_code"])
        address.primaryAddressLine1=stringToString(schoolData["primary_address_line_1"])
        
        //Numeric types
        address.latitude=stringToDouble(schoolData["latitude"])
        address.longitude=stringToDouble(schoolData["longitude"])
        
        address.censusTract=stringToInt(schoolData["census_tract"])
        address.communityBoard=stringToInt(schoolData["community_board"])
        address.councilDistrict=stringToInt(schoolData["council_district"])
    }
    
    func populateHighSchool(schoolData:Dictionary<String, String>, school:HighSchool){
        school.dbn=stringToString(schoolData["dbn"])
        school.website=stringToString(schoolData["website"])
        school.endTime=stringToString(schoolData["end_time"])
        school.startTime=stringToString(schoolData["start_time"])
        school.faxNumber=stringToString(schoolData["fax_number"])
        school.grades2018=stringToString(schoolData["grades2018"])
        school.schoolName=stringToString(schoolData["school_name"])
        school.finalGrades=stringToString(schoolData["finalgrades"])
        school.schoolEmail=stringToString(schoolData["school_email"])
        school.ellPrograms=stringToString(schoolData["ell_programs"])
        school.phoneNumber=stringToString(schoolData["phone_number"])
        school.schoolSports=stringToString(schoolData["school_sports"])
        school.additionalInfo=stringToString(schoolData["addtl_info1"])
        school.geoEligibility=stringToString(schoolData["geoeligibility"])
        school.psalSportsBoys=stringToString(schoolData["psal_sports_boys"])
        school.psalSportsCoed=stringToString(schoolData["psal_sports_coed"])
        school.languageClasses=stringToString(schoolData["language_classes"])
        school.psalSportsGirls=stringToString(schoolData["psal_sports_girls"])
        school.overviewParagraph=stringToString(schoolData["overview_paragraph"])
        school.diplomaEndorsements=stringToString(schoolData["diplomaendorsements"])
        school.advancedPlacementCourses=stringToString(schoolData["advancedplacement_courses"])
        school.extracurricularActivities=stringToString(schoolData["extracurricular_activities"])
        
        //Numeric types
        school.totalStudents=stringToInt(schoolData["total_students"])
        
        school.pctStuSafe=stringToFloat(schoolData["pct_stu_safe"])
        school.attendanceRate=stringToFloat(schoolData["attendance_rate"])
        school.graduationRate=stringToFloat(schoolData["graduation_rate"])
        school.collegeCareerRate=stringToFloat(schoolData["college_career_rate"])
        school.pctStuEnoughVariety=stringToFloat(schoolData["pct_stu_enough_variety"])
        
        //Flags
        school.boys=stringToBool(schoolData["boys"])
        school.pbat=stringToBool(schoolData["pbat"])
        school.girls=stringToBool(schoolData["girls"])
        school.ptech=stringToBool(schoolData["ptech"])
        school.transfer=stringToBool(schoolData["specialized"])
        school.specialized=stringToBool(schoolData["specialized"])
        school.sharedSpace=stringToBool(schoolData["shared_space"])
        school.international=stringToBool(schoolData["international"])
        school.school10thSeats=stringToBool(schoolData["school_10th_seats"])
        school.schoolAccessibilityDescription=stringToBool(schoolData["school_accessibility_description"])
    }
    
    func populateSAT(satData:Dictionary<String, String>, sat:SATResult){
        sat.dbn=stringToString(satData["dbn"])
        sat.schoolName=stringToString(satData["school_name"])
        
        sat.numOfSatTestTakers=stringToInt(satData["num_of_sat_test_takers"])
        sat.satCriticalReadingAvgScore=stringToInt(satData["sat_critical_reading_avg_score"])
        sat.satMathAvgScore=stringToInt(satData["sat_math_avg_score"])
        sat.satWritingAvgScore=stringToInt(satData["sat_writing_avg_score"])
    }
    
    //The return value here is primarily to allow for easier testing of the parsing routines
    //as the school is maintained in the context
    @discardableResult
    func insertHS(schoolData:Dictionary<String, String>) -> HighSchool {
        let school=HighSchool(context: self.moc)
        populateHighSchool(schoolData: schoolData, school: school)
        if includeChildEntities {
            school.address=insertAddress(schoolData: schoolData)
        }
        
        return school
    }
    
    func batchInsertHS(schoolData:Dictionary<String, String>){
        if #available(iOS 14.0, *) {
            let req=NSBatchInsertRequest(entityName: "HighSchool", managedObjectHandler: {[self, schoolData] hs in
                let hs:HighSchool=hs as! HighSchool
                self.populateHighSchool(schoolData:schoolData, school:hs)
                return true
            })
            do {
                try moc.execute(req)
            } catch {
                os_log(.error, "%@", "\(error)")
            }
        } else {
            insertHS(schoolData: schoolData)
        }
    }
    
    @discardableResult
    func insertAddress(schoolData:Dictionary<String, String>, ctx:NSManagedObjectContext? = nil)->Address {
        let address=Address(context: ctx ?? moc)
        populateAddress(schoolData: schoolData, address: address)
        return address
    }
    
    @discardableResult
    func insertSATResult(satData:Dictionary<String, String>) -> SATResult {
        let satResults=SATResult(context: moc)
        populateSAT(satData: satData, sat: satResults)
        
        return satResults
    }

    
    func batchInsertSATResults(satData:Dictionary<String,String>) {
        if #available(iOS 14.0, *) {
            let req=NSBatchInsertRequest(entityName: "SATResult", managedObjectHandler: {[self, satData] satResult in
                let satResults:SATResult=satResult as! SATResult
                self.populateSAT(satData: satData, sat: satResults)
                return true
            })
            do {
                try moc.execute(req)
            } catch {
                os_log(.error, "%@", "\(error)")
            }
        } else {
            insertSATResult(satData:satData)
        }
    }
}
    
    
