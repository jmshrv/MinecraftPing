//
//  VarInt.swift
//  
//
//  Created by James on 27/06/2024.
//

import Foundation

fileprivate let SEGMENT_BITS: UInt32 = 0x7F
fileprivate let CONTINUE_BIT: UInt32 = 0x80

extension Int32 {
    var varInt: Data {
        var value = UInt32(bitPattern: self)
        var output = Data()
        
        while true {
            if value & ~SEGMENT_BITS == 0 {
                output.append(UInt8(value))
                return output
            }
            
            output.append(UInt8(value & SEGMENT_BITS | CONTINUE_BIT))
            
            value >>= 7
        }
    }
}
