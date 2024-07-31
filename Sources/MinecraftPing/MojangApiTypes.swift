//
//  MojangApiTypes.swift
//
//
//  Created by James on 01/08/2024.
//

import Foundation

struct MinecraftProfile: Codable, Identifiable {
    let id: String
    let name: String
    let legacy: Bool?
    let properties: [MinecraftProfileProperties]
}

enum MinecraftProfilePropertiesError: Error {
    case base64DecodeFailed
}

struct MinecraftProfileProperties: Codable {
    let name: String
    let signature: String?
    let value: String
    
    public func texture() throws -> MinecraftProfileTextureMetadata {
        guard let textureJson = Data(base64Encoded: value) else {
            throw MinecraftProfilePropertiesError.base64DecodeFailed
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        
        return try decoder.decode(MinecraftProfileTextureMetadata.self, from: textureJson)
    }
}

struct MinecraftProfileTextureMetadata: Codable {
    let timestamp: Date
    let profileId: String
    let profileName: String
    let signatureRequired: Bool?
    let textures: PlayerSkin
}

struct PlayerSkin: Codable {
    let skin: PlayerTexture?
    let cape: PlayerTexture?
    
    enum CodingKeys: String, CodingKey {
        case skin = "SKIN"
        case cape = "CAPE"
    }
}

struct PlayerTexture: Codable {
    let url: URL
}
