//
//  ParseUtil.swift
//  JPMCPrototype
//
//  Created by Nathan Abbott on 10/2/21.
//

import UIKit
import CoreData
import OSLog


//https://data.cityofnewyork.us/resource/f9bf-2cp4.json
//https://data.cityofnewyork.us/resource/s3k6-pzi2.json


//MARK: - The data import engine. Parses a data object containing JSON.

//MARK: - Core data import
enum CoreDataImportErrors:Error {
    case bulkDeleteError(err:Error)
    case bulkInsertError(err:Error)
    case serializedDataFileUnreadable(msg:String)
    case deserializationError(err:Error)
    case persistentStoreCreationError(err:Error)
    case persistentStoreUpdateError(err:Error)
    case relationshipFailureError(err:Error)
    case entityDescriptionNotFound(msg:String)
    case mocSaveError(err:Error)
}

/// The main import driver routine. Takes the name of school and SAT JSON files, normalizes the records, transforms the original field names
/// to local field names and converts the data from strings to their respective local types. A new data store is created and the new data is written
/// into it. If the import succeeds the url to the new store is returned and the client can choose to delete the working store and move the new store over.

/// - Parameters:
///   - schoolFile: Name of the JSON file containing the high school records without the '.json' extension (the file is expected to have this but
///   do not append it the the file name). File is expected to be a JSON format plain text file.
///   - satFile: Name of the JSON file containing the sat records without the '.json' extension (the file is expected to have this but
///   do not append it the the file name). File is expected to be a JSON format plain text file.
/// - Returns: A URL to the new data store if import was successful
func importSchoolAndSATResults(schoolFile:String, satFile:String)->NSPersistentContainer? {
    var newStore:NSPersistentContainer?
    do {
        guard let store=try newSQLiteStore(modelName: "NYCSchools", storeName: "ImportStore") else {
            //FIXME - throw an exception here
            return nil
        }
        let ctx=store.viewContext

        importHighSchools(schoolFile: schoolFile, ctx: ctx)
        importSATResults(satFile: satFile, ctx: ctx)
        
        establishProgramRelationships(ctx: ctx)
        establishSchoolRelationships(ctx: ctx)
        newStore=store
    } catch {
        os_log(.error, "%@", error as NSError)
    }
    
    return newStore
}
//MARK: - Core Data Store Routines
/// Creates a new SQLite core data store
/// - Parameters:
///   - modelName: The data model for the store. Should be the work the working store is using
///   - storeName: File name for the new data store
/// - Throws: An import error if the store couldn't be created for some reason.
/// - Returns: A tuple containing a url to the new store and a persistent container object from which a managed object context can be retrieved.
func newSQLiteStore(modelName:String, storeName:String) throws -> NSPersistentContainer? {
    guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd") else {
        os_log(.error,"Failed to find data model.")
        return nil
    }
    
    guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
        os_log(.error,"Failed to create model from file: %@.", modelURL.path)
        return nil
    }
    
    let containerURL=NSPersistentContainer.defaultDirectoryURL()
//    let containerURL=FileManager.default.temporaryDirectory
    let dbURL:URL=URL(fileURLWithPath: "\(storeName).sqlite", relativeTo: containerURL)
    
    let psc=NSPersistentContainer(name: storeName, managedObjectModel: mom)
    let coordinator=psc.persistentStoreCoordinator
    do {
        try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: dbURL, options: nil)
        return psc
    } catch {
        os_log(.error, "%@", error as NSError)
        throw CoreDataImportErrors.persistentStoreCreationError(err: error)
    }
}

/// Overwrites the core data store at oldUrl with the store at newUrl.
/// - Parameters:
///   - coordinator: The persistent store coordinator containing the data store oldUrl points to
///   - oldURL: URL identifying the store to be replaced
///   - newURL: URL identifying the store which will replace the old one.
/// - Throws: An import error if the old store couldn't be updated.
func updateExistingStoreWithNewStore(storeCoordinator coordinator: NSPersistentStoreCoordinator, oldURL:URL, newURL:URL) throws {
    do {
        try coordinator.replacePersistentStore(at: oldURL, destinationOptions: nil, withPersistentStoreFrom: newURL, sourceOptions: nil, ofType: NSSQLiteStoreType)
//        try coordinator.destroyPersistentStore(at: newURL, ofType: NSSQLiteStoreType, options: nil)
    } catch {
        throw CoreDataImportErrors.persistentStoreUpdateError(err: error)
    }
}

func updateExistingStoreWithNewStore(store: NSPersistentStore, oldURL:URL) throws {
    do {
        guard let coordinator=store.persistentStoreCoordinator else {return}
        try coordinator.migratePersistentStore(store, to: oldURL, options: nil, withType: NSSQLiteStoreType)
    } catch {
        throw CoreDataImportErrors.persistentStoreUpdateError(err: error)
    }
}

func removeTemporaryStore(tmpContainer:NSPersistentContainer) throws {
    let coordinator=tmpContainer.persistentStoreCoordinator
    guard let store=coordinator.persistentStores.first else {return}
    do {
        let url=store.url!
        try coordinator.remove(store)
        try coordinator.destroyPersistentStore(at: url, ofType: NSSQLiteStoreType, options: nil)
        os_log(.debug,"Removed temporary store")
    } catch {
        os_log(.error,"Failed to remove temporary store: %@",error as NSError)
        throw CoreDataImportErrors.persistentStoreUpdateError(err: error)
    }
}

//MARK: - JSON Import Routines

/// Reads the JSON file within the App's bundle (note: file that were downloaded after the app was shipped may not be in the bundle).
/// - Parameters:
///   - fileName: Name of the JSON file
///   - ext: The extension; "json" is the default
/// - Throws: An exception if the file was unable to be found or if there was a problem deserializing it.
/// - Returns: An array of Dictionay<String,String> representing fields and values respectively
func deserializeData(fileName:String, ext:String="json", isDataAsset:Bool=true) throws -> Array<Record>? {
    var data:Data!
//    if isDataAsset {
//        guard let d=NSDataAsset(name: fileName)?.data else {
//            throw CoreDataImportErrors.serializedDataFileUnreadable(msg: "File: \(fileName) could not be found")
//        }
//        data=d
//    } else {
        let fManager=FileManager.default
        guard let fileURL=Bundle.main.url(forResource: fileName, withExtension:ext), fManager.isReadableFile(atPath: fileURL.path) else {
            throw CoreDataImportErrors.serializedDataFileUnreadable(msg: "File: \(fileName) could not be found")
        }
        
        do {
            data=try Data(contentsOf: fileURL, options: .uncached)
        } catch {
            throw CoreDataImportErrors.deserializationError(err: error)
        }
//    }
    
    var records:Array<Record>
    do {
        records=try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! Array<Record>
    } catch {
        throw CoreDataImportErrors.deserializationError(err: error)
    }
    
    return records
}

/// Given a collection of Dictionary<String, String> where the key is a field name and the value is a field value, transforms the names into local names and the strings into
/// local data types based in the array of transformations.
/// - Parameters:
///   - records: A collection of:  Dictionary<String, String> objects.
///   - transformations: An array of DataTransformer instances. Each instance takes a remote field name and a string value and converts it to a local field name
///   and the correct data type. As a record is highly denormalized the a given transformer may return more than one dictionary as part of the normalization process.
/// - Returns: A dictionary of arrays of dictionarys - The first key is the data type some part of the record struct was transformed into (a Program for example) and the array
/// holds from 1...N instance of that type. Program, for example, occurs up to 10 times in a single reccord.
func transformDeserializedData(records:AnyCollection<Record>, transformations:[DataTransformer]) -> [String:[[String:Any]]] {
    var transformed:[String:[[String:Any]]]=[:]
    
    records.forEach { record in
        transformations.forEach { transformation in
            var transformedRecords=transformed[transformation.entityName, default:[]]
            transformedRecords.append(contentsOf: transformation.transform(record: record))
            transformed[transformation.entityName]=transformedRecords
        }
    }
    
    return transformed
}

func importHighSchools(schoolFile:String, ctx:NSManagedObjectContext){
    do {
        if let schools=try deserializeData(fileName: schoolFile) {
            let transformers:[DataTransformer]=[
                try MappingTransformer(mappingFile: "HighSchool", entityName: "HighSchool")!,
                try MappingTransformer(mappingFile: "Address", entityName: "Address")!,
                try ProgramTransformer(mappingFile: "Program", entityName: "Program")!,
                ProgReqsTransformer(entityName: "ProgramAdmissionReqs"),
                AdmissionsPriorityTransformer(entityName: "ProgramAdmissionsPriority")
            ]
            os_log(.debug, "Transforming school records")
            let transformed=transformDeserializedData(records: AnyCollection(schools), transformations: transformers)
            os_log(.debug, "Transformed %d school records", schools.count)
            transformed.forEach {typeAndValues in
                do {
                    try persistNewEntities(entityProperties: typeAndValues.value, entityName: typeAndValues.key, ctx: ctx)
                } catch {
                    os_log(.error,"%@",error as NSError)
                }
            }
        }
    } catch {
        os_log(.error, "%@", error as NSError)
    }
}

func importSATResults(satFile:String, ctx:NSManagedObjectContext){
    do {
        if let sats=try deserializeData(fileName: satFile) {
            let transformers:[DataTransformer]=[
                try MappingTransformer(mappingFile: "SATResults", entityName: "SATResult")!
            ]
            os_log(.debug, "Transforming SAT records")
            let transformed=transformDeserializedData(records: AnyCollection(sats), transformations: transformers)
            os_log(.debug, "Transformed %d SAT records", sats.count)
            
            transformed.forEach {typeAndValues in
                do {
                    try persistNewEntities(entityProperties: typeAndValues.value, entityName: typeAndValues.key, ctx: ctx)
                } catch {
                    os_log(.error,"%@",error as NSError)
                }
            }
        }
    } catch {
        os_log(.error, "%@", error as NSError)
    }
}

//MARK: - Managed Object Routines

/// Performs a batch delete of all instance of type identified by entity name in the supplied context.
/// - Parameters:
///   - entityName: Name of the core data entity to be deleted, HighSchool for example.
///   - ctx: The managed object context handling the delete
/// - Throws: An error if the delete fails
func deleteAll(entityName:String, ctx:NSManagedObjectContext) throws {
    let deleteRequest=NSBatchDeleteRequest(fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: entityName))
    deleteRequest.resultType = .resultTypeCount
    do {
        let result=try ctx.execute(deleteRequest)
        if let rowsDeleted=(result as! NSBatchDeleteResult).result as? NSNumber {
            os_log(.debug,"%@, %@ rows deleted", rowsDeleted,entityName)
        }
    } catch {
        os_log(.error, "%@", error as NSError)
        ctx.rollback()
        throw CoreDataImportErrors.bulkDeleteError(err: error)
    }
}

/// Writes the entities identified by entityName and defined in entityProperties to the store managed by the supplied managed object context.
/// - Parameters:
///   - entityProperties: An array of dictionaries where the key is a field and the value is the field value.
///   - entityName: Name of the core data type to persist
///   - ctx: The managed object context handling the persistence
///   - batchInsert: Whether or not batch processing should be used. Set this to false for unit testing
/// - Throws: An error if the write fails
func persistNewEntities(entityProperties:Array<[String:Any]>, entityName:String, ctx:NSManagedObjectContext, batchInsert:Bool=true) throws {
    os_log(.debug, "Preparing to persist %d instances of %@",entityProperties.count, entityName)

    if #available(iOS 13, *), batchInsert {
        try batchPersistNewEntities(entityProperties: entityProperties, entityName: entityName, ctx: ctx)
    } else {
        try singlePersistNewEntities(entityProperties: entityProperties, entityName: entityName, ctx: ctx)
    }
    os_log(.debug, "Persisted %d instances of %@",entityProperties.count, entityName)
}

func singlePersistNewEntities(entityProperties:Array<[String:Any]>, entityName:String, ctx:NSManagedObjectContext) throws {
    guard let entityDesc=ctx.persistentStoreCoordinator?.managedObjectModel.entitiesByName[entityName] else {
        throw CoreDataImportErrors.entityDescriptionNotFound(msg:"Description not found for: \(entityName)")
    }
    
    entityProperties.forEach{ props in
        let managedObject=NSManagedObject(entity: entityDesc, insertInto: ctx)
        props.forEach { kv in
            managedObject.setValue(kv.value, forKey: kv.key)
        }
    }
    
    if ctx.hasChanges {
        do {
            try ctx.save()
        } catch {
            ctx.rollback()
            throw CoreDataImportErrors.mocSaveError(err: error)
        }
    }
}

@available(iOS 13,*)
func batchPersistNewEntities(entityProperties:Array<[String:Any]>, entityName:String, ctx:NSManagedObjectContext) throws {
    guard let entityDesc=ctx.persistentStoreCoordinator?.managedObjectModel.entitiesByName[entityName] else {
        throw CoreDataImportErrors.entityDescriptionNotFound(msg:"Description not found for: \(entityName)")
    }

    let insertRequest=NSBatchInsertRequest(entity: entityDesc, objects: entityProperties)
    insertRequest.resultType = .count
    
    do {
        let result=try ctx.execute(insertRequest)
        if let rowsInserted=(result as! NSBatchInsertResult).result as? NSNumber {
            os_log(.debug,"%@, %@ rows inserted", rowsInserted,entityName)
        }
    } catch {
        os_log(.error, "%@", error as NSError)
        ctx.rollback()
        throw CoreDataImportErrors.bulkInsertError(err: error)
    }
}

/// Batch inserts do not allow for the creation of relationships, that is handled in this routine. For each program, the relationships between it
/// and the program's requirements and admissions priorities are established
/// - Parameter ctx: The managed object context to use. This should be the same context that has been used for the other import routines
func establishProgramRelationships(ctx:NSManagedObjectContext) {
    print("Current thread: \(Thread.current.name ?? "NO NAME")")
    
    let programFR=NSFetchRequest<Program>(entityName: "Program")
    programFR.sortDescriptors=[NSSortDescriptor(key: "dbn", ascending: true)]
//    programFR.relationshipKeyPathsForPrefetching=["admissionPriority","admissionReqs"]
    let childTypeAndHandlers:[(NSManagedObject.Type, (Program,NSSet)->())]=[
        (ProgramAdmissionsPriority.self, {(p,c) in p.addToAdmissionPriority(c)}),
        (ProgramAdmissionReqs.self, {(p,c) in p.addToAdmissionReqs(c)})
    ]

    func fetchChildren<T>(prog:Program, childType:T.Type) -> [T] where T:NSManagedObject {
        let fr=NSFetchRequest<T>(entityName: "\(childType)")
        fr.predicate=NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "dbn=%@", prog.dbn!),
            NSPredicate(format: "programNo=%d", prog.programNumber)
        ])
        var children:[T]!
        do {
            //FIXME: Handle this
            children=try ctx.fetch(fr)
        } catch {
            os_log(.error, "%@", error as NSError)
        }
        
        return children
    }
    
    //FIXME: Handle potential errors
    os_log(.debug,"Preparing to establish program relationships")
    try! ctx.fetch(programFR).forEach { program in
        childTypeAndHandlers.forEach {typeAndHandler in
            let children=fetchChildren(prog: program, childType: typeAndHandler.0)
            guard !children.isEmpty else {return}

//            print("Program: \(program.programNumber) for high school: \(program.dbn!), relationship: \(typeAndHandler.0)")
            typeAndHandler.1(program,NSSet(array: children))
        }
    }
    if ctx.hasChanges {
        //FIXME: Handle potential errors
        do {
            try ctx.save()
        } catch {
            os_log(.error, "%@", error as NSError)
            ctx.rollback()
        }
    }
    
    os_log(.debug,"Established program relationships")
}

/// Batch inserts do not allow for the creation of relationships, that is handled in this routine. For each school, the relationships between it
/// and the schools's address, SAT results, and programs are established
/// - Parameter ctx: The managed object context to use. This should be the same context that has been used for the other import routines
func establishSchoolRelationships(ctx:NSManagedObjectContext) {
    let schoolFR=NSFetchRequest<HighSchool>(entityName: "HighSchool")
    let childTypeAndHandlers:[(NSManagedObject.Type, (HighSchool,NSSet)->())]=[
        (Address.self, { (p,c) in if let a=c.allObjects.first as? Address {p.address=a} }),
        (SATResult.self, {(p,c) in if let s=c.allObjects.first as? SATResult {p.satResults=s} }),
        (Program.self, { (p,c) in p.addToPrograms(c) })
    ]
    
    func fetchChildren<T>(school:HighSchool, childType:T.Type) -> [T] where T:NSManagedObject {
        let fr=NSFetchRequest<T>(entityName: "\(childType)")
        fr.predicate=NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "dbn=%@", school.dbn!)
        ])

        //FIXME: Handle potential errors
        return try! ctx.fetch(fr)
    }

    //FIXME: Handle potential errors
    os_log(.debug,"Preparing to establish school relationships")
    try! ctx.fetch(schoolFR).forEach { school in
        childTypeAndHandlers.forEach { typeAndHandler in
            let children=fetchChildren(school: school, childType: typeAndHandler.0)
            guard !children.isEmpty else {return}

            typeAndHandler.1(school,NSSet(array: children))
        }
    }
    
    if ctx.hasChanges {
        //FIXME: Handle potential errors
        do {
            try ctx.save()
        } catch {
            os_log(.error, "%@", error as NSError)
            ctx.rollback()
        }
    }
    os_log(.debug,"Established school relationships")
}
