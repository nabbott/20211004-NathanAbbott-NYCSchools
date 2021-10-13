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

func logInstalledFonts(){
    print("********** BEGIN FONT LOGGING ****************************************************")
    UIFont.familyNames.forEach { family in
        UIFont.fontNames(forFamilyName: family).forEach { font in
            print("Family: \(family), font: \(font)")
        }
    }
    print("********** END FONT LOGGING ******************************************************")
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var isLoadingSchools=false
    
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        #if DEBUG
        if CommandLine.arguments.contains("-showFonts"){
            DispatchQueue.global(qos: .utility).async {
                logInstalledFonts()
            }
        }
        #endif
        
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
                //Allow the system to schedule this call, hopefully after the ui has completed rendering
                DispatchQueue.main.async {
                    do {
                        let count=try container.viewContext.count(for:NSFetchRequest<HighSchool>(entityName: "HighSchool"))
                        if 0==count {
                            os_log(.debug,"Database is empty, loading in data from default files.")
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
    @objc
    func mergeContextsAfterReload(sender:Notification){
        persistentContainer.viewContext.mergeChanges(fromContextDidSave: sender)
        NotificationCenter.default.removeObserver(self, name: .NSManagedObjectContextDidSave, object: sender.userInfo?["managedObjectContext"])
    }
    
    //FIXME: This should only be run once, at first app load when the db is empty. However there is a chance, when running,
    //in debug mode that the user will trigger an additional load before the default load has completed.
    func clearAndReloadData(){
        let bgCtx=persistentContainer.newBackgroundContext()
        //Note: The context did save notification is only sent because the updating
        //of relationships occurs through the context instead of directly via the SQLite store.
        //If the bg context doesn't have at least one save the notification won't fire and the
        //main context won't see the changes and neither will the user.
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(mergeContextsAfterReload(sender:)),
                                               name: .NSManagedObjectContextDidSave,
                                               object: bgCtx)
        
        self.isLoadingSchools=true
        DispatchQueue.global(qos: .background).async {
            bgCtx.performAndWait {
                do {
                    //FIXME: Maybe wrap the delete and import routines in a transaction.
                    let importer=HSDataImporter(batchProcess: true)
                    
                    try importer.deleteAllHSData(ctx: bgCtx, batch: true)
                    
                    guard let schools=NSDataAsset(name: "2017DOEHighSchoolDirectory")?.data else {
                        os_log(.debug, "%@", "Unable to load the hs data file")
                        return
                    }
                    
                    guard let satResults=NSDataAsset(name: "2012SATResults")?.data else {
                        os_log(.debug, "%@", "Unable to load the sat results data file")
                        return
                    }
                    
                    try importer.importAllDataAndEstablishRelationships(
                        highSchools: schools,
                        satResults: satResults,
                        ctx: bgCtx)
                    
                    if bgCtx.hasChanges {
                        try bgCtx.save()
                    }
                } catch {
                    os_log(.error,"%@",error as NSError)
                }
                
                self.isLoadingSchools=false
            }
        }
    }
}
