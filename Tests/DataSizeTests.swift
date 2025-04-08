//
//  DataSizeTests.swift
//  Swifter
//
//  Created by Tomasz on 08/04/2025.
//
import XCTest
import Swifter

class DataSizeTests: XCTestCase {
    
    func test_initFromDouble() {
        XCTAssertEqual(DataSize(578), .B(578))
        XCTAssertEqual(DataSize(999), .B(999))
        XCTAssertEqual(DataSize(1_001), .KB(1.001))
        XCTAssertEqual(DataSize(56_000), .KB(56))
        XCTAssertEqual(DataSize(73_000_000), .MB(73))
        XCTAssertEqual(DataSize(21_000_000_000), .GB(21))
    }
    
    func test_count() {
        XCTAssertEqual(DataSize.B(578).count, 578)
        XCTAssertEqual(DataSize.KB(243).count, 243_000)
        XCTAssertEqual(DataSize.MB(540).count, 540_000_000)
        XCTAssertEqual(DataSize.GB(163).count, 163_000_000_000)
    }

    func test_stringConvertible() {
        XCTAssertEqual(DataSize.B(578).description, "578 B")
        XCTAssertEqual(DataSize.KB(243).description, "243 KB")
        XCTAssertEqual(DataSize.MB(540).description, "540 MB")
        XCTAssertEqual(DataSize.MB(540.721).description, "540.72 MB")
        XCTAssertEqual(DataSize.GB(163).description, "163 GB")
        XCTAssertEqual(DataSize.GB(163.879).description, "163.88 GB")
    }

    func test_comparable() {
        XCTAssertTrue(DataSize.B(23) < DataSize.B(27))
        XCTAssertTrue(DataSize.B(23) < DataSize.MB(12))
        XCTAssertTrue(DataSize.MB(23) < DataSize.GB(4))
        
        XCTAssertFalse(DataSize.TB(8) < DataSize.GB(4))
    }
}
