import Foundation

#if canImport(SwiftUI)
import SwiftUI
#endif

enum MinecraftConnectionError: Error {
    case connectionFailed(Error)
    case invalidResponse
    case noData
}

enum FaviconError: Error {
    case failedToDecode
    case imageInitializationFailed
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

#if canImport(SwiftUI)
@Observable
#endif
public class MinecraftVersion: Decodable {
    public let name: String
    public let protocolVersion: Int
    
    public init(name: String, protocolVersion: Int) {
        self.name = name
        self.protocolVersion = protocolVersion
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case protocolVersion = "protocol"
    }
}

#if canImport(SwiftUI)
@Observable
#endif
public class MinecraftDescriptionDictionary: Decodable {
    public let text: String
    
    public init(text: String) {
        self.text = text
    }
}

public enum MinecraftDescription: Decodable {
    case text(String)
    case dictionary(MinecraftDescriptionDictionary)
    
    public var actualText: String {
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

#if canImport(SwiftUI)
@Observable
#endif
public class MinecraftPlayerSample: Decodable, Identifiable {
    public let name: String
    public let id: UUID
    
    public init(name: String, id: UUID) {
        self.name = name
        self.id = id
    }
    
    public func skin() async throws -> Data? {
        let url = URL(string: "https://sessionserver.mojang.com/session/minecraft/profile/\(id)")!
        
        let (profileData, _) = try await URLSession.shared.data(from: url)
        
        let profile = try JSONDecoder().decode(MinecraftProfile.self, from: profileData)
        
        guard let texture = try profile.properties.first?.texture() else {
            return nil
        }
        
        guard let skin = texture.textures.skin else {
            return nil
        }
        
        let (skinData, _) = try await URLSession.shared.data(from: skin.url)
        
        return skinData
    }
}

#if canImport(SwiftUI)
@Observable
#endif
public class MinecraftPlayers: Decodable {
    public let max: Int
    public let online: Int
    public let sample: [MinecraftPlayerSample]?
    
    public init(max: Int, online: Int, sample: [MinecraftPlayerSample]?) {
        self.max = max
        self.online = online
        self.sample = sample
    }
    
    public func skins() async throws -> [(MinecraftPlayerSample, Data?)]? {
        guard let sample else {
            return nil
        }
        
        return try await withThrowingTaskGroup(of: (MinecraftPlayerSample, Data?).self) { group -> [(MinecraftPlayerSample, Data?)] in
            for player in sample {
                group.addTask {
                    let skin = try await player.skin()
                    return (player, skin)
                }
            }
            
            var collected: [(MinecraftPlayerSample, Data?)] = []
            
            for try await result in group {
                collected.append(result)
            }
            
            return collected.sorted(by: { $0.0.name.localizedStandardCompare($1.0.name) == .orderedAscending } )
        }
    }
}

#if canImport(SwiftUI)
@Observable
#endif
public class MinecraftStatus: Decodable {
    public let version: MinecraftVersion
    public let players: MinecraftPlayers?
    public let description: MinecraftDescription?
    
    public var favicon: String?
    public let enforcesSecureChat: Bool?
    public let previewsChat: Bool?
    
    public required init(version: MinecraftVersion, players: MinecraftPlayers?, description: MinecraftDescription?, favicon: String? = nil, enforcesSecureChat: Bool?, previewsChat: Bool?) {
        self.version = version
        self.players = players
        self.description = description
        self.favicon = favicon
        self.enforcesSecureChat = enforcesSecureChat
        self.previewsChat = previewsChat
    }
    
    public static var mock: Self {
        .init(
            version: .init(name: "1.20.6", protocolVersion: 1000),
            players: .init(max: 100, online: 5, sample: [
                .init(name: "PopBob", id: .init()),
                .init(name: "UnicornsOnLSD", id: .init()),
                .init(name: "Jeb_", id: .init())
            ]),
            description: .text("A Minecraft Server"),
            favicon: nil,
            enforcesSecureChat: true,
            previewsChat: false
        )
    }
    
    public var faviconOrPack: String {
        favicon ?? "data:image/png;base64,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"
    }
    
    #if canImport(SwiftUI)
    public var faviconOrPackImage: Image {
        get throws {
            let trimmedFavicon = faviconOrPack.trimmingPrefix("data:image/png;base64,")
            
            guard let faviconData = Data(base64Encoded: Data(trimmedFavicon.utf8)) else {
                throw FaviconError.failedToDecode
            }
            
            #if os(iOS)
            
            guard let image = UIImage(data: faviconData) else {
                throw FaviconError.imageInitializationFailed
            }
            
            return Image(uiImage: image)
            
            #else
            
            guard let image = NSImage(data: faviconData) else {
                throw FaviconError.imageInitializationFailed
            }
            
            return Image(nsImage: image)
            
            #endif
        }
    }
    #endif
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
