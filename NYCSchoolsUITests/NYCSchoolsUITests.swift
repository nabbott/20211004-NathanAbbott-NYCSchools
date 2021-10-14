//
//  NYCSchoolsUITests.swift
//  NYCSchoolsUITests
//
//  Created by Nathan Abbott on 10/13/21.
//

import XCTest

class NYCSchoolsUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCountSchools() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launchArguments=["-com.apple.CoreData.SQLDebug 1"]
        app.launchEnvironment["UITest"]="true"
        
        app.launch()
        if !app.wait(for: .runningForeground, timeout: 10){
            XCTFail("App was not able to reach the run state soon enough")
        }

        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        let tablesQuery = app.tables
        let schoolCellPredicate:NSPredicate=NSPredicate(format: "%K=%@", argumentArray: ["reuseIdentifer","HSName"])
        let schoolCells=tablesQuery.cells.containing(schoolCellPredicate)
        
        XCTAssertTrue(schoolCells.count==5)

        tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["East Side Community School"]/*[[".cells.staticTexts[\"East Side Community School\"]",".staticTexts[\"East Side Community School\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        app.navigationBars["High School"].buttons["Schools"].tap()
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
