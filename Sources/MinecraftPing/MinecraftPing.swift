import Foundation

enum MinecraftConnectionError: Error {
    case connectionFailed(Error)
    case invalidResponse
}

protocol MinecraftEncodable {
    var minecraftEncoded: Data { get }
}

extension String: MinecraftEncodable {
    var minecraftEncoded: Data {
        var out = Data()
        
        let stringBytes = self.utf8
        
        out.append(Int32(stringBytes.count).varInt)
        out.append(Data(stringBytes))
        
        return out
    }
}

protocol MinecraftPacketContent: MinecraftEncodable {
    var packetId: Int32 { get }
}

struct MinecraftPacket<T: MinecraftPacketContent>: MinecraftEncodable {
    var minecraftEncoded: Data {
        var out = Data()
        
        out.append(length.varInt)
        out.append(data.minecraftEncoded)
        
        return out
    }
    
    var length: Int32 {
        Int32(data.minecraftEncoded.count)
    }
    
    let data: T
}

struct MinecraftHandshake: MinecraftPacketContent {
    var minecraftEncoded: Data {
        var out = Data()
        
        out.append(packetId.varInt)
        out.append(protocolVersion.varInt)
        out.append(serverAddress.minecraftEncoded)
        
        withUnsafeBytes(of: serverPort.bigEndian) { buffer in
            out.append(contentsOf: buffer)
        }
        
        out.append(nextState.varInt)
        
        return out
    }
    
    var packetId: Int32 = 0x00
    let protocolVersion: Int32 = -1
    
    let serverAddress: String
    let serverPort: UInt16
    
    let nextState: Int32 = 1
}

struct MinecraftStatusRequest: MinecraftPacketContent {
    var minecraftEncoded: Data {
        packetId.varInt
    }
    
    var packetId: Int32 = 0x00
}


/// A connection to a Minecraft server
public struct MinecraftConnection {
    let connection: URLSessionStreamTask
    
    let hostname: String
    let port: UInt16
    
    public init(hostname: String, port: UInt16) {
        self.hostname = hostname
        self.port = port
        
        connection = URLSession.shared.streamTask(withHostName: hostname, port: Int(port))
        connection.resume()
    }
    
    public func ping() async throws {
        let handshake = MinecraftPacket(data: MinecraftHandshake(serverAddress: hostname, serverPort: port))
        try await connection.write(handshake.minecraftEncoded, timeout: .zero)
        
        let statusRequest = MinecraftPacket(data: MinecraftStatusRequest())
        try await connection.write(statusRequest.minecraftEncoded, timeout: .zero)
        
        let response = try await connection.readData(ofMinLength: 0, maxLength: .max, timeout: .zero)
        
        print(response.0?.base64EncodedString() ?? "None")
    }
}
