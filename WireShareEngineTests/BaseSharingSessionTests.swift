//
//


import XCTest
import WireDataModel
import WireMockTransport
import WireTesting
import WireRequestStrategy
import WireLinkPreview
@testable import WireShareEngine

class FakeAuthenticationStatus: AuthenticationStatusProvider {
    var state: AuthenticationState = .authenticated
}

class BaseSharingSessionTests: ZMTBaseTest {

    var moc: NSManagedObjectContext!
    var sharingSession: SharingSession!
    var authenticationStatus: FakeAuthenticationStatus!

    override func setUp() {
        super.setUp()

        authenticationStatus = FakeAuthenticationStatus()
        let url = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

        var directory: ManagedObjectContextDirectory!
        StorageStack.shared.createStorageAsInMemory = true
        StorageStack.shared.createManagedObjectContextDirectory(accountIdentifier: UUID.create(), applicationContainer: url) {
            directory = $0
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        let mockTransport = MockTransportSession(dispatchGroup: ZMSDispatchGroup(label: "ZMSharingSession"))
        let transportSession = mockTransport.mockedTransportSession()

        let saveNotificationPersistence = ContextDidSaveNotificationPersistence(accountContainer: url)
        let analyticsEventPersistence = ShareExtensionAnalyticsPersistence(accountContainer: url)

        let requestGeneratorStore = RequestGeneratorStore(strategies: [])
        let registrationStatus = ClientRegistrationStatus(context: directory.syncContext)
        let linkPreviewDetector = LinkPreviewDetector()
        let operationLoop = RequestGeneratingOperationLoop(
            userContext: directory.uiContext,
            syncContext: directory.syncContext,
            callBackQueue: .main,
            requestGeneratorStore: requestGeneratorStore,
            transportSession: transportSession
        )
        let applicationStatusDirectory = ApplicationStatusDirectory(
            transportSession: transportSession,
            authenticationStatus: authenticationStatus,
            clientRegistrationStatus: registrationStatus,
            linkPreviewDetector: linkPreviewDetector
        )

        let strategyFactory = StrategyFactory(
            syncContext: directory.syncContext,
            applicationStatus: applicationStatusDirectory,
            linkPreviewPreprocessor: LinkPreviewPreprocessor(linkPreviewDetector: linkPreviewDetector, managedObjectContext: directory.syncContext)
        )

        sharingSession = try! SharingSession(
            contextDirectory: directory,
            transportSession: transportSession,
            cachesDirectory: url,
            saveNotificationPersistence: saveNotificationPersistence,
            analyticsEventPersistence: analyticsEventPersistence,
            applicationStatusDirectory: applicationStatusDirectory,
            operationLoop: operationLoop,
            strategyFactory: strategyFactory
        )

        moc = sharingSession.userInterfaceContext
    }

    override func tearDown() {
        sharingSession = nil
        authenticationStatus = nil
        moc = nil
        StorageStack.reset()
        super.tearDown()
    }

}
