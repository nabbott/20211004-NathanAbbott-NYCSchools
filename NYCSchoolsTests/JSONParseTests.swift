//
//  JSONParseTests.swift
//  JPMCPrototypeTests
//
//  Created by Nathan Abbott on 10/2/21.
//

import XCTest
import CoreData
@testable import NYCSchools


class JSONParseTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testStringToString(){
        let newline = """
foo
 bar
"""
        let whitespace=" foo bar  "
        let good="foo bar"
        
        XCTAssertEqual("foo bar", stringToString(newline)!)
        XCTAssertEqual("foo bar", stringToString(whitespace)!)
        XCTAssertEqual("foo bar", stringToString(good)!)
    }
    
    func testStringToBool(){
        let falseN="N"
        let falseNo="no"
        let false0="0"
        let falseNil:String? = nil
        XCTAssertFalse(stringToBool(falseN))
        XCTAssertFalse(stringToBool(falseNo))
        XCTAssertFalse(stringToBool(false0))
        XCTAssertFalse(stringToBool(falseNil))
        
        let trueAny1=""
        let trueAny2="ahe"
        
        XCTAssertTrue(stringToBool(trueAny1))
        XCTAssertTrue(stringToBool(trueAny2))
    }
    
    func testStringToFloat(){
        XCTAssertEqual(0.0, stringToFloat(nil))
        XCTAssertEqual(0.0, stringToFloat(""))
        XCTAssertEqual(0.0, stringToFloat("foo"))
        
        XCTAssertEqual(-73.9252, stringToFloat("-73.9252"))
        XCTAssertEqual(0.958000004, stringToFloat("0.958000004"))
    }
    
    func testStringToDouble(){
        XCTAssertEqual(0.0, stringToDouble(nil))
        XCTAssertEqual(0.0, stringToDouble(""))
        XCTAssertEqual(0.0, stringToDouble("foo"))
        
        XCTAssertEqual(-73.9252, stringToDouble("-73.9252"))
        XCTAssertEqual(0.958000004, stringToDouble("0.958000004"))
    }
    
    func testStringToInt(){
        XCTAssertEqual(0, stringToInt(nil))
        XCTAssertEqual(0, stringToInt(""))
        XCTAssertEqual(0, stringToInt("foo"))
        
        XCTAssertEqual(828, stringToInt("828"))
    }
}
