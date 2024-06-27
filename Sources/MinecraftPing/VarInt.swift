//
//  VarInt.swift
//  
//
//  Created by James on 27/06/2024.
//

import Foundation

fileprivate let SEGMENT_BITS: UInt32 = 0x7F
fileprivate let CONTINUE_BIT: UInt32 = 0x80

enum VarIntError: Error {
    case unexpectedEnd
    case varIntTooBig
}

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
    
    init(varInt: Data) throws {
        var varIntCopy = varInt
        var value: UInt32 = 0
        var position: UInt32 = 0
        
        while true {
            guard let currentByte = varIntCopy.popFirst() else {
                throw VarIntError.unexpectedEnd
            }
            
            value |= (UInt32(currentByte) & SEGMENT_BITS) << position
            
            if UInt32(currentByte) & CONTINUE_BIT == 0 {
                break
            }
            
            position += 7
            
            if position >= 32 {
                throw VarIntError.varIntTooBig
            }
        }
        
        self.init(bitPattern: value)
    }
}
