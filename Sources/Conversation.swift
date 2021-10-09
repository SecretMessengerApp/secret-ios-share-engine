//
//

import Foundation
import WireDataModel
import WireRequestStrategy

/// A conversation
public protocol Conversation : SharingTarget {
    
    /// User defined name for a group conversation, or standard name
    var name : String { get }
    
    /// Type of the conversation
    var conversationType : ZMConversationType { get }
    
    /// Returns true if the conversation is trusted (all participants are trusted)
    var securityLevel : ZMConversationSecurityLevel { get }

    /// The status of legal hold in the conversation.
    var legalHoldStatus: ZMConversationLegalHoldStatus { get }

    /// Adds an observer for when the conversation verification status degrades
    func add(conversationVerificationDegradedObserver: @escaping (ConversationDegradationInfo)->()) -> TearDownCapable
    
    /// Accept the privacy warning, and resend the messages that caused them if wanted.
    func acknowledgePrivacyWarning(withResendIntent shouldResendMessages: Bool)

}
