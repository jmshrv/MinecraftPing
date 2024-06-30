import Foundation

enum MinecraftConnectionError: Error {
    case connectionFailed(Error)
    case invalidResponse
    case noData
}

protocol MinecraftEncodable {
    var minecraftEncoded: Data { get }
}

protocol MinecraftDecodable {
    init(fromMinecraft data: Data) throws
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

extension String: MinecraftDecodable {
    init(fromMinecraft data: Data) throws {
        var dataCopy = data
        
//        Strings have a varint for their size that we don't care about
        let _ = try Int32(varInt: &dataCopy)
        
        self.init(decoding: dataCopy, as: UTF8.self)
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

struct MinecraftStatusResponse: MinecraftDecodable {
    let length: Int32
    let packetId: Int32
    let response: String
    
    init(fromMinecraft data: Data) throws {
        var dataCopy = data
        
        length = try .init(varInt: &dataCopy)
        packetId = try .init(varInt: &dataCopy)
        response = try .init(fromMinecraft: dataCopy)
    }
}

public struct MinecraftVersion: Decodable, Equatable {
    public let name: String
    public let protocolVersion: Int
    
    enum CodingKeys: String, CodingKey {
        case name
        case protocolVersion = "protocol"
    }
}

public struct MinecraftDescriptionDictionary: Decodable, Equatable {
    public let text: String
}

public enum MinecraftDescription: Decodable, Equatable {
    case text(String)
    case dictionary(MinecraftDescriptionDictionary)
    
    var actualText: String {
        return switch self {
        case .text(let text): text
        case .dictionary(let dictionary): dictionary.text
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else if let dictionary = try? container.decode(MinecraftDescriptionDictionary.self) {
            self = .dictionary(dictionary)
        } else {
            throw DecodingError.typeMismatch(MinecraftDescription.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid description type"))
        }
    }
}

public struct MinecraftPlayerSample: Decodable, Equatable, Identifiable {
    public let name: String
    public let id: UUID
}

public struct MinecraftPlayers: Decodable, Equatable {
    public let max: Int
    public let online: Int
    public let sample: [MinecraftPlayerSample]?
}

public struct MinecraftStatus: Decodable, Equatable {
    public let version: MinecraftVersion
    public let players: MinecraftPlayers?
    public let description: MinecraftDescription?
    
    public let favicon: String?
    public let enforcesSecureChat: Bool?
    public let previewsChat: Bool?
}

/// A connection to a Minecraft server. When initialised, the socket is created. Don't leave this object hanging around
/// for ages.
public struct MinecraftConnection {
    let hostname: String
    let port: UInt16
    
    public init(hostname: String, port: UInt16) {
        self.hostname = hostname
        self.port = port
    }
    
    
    /// Performs a [Server List Ping](https://wiki.vg/Server_List_Ping) with the server, returning the server status.
    /// Note that the socket connection will stay active after this call.
    /// - Returns: A `MinecraftStatus`
    /// - Throws: Errors related to `URLSessionStreamTask`, and any encoding errors
    public func ping() async throws -> MinecraftStatus {
        let connection = URLSession.shared.streamTask(withHostName: hostname, port: Int(port))
        connection.resume()
        
        let handshake = MinecraftPacket(data: MinecraftHandshake(serverAddress: hostname, serverPort: port))
        try await connection.write(handshake.minecraftEncoded, timeout: .zero)
        
        let statusRequest = MinecraftPacket(data: MinecraftStatusRequest())
        try await connection.write(statusRequest.minecraftEncoded, timeout: .zero)
        
        var response = Data()
        var responseSize: Int32? = nil
        var lengthLength = 0
        
        while response.count - lengthLength != (responseSize ?? .max) {
            let (newResponse, _) = try await connection.readData(ofMinLength: 0, maxLength: .max, timeout: .zero)
            
            guard let newResponse else {
                throw MinecraftConnectionError.noData
            }
            
            response.append(newResponse)
            
            if responseSize == nil {
                do {
                    var responseClone = response
                    responseSize = try .init(varInt: &responseClone)
                    lengthLength = response.count - responseClone.count
                } catch {}
            }
        }
        
        let decodedResponse = try MinecraftStatusResponse(fromMinecraft: response)
        
        guard let payloadData = decodedResponse.response.data(using: .utf8) else {
            throw MinecraftConnectionError.invalidResponse
        }
        
        return try JSONDecoder()
            .decode(MinecraftStatus.self, from: payloadData)
    }
}
