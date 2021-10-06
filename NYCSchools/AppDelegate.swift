//
//  AppDelegate.swift
//  JPMCPrototype
//
//  Created by Nathan Abbott on 10/1/21.
//

import UIKit
import CoreData
import os
import Dispatch

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    // MARK: UISceneSession Lifecycle
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    @available(iOS 13.0, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "NYCSchools")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                //FIXME: If the persistent container is loaded all core data ops will fail.
                os_log(.error, "%@", "Unresolved error \(error), \(error.userInfo)")
            } else {
                DispatchQueue.main.async {
                    do {
                        let count=try container.viewContext.count(for:NSFetchRequest<HighSchool>(entityName: "HighSchool"))
                        if 0==count {
                            self.clearAndReloadData()
                        }
                    } catch {
                        os_log(.error, "%@", "\(error)")
                    }                    
                }
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                //FIXME: This will fail silently potentially losing data
                os_log(.error, "%@", "Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    //MARK: - Data import routines
    func batchDelete(ctx:NSManagedObjectContext) {
        let entities=["HighSchool","SATResult","Address"]
        entities.forEach { entity in
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDeleteRequest.resultType = .resultTypeCount
            do {
                let result=try ctx.execute(batchDeleteRequest)
                if let rowsDeleted=(result as! NSBatchDeleteResult).result as? NSNumber {
                    print("\(rowsDeleted) \(entity) rows deleted")
                }
            } catch {
                os_log(.error, "%@", "\(error)")
            }
        }
    }
    
    func importData(fileAndHandler:[String:(HSDataImporter)->(Data,Bool) throws ->()], ctx:NSManagedObjectContext){
        fileAndHandler.forEach {
            guard let data=NSDataAsset(name: $0.key)?.data else {
                os_log(.debug, "%@", "Unable to load the hs data file")
                return
            }
            
            let importer=HSDataImporter(moc: ctx, includeChildEntities: true)
            do {
                try $0.value(importer)(data,true)
            } catch {
                os_log(.error, "%@", "\(error)")
            }
        }
    }
    
    
    @objc
    func mergeContextsAfterReload(sender:Notification){
        persistentContainer.viewContext.mergeChanges(fromContextDidSave: sender)
        NotificationCenter.default.removeObserver(self, name: .NSManagedObjectContextDidSave, object: sender.userInfo?["managedObjectContext"])
    }
    
    func clearAndReloadData(){
        let bgCtx=persistentContainer.newBackgroundContext()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(mergeContextsAfterReload(sender:)),
                                               name: .NSManagedObjectContextDidSave,
                                               object: bgCtx)
        bgCtx.performAndWait {
            self.batchDelete(ctx:bgCtx)
            self.importData(fileAndHandler:
                                [
                                    "2017DOEHighSchoolDirectory":HSDataImporter.importSchools,
                                    "2012SATResults":HSDataImporter.importSATResults
                                ],ctx:bgCtx)
            
            do {
                if bgCtx.hasChanges {
                    try bgCtx.save()
                }
            } catch {
                let nserror = error as NSError
                os_log(.error, "%@", "Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}

//func importSchools(ctx:NSManagedObjectContext){
//    guard let data=NSDataAsset(name: "2017DOEHighSchoolDirectory")?.data else {
//        os_log(.debug, "%@", "Unable to load the hs data file")
//        return
//    }
//
//    let importer=HSDataImporter(moc: ctx, includeChildEntities: true)
//    do {
//        try importer.importSchools(json: data)
//    } catch {
//        os_log(.error, "%@", "\(error)")
//    }
//}
//
//func importSATResults(ctx:NSManagedObjectContext){
//    guard let data=NSDataAsset(name: "2012SATResults")?.data else {
//        os_log(.debug, "%@", "Unable to load the sat results data file")
//        return
//    }
//    
//    let importer=HSDataImporter(moc: ctx, includeChildEntities: true)
//    do {
//        try importer.importSATResults(json: data)
//    } catch {
//        os_log(.error, "%@", "\(error)")
//    }
//}
