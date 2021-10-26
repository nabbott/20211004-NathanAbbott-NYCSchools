//
//  DataTypeHandlers.swift
//  NYCSchools
//
//  Created by Nathan Abbott on 10/25/21.
//

import Foundation
import os

//MARK: - Utility functions to handle data type conversions, cleaning, and defaults
internal
func log(_ msg:String, logType:OSLogType = .debug){
//    if #available(iOS 14, *) {
//        let log=OSLog(subsystem: Bundle.main.bundleIdentifier ?? "NYHS_Directory", category: "Data Import")
//        os_log(logType, log: log, "\(msg)")
//    } else {
//        os_log(logType, "%@", msg)
//    }
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

//internal
//func stringToTime(input:String)->Date {
//    let df=DateFormatter()
//    df.locale=Locale.current
//    df.setLocalizedDateFormatFromTemplate("hh:mm a")
//        //.dateFormat(fromTemplate: "h:mma", options: 0, locale: Locale.current)
//    return df.date(from: input)!
//}


//FIXME: Return nil for all failed conversions
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

enum DataConverter:String {
    case bool, string, float, double, int
    
    var convert:((String?)->Any)? {
        switch self {
        case .bool:
            return stringToBool(_:)
        case .string:
            return stringToString(_:)
        case .float:
            return stringToFloat(_:)
        case .double:
            return stringToDouble(_:)
        case .int:
            return stringToInt(_:)
        }
    }
}


typealias Record = Dictionary<String,String>
