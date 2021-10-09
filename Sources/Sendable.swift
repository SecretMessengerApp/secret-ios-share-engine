//
//

import Foundation
import WireDataModel

/// A object that can be sent, in progress, or failed, optionally tracking the sending progress
public protocol Sendable {
    
    /// The state of the delivery
    var isSent: Bool { get }

    /// Whether the sendable is currently blocked because of missing clients
    var blockedBecauseOfMissingClients : Bool { get }
    
    /// The progress of the delivery, from 0 to 1.
    /// It will be nil if the progress can not be tracked.
    /// It will be 1 when the delivery is completed.
    var deliveryProgress : Float? { get }
    
    /// Expire message sending
    func cancel()
}
