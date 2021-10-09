//
//


import Foundation
import WireDataModel



private extension ZMMessage {

    var reportsProgress: Bool {
        return fileMessageData != nil || imageMessageData != nil
    }

}

extension ZMMessage: Sendable {

    public var blockedBecauseOfMissingClients : Bool {
        guard let message = self as? ZMOTRMessage else {
            return false
        }
        return self.deliveryState == .failedToSend && message.causedSecurityLevelDegradation
    }

    public var isSent: Bool {
        if let clientMessage = self as? ZMClientMessage {
            if clientMessage.linkPreviewState != .done {
                return false
            }
        }
        
        return delivered
    }
    
    public var deliveryProgress: Float? {
        if let asset = self as? ZMAssetClientMessage, reportsProgress {
            return asset.progress
        }
        
        return nil
    }
        
    public func cancel() {
        
        if let asset = self.fileMessageData {
            asset.cancelTransfer()
            return
        }
        self.expire()
    }
    
}
