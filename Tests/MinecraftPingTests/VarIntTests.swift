//
//  VarIntTests.swift
//  
//
//  Created by James on 27/06/2024.
//

import XCTest
@testable import MinecraftPing

final class VarIntTests: XCTestCase {
//    Test cases from https://wiki.vg/Protocol#Type:VarInt
    let cases: [Int32: Data] = [
        0:           .init([0x00]),
        1:           .init([0x01]),
        2:           .init([0x02]),
        127:         .init([0x7f]),
        128:         .init([0x80, 0x01]),
        255:         .init([0xff, 0x01]),
        25565:       .init([0xdd, 0xc7, 0x01]),
        2097151:     .init([0xff, 0xff, 0x7f]),
        2147483647:  .init([0xff, 0xff, 0xff, 0xff, 0x07]),
        -1:          .init([0xff, 0xff, 0xff, 0xff, 0x0f]),
        -2147483648: .init([0x80, 0x80, 0x80, 0x80, 0x08])
    ]
    
    func testIntToVarInt() throws {
        for testCase in cases {
            XCTAssertEqual(testCase.key.varInt, testCase.value)
        }
    }
    
    func testFromVarInt() throws {
        for testCase in cases {
            let output = try Int32(varInt: testCase.value)
            XCTAssertEqual(output, testCase.key)
        }
    }
}
