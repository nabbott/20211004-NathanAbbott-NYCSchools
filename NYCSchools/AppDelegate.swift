//
//  AppDelegate.swift
//  JPMCPrototype
//
//  Created by Nathan Abbott on 10/1/21.
//

import os
import UIKit
import CoreData
import Dispatch
import Foundation

func logInstalledFonts(){
    print("********** BEGIN FONT LOGGING ****************************************************")
    UIFont.familyNames.forEach { family in
        UIFont.fontNames(forFamilyName: family).forEach { font in
            print("Family: \(family), font: \(font)")
        }
    }
    print("********** END FONT LOGGING ******************************************************")
}

fileprivate typealias DataAsset=(school:String,sat:String)
fileprivate let standardDataAssets:DataAsset=("2017DOEHighSchoolDirectory","2012SATResults")
fileprivate let UITestingDataAssets:DataAsset=("UIUnitTestSchoolFile","UIUnitTestSATFile")

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
                container.performBackgroundTask { ctx in
                    do {
                        let count=try ctx.count(for:NSFetchRequest<HighSchool>(entityName: "HighSchool"))
                        #if DEBUG
                        let isUITest = "true"==ProcessInfo.processInfo.environment["UITest"]
                        os_log(.debug,"Loading UI test db: $@", "\(isUITest)")
                        #else
                        let isUITest=false
                        #endif
                        
                        if 0==count || isUITest {
                            os_log(.debug,"Database is empty, loading in data from default files.")
//                            self.clearAndReloadData()
                        }
                    } catch {
                        os_log(.error, "%@", "\(error)")
                    }
                }
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent=true
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
    func clearAndReloadData(){
        guard !self.isLoadingSchools else {return}
        
        self.isLoadingSchools=true
        var assets=standardDataAssets
        #if DEBUG
        if "true"==ProcessInfo.processInfo.environment["UITest"] {
            assets=UITestingDataAssets
        }
        #endif
        
        let psc=self.persistentContainer.persistentStoreCoordinator
        DispatchQueue.global(qos: .background).async {
            os_log(.debug,"Starting the update routine")
            do {
                let tmpContainer=try importSchoolAndSATResults(schoolFile:assets.school, satFile:assets.sat)
                guard let tmpCoordinator=tmpContainer?.persistentStoreCoordinator else {return}
                guard let tmpStore=tmpCoordinator.persistentStores.first else {return}
                
                let newURL=tmpStore.url!
                //Depending on write ahead logging to protect from suddenly overwriting the working store
                try updateExistingStoreWithNewStore(storeCoordinator: psc, oldURL: psc.persistentStores.first!.url!, newURL: newURL)
                try removeTemporaryStore(tmpContainer: tmpContainer!)
                DispatchQueue.main.async {
                    self.persistentContainer.loadPersistentStores(completionHandler: { desc, err in
                        if let e=err {
                            os_log(.error,"%@",e as NSError)
                        } else {
                            os_log(.debug,"Reloaded stores")
                            self.persistentContainer.viewContext.reset()
                            self.isLoadingSchools=false
                            os_log(.debug,"Completed the update routine")
                            NotificationCenter.default.post(Notification(name: Notification.Name("DataUploadComplete"), object: self.persistentContainer))
                        }
                    })
                }
            } catch {
                os_log(.error, "%@",error as NSError)
            }
        }
    }
}
