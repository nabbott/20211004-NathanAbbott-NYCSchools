//
//  ParseUtil.swift
//  JPMCPrototype
//
//  Created by Nathan Abbott on 10/2/21.
//

import Foundation
import CoreData
import OSLog

enum ImportErrors:Error {
    case missingFile
    case jsonParseFailed
}

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

//FIXME: All entities that depend on DBN to facilitate relationships with a highschool
//should log if this value is missing from the original file. It should not be for
//addresses as this is part of the HS data
internal
func populateAddress(schoolData:Dictionary<String, String>, address:Address){
    address.bbl=stringToString(schoolData["bbl"])
    address.bin=stringToString(schoolData["bin"])
    address.dbn=stringToString(schoolData["dbn"])
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

internal
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

//FIXME: All entities that depend on DBN to facilitate relationships with a highschool
//should log if this value is missing from the original file. It should not be for
//addresses as this is part of the HS data
internal
func populateSAT(satData:Dictionary<String, String>, sat:SATResult){
    sat.dbn=stringToString(satData["dbn"])
    sat.schoolName=stringToString(satData["school_name"])
    
    sat.numOfSatTestTakers=stringToInt(satData["num_of_sat_test_takers"])
    sat.satCriticalReadingAvgScore=stringToInt(satData["sat_critical_reading_avg_score"])
    sat.satMathAvgScore=stringToInt(satData["sat_math_avg_score"])
    sat.satWritingAvgScore=stringToInt(satData["sat_writing_avg_score"])
}

//MARK: - The data import engine. Parses a data object containing JSON.
typealias JSONRecords = Array<Dictionary<String,String>>
class HSDataImporter {
//    private let moc:NSManagedObjectContext
//    private let includeChildEntities:Bool
    
    private let batchProcess:Bool
    init(batchProcess:Bool=false) {
        self.batchProcess=batchProcess
    }
    
    func dataToJSON(data:Data) throws -> JSONRecords {
        let rawJSON=try JSONSerialization.jsonObject(with: data, options: .allowFragments)
        return rawJSON as! Array<Dictionary<String, String>>
    }
    
    func importAllDataAndEstablishRelationships(highSchools:Data, satResults:Data, ctx:NSManagedObjectContext) throws {
        let hs=try dataToJSON(data: highSchools)
        let sat=try dataToJSON(data: satResults)
        try importAllDataAndEstablishRelationships(highSchools: hs, satResults: sat, ctx: ctx)
    }
    
    func importAllDataAndEstablishRelationships(highSchools:JSONRecords, satResults:JSONRecords, ctx:NSManagedObjectContext) throws {
        try importSchools(schools: highSchools,ctx: ctx)
        try importAddresses(addresses: highSchools,ctx: ctx)
        try importSATResults(satResults: satResults,ctx: ctx)
        
        try establishRelationship(ctx: ctx, entityType: SATResult.self, relKey: "satResults")
        try establishRelationship(ctx: ctx, entityType: Address.self, relKey: "address")
    }

    func importSchools(schools:JSONRecords, ctx:NSManagedObjectContext) throws {
        try genericInsert(ctx: ctx, records: schools, populator:{ (record:Dictionary<String,String>, entity:HighSchool) in
            populateHighSchool(schoolData: record, school: entity)
        })
    }
    
    func importAddresses(addresses:JSONRecords, ctx:NSManagedObjectContext) throws {
        try genericInsert(ctx: ctx, records: addresses) { (record:Dictionary<String,String>, entity:Address) in
            populateAddress(schoolData: record, address: entity)
        }
    }
    
    func importSATResults(satResults:JSONRecords, ctx:NSManagedObjectContext) throws {
        try genericInsert(ctx: ctx, records: satResults) { (record:Dictionary<String,String>, entity:SATResult) in
            populateSAT(satData: record, sat: entity)
        }
    }
    
    func establishRelationship<T>(ctx:NSManagedObjectContext, entityType:T.Type, relKey:String) throws where T:NSManagedObject {
        let entityName="\(entityType)"
        let childFR=NSFetchRequest<T>(entityName: entityName)
        childFR.propertiesToFetch=["dbn"]
        
        try ctx.fetch(childFR).forEach { child in
            guard let dbn=child.value(forKey:"dbn") as? String else {
                os_log(.error, "Missing dbn property for %@", entityName)
                return
            }
            
            let fr=NSFetchRequest<HighSchool>(entityName: "HighSchool")
            fr.predicate=NSPredicate(format: "dbn=%@", argumentArray: [dbn])
            
            do {
                guard let hs=try ctx.fetch(fr).first else {
                    os_log(.error, "Could not find school for %@ at: %@", entityName, dbn)
                    return
                }
                hs.setValue(child, forKey: relKey)
            }
            catch {
                os_log(.error, "%@", error as NSError)
            }
        }
    }
    
    func genericInsert<T>(ctx:NSManagedObjectContext,records:JSONRecords, populator:@escaping(Dictionary<String,String>,T)->())  throws where T:NSManagedObject {
        
        let entityName:String="\(T.self)"
        if #available(iOS 14.0, *), batchProcess {
            var iter=records.makeIterator()
            let req=NSBatchInsertRequest(entityName: entityName, managedObjectHandler: {managedObject in
                guard let record=iter.next() else {return true}
                let entity:T=managedObject as! T
                
                let _ = populator(record,entity)
                return false
            })
            req.resultType = .statusOnly
            do {
                try ctx.execute(req)
                #if DEBUG
                let count=try ctx.count(for:NSFetchRequest<T>(entityName: entityName))
                os_log(.debug,"%@","Inserted \(count) \(entityName) records")
                #endif
            } catch {
                os_log(.error, "Threw error inserting new $@ records: %@", entityName, "\(error)")
                throw error
            }
        } else {
            records.forEach { address in
                let entity=NSEntityDescription.insertNewObject(forEntityName: entityName, into: ctx) as! T
                populator(address,entity)
            }
        }
    }
    
    func deleteAllHSData(ctx:NSManagedObjectContext, batch:Bool=false) throws {
        let entities=["HighSchool"]//,"SATResult","Address"]
        try entities.forEach { entity in
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            if batch {
                let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                batchDeleteRequest.resultType = .resultTypeCount
                do {
                    let result=try ctx.execute(batchDeleteRequest)
                    if let rowsDeleted=(result as! NSBatchDeleteResult).result as? NSNumber {
                        os_log(.debug,"%@, %@ rows deleted", rowsDeleted,entity)
                    }
                } catch {
                    os_log(.error, "%@", error as NSError)
                    throw error
                }
            } else {
                try ctx.fetch(fetchRequest).forEach { hs in
                    ctx.delete(hs as! NSManagedObject)
                }
            }
        }
    }
}
