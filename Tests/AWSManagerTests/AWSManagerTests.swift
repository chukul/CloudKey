import XCTest
@testable import AWSManager

@MainActor
final class AWSManagerTests: XCTestCase {
    func testSessionCreation() {
        let session = Session(
            alias: "Test Session",
            profileName: "test-profile",
            region: "us-east-1",
            accountId: "123456789012",
            status: .inactive,
            type: .iamUser
        )
        
        XCTAssertEqual(session.alias, "Test Session")
        XCTAssertEqual(session.status, .inactive)
    }
    
    func testStoreAddSession() {
        let store = SessionStore()
        let initialCount = store.sessions.count
        
        let newSession = Session(
            alias: "New Session",
            profileName: "new-profile",
            region: "us-west-2",
            accountId: "000000000000",
            status: .active,
            type: .sso
        )
        
        store.addSession(newSession)
        
        XCTAssertEqual(store.sessions.count, initialCount + 1)
        XCTAssertEqual(store.sessions.last?.alias, "New Session")
    }
}
