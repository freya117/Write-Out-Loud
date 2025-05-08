//
//  WriteOutLoudUITests.swift
//  WriteOutLoudUITests
//
//  Created by Freya on 4/22/25.
//

import XCTest

final class WriteOutLoudUITests: XCTestCase {

    override func setUpWithError() throws {
        // Set up code for UI tests
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Clean up after UI tests
    }

    @MainActor
    func testCharacterSelection() throws {
        // Test that character selection interface works properly
        let app = XCUIApplication()
        app.launch()
        
        // Verify character selection area is present
        XCTAssert(app.staticTexts["Characters Selection"].exists)
        
        // TODO: Implement selection of a character and verification that it loads
    }

    @MainActor
    func testDrawingInterface() throws {
        // Test that the drawing interface is accessible
        let app = XCUIApplication()
        app.launch()
        
        // Verify the main components of the writing interface
        XCTAssert(app.staticTexts["Vocalize your stroke while writing:"].exists)
        
        // TODO: Implement verification of canvas and stroke info components
    }
    
    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch the application
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
