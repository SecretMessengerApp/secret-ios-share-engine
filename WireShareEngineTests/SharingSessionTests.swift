
import XCTest
import WireDataModel
import WireTesting

class SharingSessionTests: BaseSharingSessionTests {
    
    func createConversation(type: ZMConversationType, archived: Bool) -> ZMConversation {
        let conversation = ZMConversation.insertNewObject(in: moc)
        conversation.conversationType = type
        conversation.isArchived = archived
        return conversation
    }
    
    var activeConversation1: ZMConversation!
    var activeConversation2: ZMConversation!
    var activeConnection: ZMConversation!
    var archivedConversation: ZMConversation!
    var archivedConnection: ZMConversation!

    override func setUp() {
        super.setUp()
        activeConversation1 = createConversation(type: .group, archived: false)
        activeConversation2 = createConversation(type: .group, archived: false)
        activeConnection = createConversation(type: .connection, archived: false)
        archivedConversation = createConversation(type: .group, archived: true)
        archivedConnection = createConversation(type: .connection, archived: true)
    }
    
    override func tearDown() {
        activeConversation1 = nil
        activeConversation2 = nil
        activeConnection = nil
        archivedConversation = nil
        archivedConnection = nil
        super.tearDown()
    }

    func testThatWriteableNonArchivedConversationsAreReturned() {
        let conversations = Set(sharingSession.writeableNonArchivedConversations.map { $0 as! ZMConversation })
        XCTAssertEqual(conversations, Set(arrayLiteral: activeConversation1, activeConversation2))
    }

    func testThatWritebleArchivedConversationsAreReturned() {
        let conversations = sharingSession.writebleArchivedConversations.map { $0 as! ZMConversation }
        XCTAssertEqual(conversations, [archivedConversation])
    }
}
