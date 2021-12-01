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
    case persistentStoreCreationError(err:Error?, msg:String?=nil)
    case persistentStoreUpdateError(err:Error)
    case relationshipFailureError(err:Error)
    case entityDescriptionNotFound(msg:String)
    case mocSaveError(err:Error)
    case mappingFileError(err:Error)
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
func importSchoolAndSATResults(schoolFile:String, satFile:String) throws ->NSPersistentContainer? {
    var newStore:NSPersistentContainer!
    do {
        newStore=try newSQLiteStore(modelName: "NYCSchools", storeName: "ImportStore")
    } catch {
        //Escape here if the temp store couldn't be created
        throw CoreDataImportErrors.persistentStoreCreationError(err: error)
    }
    
    let ctx=NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    ctx.persistentStoreCoordinator=newStore.persistentStoreCoordinator
    do {
        //The routines below will error out if the transformation mapping or
        //the input files were missing or corrupt
        try persistTransformedData(
            transformed: try importAndTransformHSData(schools: schoolFile),
            ctx: ctx)
        
        try persistTransformedData(
            transformed: try importAndTransformSATResults(sats: satFile),
            ctx: ctx)
        
        try establishSchoolRelationships(ctx: ctx)
        try establishProgramRelationships(ctx: ctx)
    } catch {
        os_log(.error, "%@", error as NSError)
        try? removeTemporaryStore(tmpContainer: newStore)
        throw error
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
func newSQLiteStore(modelName:String, storeName:String, path:URL=NSPersistentContainer.defaultDirectoryURL()) throws -> NSPersistentContainer {
    guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd") else {
        os_log(.error,"Failed to find data model.")
        throw CoreDataImportErrors.persistentStoreCreationError(err:nil, msg:"Failed to find data model: \(modelName).")
    }
    
    guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
        os_log(.error,"Failed to create model from file: %@.", modelURL.path)
        throw CoreDataImportErrors.persistentStoreCreationError(err:nil, msg:"Failed to instantiate the model at: \(modelURL).")
    }
    
    let dbURL:URL=URL(fileURLWithPath: "\(storeName).sqlite", relativeTo: path)
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
    let fManager=FileManager.default
    guard let fileURL=Bundle.main.url(forResource: fileName, withExtension:ext), fManager.isReadableFile(atPath: fileURL.path) else {
        throw CoreDataImportErrors.serializedDataFileUnreadable(msg: "File: \(fileName) could not be found")
    }
    
    do {
        data=try Data(contentsOf: fileURL, options: .uncached)
    } catch {
        throw CoreDataImportErrors.deserializationError(err: error)
    }
    
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

/// Reads in the JSON file provided by NYC Open Data and drives the transformation routine that converts each field name to a local
/// name and field value from a string to the data type defined in the managed object model.
/// - Parameter schoolFile: JSON file provided by NYC Open Data
/// - Throws: An error if there is a problem with the mapping file or deserializing the JSON file
/// - Returns: A dictionary whose keys are the names of entities from the managed object mode and whos values
/// are arrays of dictionarys representing fields and values for each instance of that type found in a give input record. For
/// example, programs may have 10 instances per school
func importAndTransformHSData(schools:String) throws -> [String:[[String:Any]]] {
    var transformed:[String:[[String:Any]]]!
    var transformers:[DataTransformer]!
    do {
        transformers=[
            try MappingTransformer(mappingFile: "HighSchool", entityName: "HighSchool")!,
            try MappingTransformer(mappingFile: "Address", entityName: "Address")!,
            try ProgramTransformer(mappingFile: "Program", entityName: "Program")!,
            ProgReqsTransformer(entityName: "ProgramAdmissionReqs"),
            AdmissionsPriorityTransformer(entityName: "ProgramAdmissionsPriority")
        ]
    } catch {
        //Escape here if unable to load a transformation file
        throw CoreDataImportErrors.mappingFileError(err: error)
    }
    
    do {
        if let schools=try deserializeData(fileName: schools) {
            os_log(.debug, "Transforming school records")
            transformed=transformDeserializedData(records: AnyCollection(schools), transformations: transformers)
        }
    } catch {
        //Escape out the input file, schoolFile, was corrupt.
        os_log(.error, "%@", error as NSError)
        throw error
    }
    
    return transformed
}

/// Reads in the JSON file provided by NYC Open Data and drives the transformation routine that converts each field name to a local
/// name and field value from a string to the data type defined in the managed object model.
/// - Parameter satFile: JSON file provided by NYC Open Data
/// - Throws: An error if there is a problem with the mapping file or deserializing the JSON file
/// - Returns: A dictionary whose keys are the names of entities from the managed object mode and whos values
/// are arrays of dictionarys representing fields and values for each instance of that type found in a give input record. For
/// example, programs may have 10 instances per school
func importAndTransformSATResults(sats:String) throws -> [String:[[String:Any]]]{
    var transformed:[String:[[String:Any]]]!
    var transformers:[DataTransformer]!
    
    do {
        transformers=[
            try MappingTransformer(mappingFile: "SATResults", entityName: "SATResult")!
        ]
    } catch {
        throw CoreDataImportErrors.mappingFileError(err: error)
    }
    
    do {
        if let sats=try deserializeData(fileName: sats) {
            os_log(.debug, "Transforming SAT records")
            transformed=transformDeserializedData(records: AnyCollection(sats), transformations: transformers)
            os_log(.debug, "Transformed %d SAT records", sats.count)
        }
    } catch {
        //Escape out the input file, satFile, was corrupt.
        os_log(.error, "%@", error as NSError)
        throw error
    }
    
    return transformed
}


/// Loops though the dictionary of MO types and persists the array of records.
/// - Parameters:
///   - transformed: A dictionary of record after having been transformed from the NYC open data representation to the
///   local representation. Each key is the name of a type defined in the managed object mode and eacy value is an array of dictionarys
///   of field name/value pairs.
///   - ctx: The context handling the inserts. Normally this would come from the container created in the driver routine but you can
///   supply your own for testing etc.
/// - Throws: A error if either batch or per record insertion failed. This is an all or nothing (atomic) process - either all of the inserts
///   succeed or none do. Since this is not a user controlled process, if an error is raised the temp store should removed and the update
///   tried again once the issues have been resolved.
func persistTransformedData(transformed:[String:[[String:Any]]],ctx:NSManagedObjectContext) throws {
    try transformed.forEach {typeAndValues in
        do {
            try persistNewEntities(entityProperties: typeAndValues.value, entityName: typeAndValues.key, ctx: ctx)
        } catch {
            //All or thing here - either all the MO types succeed or none do
            os_log(.error,"%@",error as NSError)
            throw error
        }
    }
}



//MARK: - Batch Delete
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

//MARK: - Persisting New Entities
/// Writes the entities identified by entityName and defined in entityProperties to the store managed by the supplied managed object context.
/// - Parameters:
///   - entityProperties: An array of dictionaries where the key is a field and the value is the field value.
///   - entityName: Name of the core data type to persist
///   - ctx: The managed object context handling the persistence
///   - batchInsert: Whether or not batch processing should be used; set this to false for unit testing. Batch insert has only been
///   available since iOS 13 so older devices will be forced to insert objects the old fashioned way.
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

/// Writes each entity directly to the Core Data store. This happens as a series of SQL insert-into statements and thus only works
/// with SQLite stores. Since this more or less by passes Core Data none of the persisted entities exist in the context and will need
/// to be loaded seperately. If the write fails any changes on the undo stack are removed (rolled back).
/// - Parameters:
///   - entityProperties: An array of dictionaries where each key is a field name and the value is the value of the correct type
///   for that field.
///   - entityName: The name of the entity as defined in the managed object model
///   - ctx: The context handling the inserts.
/// - Throws: An error is thrown if the entity cannot be found in the managed object model or batch insert fails.
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

/// Instead of batch inserting this routing inserts each record in the provided array one at at thing using the context.
/// - Parameters:
///   - entityProperties: An array of dictionaries where each key is a field name and the value is the value of the correct type
///   for that field.
///   - entityName: The name of the entity as defined in the managed object model
///   - ctx: The context handling the inserts.
/// - Throws: An error is thrown if the entity cannot be found in the managed object model or batch insert fails.
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

//MARK: - Cleanup and Establishing Relationships
/// Establishes the various parent/child relationships after the bulk insert.
/// - Parameters:
///   - ctx: The managed object context
///   - parentType: The type of the parent as defined in the managed object model
///   - fetchPredicate: The predicate that fetches each set of children. Given a parent, this predicate should be able to retrive all of the parent's children.
///   - relHandlers: Each relationship belongs to a different field in the parent and may have a different cardinality (one-one,
///   one-many, etc.) this array of tuples allows for custom handlng per child. The first element in the tuple should be the class type of the child and the second
///   element should be a function that takes the parent and a set of [1..N] children and adds the children to the parent.
/// - Returns: An arry of children of type childType.
func establishParentChildRelations<P>(ctx:NSManagedObjectContext, parentType:P.Type, fetchPredicate:(P)->NSPredicate, relHandlers:[(NSManagedObject.Type,(P,NSSet)->())]) throws where P:NSManagedObject {
    let parentFR=NSFetchRequest<P>(entityName: "\(parentType)")
    
    /// Fetches all programs children of a certain type based on the child's dbn and program number values.
    /// - Parameters:
    ///   - prog: The parent program
    ///   - childType: The class type fo the child entity
    /// - Returns: An arry of children of type childType
    func fetchChildren<T>(parent:P, childType:T.Type) throws -> [T] where T:NSManagedObject {
        let fr=NSFetchRequest<T>(entityName: "\(childType)")
        fr.predicate=fetchPredicate(parent)
        
        return try ctx.fetch(fr)
    }

    do {
        try ctx.fetch(parentFR).forEach { parent in
            try relHandlers.forEach { handler in
                let children=try fetchChildren(parent:parent, childType:handler.0)
                guard !children.isEmpty else {return}
                
                handler.1(parent,NSSet(array: children))
            }
        }
        try ctx.save()
    } catch {
        os_log(.error, "%@", error as NSError)
        ctx.rollback()
        throw error
    }
}

/// Batch inserts do not allow for the creation of relationships, that is handled in this routine. For each program, the relationships between it
/// and the program's requirements and admissions priorities are established
/// - Parameter ctx: The managed object context to use. This should be the same context that has been used for the other import routines
func establishProgramRelationships(ctx:NSManagedObjectContext) throws {
    try establishParentChildRelations(
        ctx: ctx,
        parentType: Program.self,
        fetchPredicate: { (prog:Program) -> NSPredicate in
            NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "dbn=%@", prog.dbn!),
                NSPredicate(format: "programNo=%d", prog.programNumber)
            ])
        },
        relHandlers:[
            (ProgramAdmissionsPriority.self, {(p,c) in p.addToAdmissionPriority(c)}),
            (ProgramAdmissionReqs.self, {(p,c) in p.addToAdmissionReqs(c)})
        ])
    
    os_log(.debug,"Established program relationships")
}

/// Batch inserts do not allow for the creation of relationships, that is handled in this routine. For each school, the relationships between it
/// and the schools's address, SAT results, and programs are established
/// - Parameter ctx: The managed object context to use. This should be the same context that has been used for the other import routines
func establishSchoolRelationships(ctx:NSManagedObjectContext) throws {
    try establishParentChildRelations(
        ctx: ctx,
        parentType: HighSchool.self,
        fetchPredicate: { (school:HighSchool) -> NSPredicate in
            NSPredicate(format: "dbn=%@", school.dbn!)
        },
        relHandlers:[
            (Address.self, { (p,c) in if let a=c.allObjects.first as? Address {p.address=a} }),
            (SATResult.self, {(p,c) in if let s=c.allObjects.first as? SATResult {p.satResults=s} }),
            (Program.self, { (p,c) in p.addToPrograms(c) })
        ])
    
    os_log(.debug,"Established school relationships")
}

