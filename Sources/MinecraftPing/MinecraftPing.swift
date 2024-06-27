import Foundation

enum MinecraftConnectionError: Error {
    case connectionFailed(Error)
    case invalidResponse
}

protocol MinecraftPacketContent {
    var packetId: Int32 { get }
}

struct MinecraftPacket<T: MinecraftPacketContent> {
    var length: Int32
    let data: T
}


/// A connection to a Minecraft server
public struct MinecraftConnection {
    let connection: URLSessionStreamTask
    
    public init(hostname: String, port: Int) {
        connection = URLSession.shared.streamTask(withHostName: hostname, port: port)
        connection.resume()
    }
    
    public func ping() async throws {
        
    }
}
