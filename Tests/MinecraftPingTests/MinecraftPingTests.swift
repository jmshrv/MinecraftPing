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
        
        let result = try await connection.ping()
        print(result)
    }
}
