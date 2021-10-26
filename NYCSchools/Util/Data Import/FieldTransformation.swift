//
//  FieldTransformation.swift
//  NYCSchools
//
//  Created by Nathan Abbott on 10/25/21.
//

import UIKit
import os

//MARK: - Data Transformers
/// Basic contract for an algorithm maps a denormalized record to 1 or more records.
protocol DataTransformer {
    var entityName:String! {get}
    
    
    /// Transforms a remote record directly from NYC open data to a local representation.
    /// - Parameter record: A NYC open data record.
    /// - Returns: an array of dictionarys where each key is a local field name and the string value
    /// provided in the NYC open data record has been converted to its local data type.
    @discardableResult
    func transform(record:Record) -> Array<Dictionary<String,Any>>
}

enum TransformationErrors:Error {
    case mappingFileError(desc:String?)
}

class BaseTransformer: DataTransformer {
    let entityName:String!
    
    init(entityName:String) {
        self.entityName=entityName
    }
    
    @discardableResult
    func transform(record:Record) -> Array<Dictionary<String,Any>> {return []}
}

/// A transformer for resonably simple data types, usually ones where there is only one instance per record and the field  names
/// don't need additional distinguishing tags.
class MappingTransformer: BaseTransformer {
    let map:[String:(localName:String, converter:DataConverter)]
    
    /// Creates a mapping transformer.
    /// - Parameters:
    ///   - mappingFile: The mapping file is a JSON file consisting of an array of three element arrays where
    ///   the first element is the field name in the NYC open data record, the second element is field name as defined in the core data model
    ///   for the entity identified by entity name, and the third element is the data type as defined in the core data model. The data type should correspond
    ///   to one of the types defined in DataConverter. The mapping file should be stored in the app's asset catalog as a data set.
    ///   - entityName: The name of the entity as declared in the core data model
    /// - Throws: An error if the mapping file could not be read.
    init?(mappingFile:String, entityName:String) throws {
//        guard let mapping=NSDataAsset(name: mappingFile)?.data else {
//            os_log(.debug, "Unable to load the mapping file: %@", mappingFile)
//            throw TransformationErrors.mappingFileError(desc:"Unable to load the mapping file.")
//        }
        
        var data:Data!
        let fManager=FileManager.default
        guard let fileURL=Bundle.main.url(forResource: mappingFile, withExtension:"json"), fManager.isReadableFile(atPath: fileURL.path) else {
            throw CoreDataImportErrors.serializedDataFileUnreadable(msg: "File: \(mappingFile) could not be found")
        }
        
        do {
            data=try Data(contentsOf: fileURL, options: .uncached)
        } catch {
            throw CoreDataImportErrors.deserializationError(err: error)
        }
        
        guard let rawJSON=try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? Array<Array<String>> else {
            os_log(.debug, "%@", "Unable to convert the mapping file to json")
            return nil
        }
        
        var map:[String:(localName:String, converter:DataConverter)]=[:]
        rawJSON.forEach { fieldMapping in
            map[fieldMapping[0]]=(fieldMapping[1],DataConverter(rawValue: fieldMapping[2])!)
        }

        self.map=map
        super.init(entityName: entityName)
    }
    
    @discardableResult
    override
    func transform(record:Record) -> Array<Dictionary<String,Any>> {
        var object:[String:Any]=[:]
        map.forEach { kv in
            guard let value=record[kv.key] else {return}
            
            object[kv.value.localName]=kv.value.converter.convert!(value)
        }
        
        return object.isEmpty ? []:[object]
    }
}

/// Transformer for requires portion of a NYC open data record. There can be up to 12 requirements
/// for each of the ten programs.
class ProgReqsTransformer:BaseTransformer {
    
    @discardableResult
    override
    func transform(record:Record) -> Array<Dictionary<String,Any>> {
        
        var records:[[String:Any]]=[]
        (1...12).forEach { reqNo in
            (1...10).forEach { progNo in
                let field="requirement\(reqNo)_\(progNo)"
                guard let req = record[field] else {return}
                
                var object:[String:Any]=[:]
                object["dbn"]=record["dbn"]
                object["requirementNo"]=Int16(reqNo)
                object["programNo"]=Int16(progNo)
                object["requirement"]=req
                records.append(object)
            }
        }
        
        return records
    }
}

/// Transformer for the admissions priority portion of an NYC open data record. There can be up to 7
/// priority levels for each of the ten programs
class AdmissionsPriorityTransformer:BaseTransformer {
    
    @discardableResult
    override
    func transform(record: Record) -> Array<Dictionary<String, Any>> {
        var records:[[String:Any]]=[]
        
        (1...7).forEach { priorityNo in
            (1...10).forEach { progNo in
                let field="admissionspriority\(priorityNo)\(progNo)"
                guard let priority = record[field] else {return}
                
                var object:[String:Any]=[:]
                object["dbn"]=record["dbn"]
                object["priorityNo"]=Int16(priorityNo)
                object["programNo"]=Int16(progNo)
                object["priority"]=priority
                records.append(object)
            }
        }
        
        return records
    }
}

/// A transform for the program portion of the NYC open data record. There can be up to 10 programs
/// per high school
class ProgramTransformer:MappingTransformer {
    
    @discardableResult
    override
    func transform(record:Record) -> Array<Dictionary<String,Any>> {
        var programs:[[String:Any]]=[]
        
        (1...10).forEach { progNo in
            guard let _ = record["program\(progNo)"] else {return}
            
            var program:[String:Any]=[:]
            map.forEach { kv in
                let field=String(format: kv.key, progNo)
                guard let value=record[field] else {return}
                program[kv.value.localName]=kv.value.converter.convert!(value)
            }
            
            guard !program.isEmpty else {return}
            
            program["dbn"]=record["dbn"]
            program["programNumber"]=Int16(progNo)
            
            programs.append(program)
        }

        return programs
    }
}
