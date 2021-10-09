//
//


import Foundation
import WireDataModel
import WireTransport
import WireRequestStrategy
import WireLinkPreview

class PushMessageHandlerDummy : NSObject, PushMessageHandler {

    func process(_ message: ZMMessage) {
        // nop
    }

    func process(_ genericMessage: ZMGenericMessage) {
        // nop
    }

    func didFailToSend(_ message: ZMMessage) {
        // nop
    }
    
}

class DeliveryConfirmationDummy : NSObject, DeliveryConfirmationDelegate {
    
    static var sendDeliveryReceipts: Bool {
        return false
    }
    
    var needsToSyncMessages: Bool {
        return false
    }
    
    func needsToConfirmMessage(_ messageNonce: UUID) {
        // nop
    }
    
    func didConfirmMessage(_ messageNonce: UUID) {
        // nop
    }
    
}

class ClientRegistrationStatus : NSObject, ClientRegistrationDelegate {
    
    let context : NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    var clientIsReadyForRequests: Bool {
        if let clientId = context.persistentStoreMetadata(forKey: "PersistedClientId") as? String { // TODO move constant into shared framework
            return !clientId.isEmpty
        }
        
        return false
    }
    
    func didDetectCurrentClientDeletion() {
        // nop
    }
}

class AuthenticationStatus : AuthenticationStatusProvider {
    
    let transportSession : ZMTransportSession
    
    init(transportSession: ZMTransportSession) {
        self.transportSession = transportSession
    }
    
    var state: AuthenticationState {
        return isLoggedIn ? .authenticated : .unauthenticated
    }
    
    private var isLoggedIn : Bool {
        return transportSession.cookieStorage.authenticationCookieData != nil
    }
    
}

extension BackendEnvironmentProvider {
    func cookieStorage(for account: Account) -> ZMPersistentCookieStorage {
        let backendURL = self.backendURL.host!
        return ZMPersistentCookieStorage(forServerName: backendURL, userIdentifier: account.userIdentifier)
    }
    
    public func isAuthenticated(_ account: Account) -> Bool {
        return cookieStorage(for: account).authenticationCookieData != nil
    }
}

class ApplicationStatusDirectory : ApplicationStatus {

    let transportSession : ZMTransportSession
    let deliveryConfirmationDummy : DeliveryConfirmationDummy
    
    /// The authentication status used to verify a user is authenticated
    public let authenticationStatus: AuthenticationStatusProvider
    
    /// The client registration status used to lookup if a user has registered a self client
    public let clientRegistrationStatus : ClientRegistrationDelegate

    public let linkPreviewDetector: LinkPreviewDetectorType
    
    public init(transportSession: ZMTransportSession, authenticationStatus: AuthenticationStatusProvider , clientRegistrationStatus: ClientRegistrationStatus, linkPreviewDetector: LinkPreviewDetectorType) {
        self.transportSession = transportSession
        self.authenticationStatus = authenticationStatus
        self.clientRegistrationStatus = clientRegistrationStatus
        self.deliveryConfirmationDummy = DeliveryConfirmationDummy()
        self.linkPreviewDetector = linkPreviewDetector
    }
    
    public convenience init(syncContext: NSManagedObjectContext, transportSession: ZMTransportSession) {
        let authenticationStatus = AuthenticationStatus(transportSession: transportSession)
        let clientRegistrationStatus = ClientRegistrationStatus(context: syncContext)
        let linkPreviewDetector = LinkPreviewDetector()
        self.init(transportSession: transportSession, authenticationStatus: authenticationStatus, clientRegistrationStatus: clientRegistrationStatus, linkPreviewDetector: linkPreviewDetector)
    }
    
    public var synchronizationState: SynchronizationState {
        if clientRegistrationStatus.clientIsReadyForRequests {
            return .eventProcessing
        } else {
            return .unauthenticated
        }
    }
    
    public var operationState: OperationState {
        return .foreground
    }

    public let notificationFetchStatus: BackgroundNotificationFetchStatus = .done
    
    public let notificationHugeFetchStatus:
        BackgroundNotificationFetchStatus = .done
    
    public var clientRegistrationDelegate: ClientRegistrationDelegate {
        return self.clientRegistrationStatus
    }
    
    public var requestCancellation: ZMRequestCancellation {
        return transportSession
    }
    
    public var deliveryConfirmation: DeliveryConfirmationDelegate {
        return deliveryConfirmationDummy
    }
    
    func requestSlowSync() {
        // we don't do slow syncing in the share engine
    }
    
}


/// A Wire session to share content from a share extension
/// - note: this is the entry point of this framework. Users of 
/// the framework should create an instance as soon as possible in
/// the lifetime of the extension, and hold on to that session
/// for the entire lifetime.
/// - warning: creating multiple sessions in the same process
/// is not supported and will result in undefined behaviour
public class SharingSession {
    
    /// The failure reason of a `SharingSession` initialization
    /// - NeedsMigration: The database needs a migration which is only done in the main app
    /// - LoggedOut: No user is logged in
    /// - missingSharedContainer: The shared container is missing
    public enum InitializationError: Error {
        case needsMigration, loggedOut, missingSharedContainer
    }
    
    /// The `NSManagedObjectContext` used to retrieve the conversations
    var userInterfaceContext: NSManagedObjectContext {
        return contextDirectory.uiContext
    }

    private var syncContext: NSManagedObjectContext {
        return contextDirectory.syncContext
    }

    /// Directory of all application statuses
    private let applicationStatusDirectory : ApplicationStatusDirectory

    /// The list to which save notifications of the UI moc are appended and persistet
    private let saveNotificationPersistence: ContextDidSaveNotificationPersistence

    public let analyticsEventPersistence: ShareExtensionAnalyticsPersistence

    private var contextSaveObserverToken: NSObjectProtocol?

    let transportSession: ZMTransportSession
    
    private var contextDirectory: ManagedObjectContextDirectory!
    
    /// The `ZMConversationListDirectory` containing all conversation lists
    private var directory: ZMConversationListDirectory {
        return userInterfaceContext.conversationListDirectory()
    }
    
    /// Whether all prerequsisties for sharing are met
    public var canShare: Bool {
        return applicationStatusDirectory.authenticationStatus.state == .authenticated && applicationStatusDirectory.clientRegistrationStatus.clientIsReadyForRequests
    }

    /// List of non-archived conversations in which the user can write
    /// The list will be sorted by relevance
    public var writeableNonArchivedConversations : [Conversation] {
        return directory.unarchivedConversations.writeableConversations
    }
    
    /// List of archived conversations in which the user can write
    public var writebleArchivedConversations : [Conversation] {
        return []
    }
    
    ///外部分享时获取conversation
    public var sharedConversation : [Conversation] {
        return userInterfaceContext.sharedConversationList()
    }
    
    ///外部分享时根据关键字搜索conversation
    public func searchSharedConversation(with text: String) -> [Conversation] {
        return userInterfaceContext.filterSharedConversationList(withSearchText: text)
    }

    private let operationLoop: RequestGeneratingOperationLoop

    private let strategyFactory: StrategyFactory
        
    /// Initializes a new `SessionDirectory` to be used in an extension environment
    /// - parameter databaseDirectory: The `NSURL` of the shared group container
    /// - throws: `InitializationError.NeedsMigration` in case the local store needs to be
    /// migrated, which is currently only supported in the main application or `InitializationError.LoggedOut` if
    /// no user is currently logged in.
    /// - returns: The initialized session object if no error is thrown
    
    public convenience init(applicationGroupIdentifier: String, accountIdentifier: UUID, hostBundleIdentifier: String, environment: BackendEnvironmentProvider) throws {
        let sharedContainerURL = FileManager.sharedContainerDirectory(for: applicationGroupIdentifier)
        guard !StorageStack.shared.needsToRelocateOrMigrateLocalStack(accountIdentifier: accountIdentifier, applicationContainer: sharedContainerURL) else { throw InitializationError.needsMigration }
        
        let group = DispatchGroup()
        
        var directory: ManagedObjectContextDirectory!
        group.enter()
        StorageStack.shared.createManagedObjectContextDirectory(
            accountIdentifier: accountIdentifier,
            applicationContainer: sharedContainerURL,
            startedMigrationCallback: {  },
            completionHandler: { contextDirectory in
                directory = contextDirectory
                group.leave()
            }
        )
        
        var didCreateStorageStack = false
        group.notify(queue: .global()) { 
            didCreateStorageStack = true
        }
        
        while !didCreateStorageStack {
            if !RunLoop.current.run(mode: RunLoop.Mode.default, before: Date(timeIntervalSinceNow: 0.002)) {
                Thread.sleep(forTimeInterval: 0.002)
            }
        }
        
        let cookieStorage = ZMPersistentCookieStorage(forServerName: environment.backendURL.host!, userIdentifier: accountIdentifier)
        let reachabilityGroup = ZMSDispatchGroup(dispatchGroup: DispatchGroup(), label: "Sharing session reachability")!
        let serverNames = [environment.backendURL, environment.backendWSURL].compactMap { $0.host }
        let reachability = ZMReachability(serverNames: serverNames, group: reachabilityGroup)
        
        let transportSession =  ZMTransportSession(
            environment: environment,
            cookieStorage: cookieStorage,
            reachability: reachability,
            initialAccessToken: ZMAccessToken(),
            applicationGroupIdentifier: applicationGroupIdentifier
        )
        
        try self.init(
            contextDirectory: directory,
            transportSession: transportSession,
            cachesDirectory: FileManager.default.cachesURLForAccount(with: accountIdentifier, in: sharedContainerURL),
            accountContainer: StorageStack.accountFolder(accountIdentifier: accountIdentifier, applicationContainer: sharedContainerURL)
        )
    }
    
    internal init(contextDirectory: ManagedObjectContextDirectory,
                  transportSession: ZMTransportSession,
                  cachesDirectory: URL,
                  saveNotificationPersistence: ContextDidSaveNotificationPersistence,
                  analyticsEventPersistence: ShareExtensionAnalyticsPersistence,
                  applicationStatusDirectory: ApplicationStatusDirectory,
                  operationLoop: RequestGeneratingOperationLoop,
                  strategyFactory: StrategyFactory
        ) throws {
        
        self.contextDirectory = contextDirectory
        self.transportSession = transportSession
        self.saveNotificationPersistence = saveNotificationPersistence
        self.analyticsEventPersistence = analyticsEventPersistence
        self.applicationStatusDirectory = applicationStatusDirectory
        self.operationLoop = operationLoop
        self.strategyFactory = strategyFactory
        
        guard applicationStatusDirectory.authenticationStatus.state == .authenticated else { throw InitializationError.loggedOut }
        
        setupCaches(at: cachesDirectory)
        setupObservers()
    }
    
    public convenience init(contextDirectory: ManagedObjectContextDirectory, transportSession: ZMTransportSession, cachesDirectory: URL, accountContainer: URL) throws {
        
        let applicationStatusDirectory = ApplicationStatusDirectory(syncContext: contextDirectory.syncContext, transportSession: transportSession)
        let linkPreviewPreprocessor = LinkPreviewPreprocessor(linkPreviewDetector: applicationStatusDirectory.linkPreviewDetector, managedObjectContext: contextDirectory.syncContext)
        
        let strategyFactory = StrategyFactory(
            syncContext: contextDirectory.syncContext,
            applicationStatus: applicationStatusDirectory,
            linkPreviewPreprocessor: linkPreviewPreprocessor
        )

        let requestGeneratorStore = RequestGeneratorStore(strategies: strategyFactory.strategies)

        let operationLoop = RequestGeneratingOperationLoop(
            userContext: contextDirectory.uiContext,
            syncContext: contextDirectory.syncContext,
            callBackQueue: .main,
            requestGeneratorStore: requestGeneratorStore,
            transportSession: transportSession
        )
        
        let saveNotificationPersistence = ContextDidSaveNotificationPersistence(accountContainer: accountContainer)
        let analyticsEventPersistence = ShareExtensionAnalyticsPersistence(accountContainer: accountContainer)
        
        try self.init(
            contextDirectory: contextDirectory,
            transportSession: transportSession,
            cachesDirectory: cachesDirectory,
            saveNotificationPersistence: saveNotificationPersistence,
            analyticsEventPersistence: analyticsEventPersistence,
            applicationStatusDirectory: applicationStatusDirectory,
            operationLoop: operationLoop,
            strategyFactory: strategyFactory
        )
    }

    deinit {
        if let token = contextSaveObserverToken {
            NotificationCenter.default.removeObserver(token)
            contextSaveObserverToken = nil
        }
        transportSession.reachability.tearDown()
        transportSession.tearDown()
        strategyFactory.tearDown()
    }
    
    private func setupCaches(at cachesDirectory: URL) {
        
        let userImageCache = UserImageLocalCache(location: cachesDirectory)
        userInterfaceContext.zm_userImageCache = userImageCache
        syncContext.zm_userImageCache = userImageCache
        
        let fileAssetcache = FileAssetCache(location: cachesDirectory)
        userInterfaceContext.zm_fileAssetCache = fileAssetcache
        syncContext.zm_fileAssetCache = fileAssetcache
    }

    private func setupObservers() {
        contextSaveObserverToken = NotificationCenter.default.addObserver(
            forName: contextWasMergedNotification,
            object: nil,
            queue: .main,
            using: { [weak self] note in
                self?.saveNotificationPersistence.add(note)
                DarwinNotification.shareExtDidSaveNote.post()
            }
        )
    }

    public func enqueue(changes: @escaping () -> Void) {
        enqueue(changes: changes, completionHandler: nil)
    }
    
    public func enqueue(changes: @escaping () -> Void, completionHandler: (() -> Void)?) {
        userInterfaceContext.performGroupedBlock { [weak self] in
            changes()
            self?.userInterfaceContext.saveOrRollback()
            completionHandler?()
        }
    }

}

extension SharingSession: LinkPreviewDetectorType {

    public func downloadLinkPreviews(inText text: String, excluding: [NSRange], completion: @escaping ([LinkMetadata]) -> Void) {
        applicationStatusDirectory.linkPreviewDetector.downloadLinkPreviews(inText: text, excluding: excluding, completion: completion)
    }

}

// MARK: - Helper

fileprivate extension ZMConversationList {
    
    var writeableConversations: [Conversation] {
        return self.filter {
            if let conversation = $0 as? ZMConversation {
                return !conversation.isReadOnly
            }
            return false
        }.compactMap { $0 as? Conversation }
    }

}
