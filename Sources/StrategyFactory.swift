//
//


import Foundation
import WireRequestStrategy
import WireTransport.ZMRequestCancellation
import WireLinkPreview

class StrategyFactory {

    unowned let syncContext: NSManagedObjectContext
    let applicationStatus: ApplicationStatus
    let linkPreviewPreprocessor: LinkPreviewPreprocessor
    private(set) var strategies = [AnyObject]()

    private var tornDown = false

    init(syncContext: NSManagedObjectContext, applicationStatus: ApplicationStatus, linkPreviewPreprocessor: LinkPreviewPreprocessor) {
        self.linkPreviewPreprocessor = linkPreviewPreprocessor
        self.syncContext = syncContext
        self.applicationStatus = applicationStatus
        self.strategies = createStrategies(linkPreviewPreprocessor: linkPreviewPreprocessor)
    }

    deinit {
        precondition(tornDown, "Need to call `tearDown` before `deinit`")
    }

    func tearDown() {
        strategies.forEach {
            if $0.responds(to: #selector(ZMObjectSyncStrategy.tearDown)) {
                ($0 as? ZMObjectSyncStrategy)?.tearDown()
            }
        }
        tornDown = true
    }

    private func createStrategies(linkPreviewPreprocessor: LinkPreviewPreprocessor) -> [AnyObject] {
        return [
            // Clients
            createMissingClientsStrategy(),
            createFetchingClientsStrategy(),
            createVerifyLegalHoldStrategy(),
            
            // Client Messages
            createClientMessageTranscoder(),

            // Link Previews
            createLinkPreviewAssetUploadRequestStrategy(linkPreviewPreprocessor: linkPreviewPreprocessor),
            createLinkPreviewUploadRequestStrategy(),

            // Assets V3
            createAssetClientMessageRequestStrategy(),
            createAssetV3UploadRequestStrategy()
        ]
    }
    
    private func createVerifyLegalHoldStrategy() -> VerifyLegalHoldRequestStrategy {
        return VerifyLegalHoldRequestStrategy(withManagedObjectContext: syncContext, applicationStatus: applicationStatus)
    }
    
    private func createFetchingClientsStrategy() -> FetchingClientRequestStrategy {
        return FetchingClientRequestStrategy(withManagedObjectContext: syncContext, applicationStatus: applicationStatus)
    }

    private func createMissingClientsStrategy() -> MissingClientsRequestStrategy {
        return MissingClientsRequestStrategy(withManagedObjectContext: syncContext, applicationStatus: applicationStatus)
    }

    private func createClientMessageTranscoder() -> ClientMessageTranscoder {
        return ClientMessageTranscoder(
            in: syncContext,
            localNotificationDispatcher: PushMessageHandlerDummy(),
            applicationStatus: applicationStatus
        )
    }

    // MARK: – Link Previews

    private func createLinkPreviewAssetUploadRequestStrategy(linkPreviewPreprocessor: LinkPreviewPreprocessor) -> LinkPreviewAssetUploadRequestStrategy {
        
        return LinkPreviewAssetUploadRequestStrategy(
            managedObjectContext: syncContext,
            applicationStatus: applicationStatus,
            linkPreviewPreprocessor: linkPreviewPreprocessor,
            previewImagePreprocessor: nil
        )
    }

    private func createLinkPreviewUploadRequestStrategy() -> LinkPreviewUploadRequestStrategy {
        return LinkPreviewUploadRequestStrategy(withManagedObjectContext: syncContext, applicationStatus: applicationStatus)
    }

    // MARK: - Asset V3

    private func createAssetV3UploadRequestStrategy() -> AssetV3UploadRequestStrategy {
         return AssetV3UploadRequestStrategy(withManagedObjectContext: syncContext, applicationStatus: applicationStatus)
    }

    private func createAssetClientMessageRequestStrategy() -> AssetClientMessageRequestStrategy {
        return AssetClientMessageRequestStrategy(withManagedObjectContext: syncContext, applicationStatus: applicationStatus)
    }
}
