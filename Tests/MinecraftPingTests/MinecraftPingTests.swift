import XCTest
@testable import MinecraftPing

final class MinecraftPingTests: XCTestCase {
    func testPing() async throws {
        let connection = MinecraftConnection(hostname: "localhost", port: 25565)
        
        try await connection.ping()
    }
}
