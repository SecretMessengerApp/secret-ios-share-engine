//
//

import Foundation
import XCTest
import WireTesting
import WireDataModel
import WireRequestStrategy
@testable import WireShareEngine

class OperationLoopTests :  ZMTBaseTest {

    var uiMoc   : NSManagedObjectContext! = nil
    var syncMoc : NSManagedObjectContext! = nil
    var sut : OperationLoop! = nil
    
    override func setUp() {
        super.setUp()
        let accountId = UUID()
        let directoryURL = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        
        StorageStack.shared.createStorageAsInMemory = true
        StorageStack.shared.createManagedObjectContextDirectory(accountIdentifier: accountId, applicationContainer: directoryURL, dispatchGroup: self.dispatchGroup) {
            self.uiMoc = $0.uiContext
            self.syncMoc = $0.syncContext
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        sut = OperationLoop(userContext: uiMoc, syncContext: syncMoc, callBackQueue: OperationQueue())
    }
    
    override func tearDown() {
        
        sut = nil
        
        resetState()
    
        uiMoc = nil
        syncMoc = nil
        
        super.tearDown()
    }
    
    func resetState() {
        StorageStack.reset()
    }
}


extension OperationLoopTests {
    
    func testThatItMergesUiContextInSyncContext() {
        
        let userID = UUID()
        
        var syncUser : ZMUser! = nil
        syncMoc.performGroupedBlock { [unowned self] in
            syncUser = ZMUser(remoteID: userID, createIfNeeded: true, in: self.syncMoc)!
            self.syncMoc.saveOrRollback()
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        XCTAssertNotNil(syncUser)
        XCTAssertNil(syncUser.name)
        
        uiMoc.performGroupedBlock {
            let uiUser = ZMUser(remoteID: userID, createIfNeeded: false, in: self.uiMoc)!
            uiUser.name = "Jean Claude YouKnowWho"
            XCTAssertNotNil(uiUser)
            self.uiMoc.saveOrRollback()
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        XCTAssertEqual(syncUser.name, "Jean Claude YouKnowWho")
    }
    
    func testThatItMergesSyncContextInUIContext() {
        let userID = UUID()
        
        var syncUser : ZMUser! = nil
        syncMoc.performGroupedBlock { [unowned self] in
            syncUser = ZMUser(remoteID: userID, createIfNeeded: true, in: self.syncMoc)!
            self.syncMoc.saveOrRollback()
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        XCTAssertNotNil(syncUser)
        XCTAssertNil(syncUser.name)
        
        var uiUser : ZMUser! = nil
        uiMoc.performGroupedBlock {
            uiUser = ZMUser(remoteID: userID, createIfNeeded: false, in: self.uiMoc)!
            XCTAssertNotNil(uiUser)
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        syncMoc.performGroupedBlockAndWait {
            syncUser.name = "Jean Claude YouKnowWho"
            self.syncMoc.saveOrRollback()
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        XCTAssertEqual(uiUser.name, syncUser.name)
    }
    
    func testThatItGeneratesTheExpectedRequest() {
        var count = 0
        sut.requestAvailableClosure = {
            count += 1
        }
        XCTAssertEqual(count, 0)
        
        sut.newRequestsAvailable()
        XCTAssertEqual(count, 1)
        
        sut.newRequestsAvailable()
        XCTAssertEqual(count, 2)
    }
}



