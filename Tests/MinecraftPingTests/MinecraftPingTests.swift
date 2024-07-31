import XCTest
@testable import MinecraftPing

final class MinecraftPingTests: XCTestCase {
    func testPing() async throws {
//        let expected = MinecraftStatus(
//            version: .init(name: "Paper 1.20.6", protocolVersion: 166),
//            players: .init(max: 20, online: 0, sample: nil),
//            description: "A Minecraft Server",
//            favicon: nil,
//            enforcesSecureChat: true,
//            previewsChat: nil
//        )
        
        let connection = MinecraftConnection(hostname: "localhost", port: 25565)
        
        try await connection.ping()
    }
    
    func testSkin() async throws {
        let testPlayer = MinecraftPlayerSample(name: "UnicornsOnLSD", id: .init(uuidString: "ff01fa15-7b46-4368-a193-75892222201e")!)
        
        let result = try await testPlayer.skin()
        
        XCTAssertNotNil(result)
    }
}
