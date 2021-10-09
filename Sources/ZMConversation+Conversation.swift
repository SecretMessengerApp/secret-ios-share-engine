//
//


import Foundation
import WireDataModel
import WireRequestStrategy


extension ZMConversation: Conversation {

    @objc public var name: String { return displayName }
        
    public func appendTextMessage(_ message: String, fetchLinkPreview: Bool) -> Sendable? {
        return append(text: message, fetchLinkPreview: fetchLinkPreview) as? Sendable
    }
    
    public func appendImage(_ data: Data) -> Sendable? {
        return append(imageFromData: data) as? Sendable
    }
    
    public func appendFile(_ metadata: ZMFileMetadata) -> Sendable? {
        return append(file: metadata) as? Sendable
    }
    
    public func appendLocation(_ location: LocationData) -> Sendable? {
        return append(location: location) as? Sendable
    }
    
    /// Adds an observer for when the conversation verification status degrades
    public func add(conversationVerificationDegradedObserver: @escaping (ConversationDegradationInfo)->()) -> TearDownCapable {
        return DegradationObserver(conversation: self, callback: conversationVerificationDegradedObserver)
    }
}

public struct ConversationDegradationInfo {
    
    public let conversation : Conversation
    public let users : Set<ZMUser>
    
    public init(conversation: Conversation, users: Set<ZMUser>) {
        self.users = users
        self.conversation = conversation
    }
}

class DegradationObserver : NSObject, ZMConversationObserver, TearDownCapable {
    
    let callback : (ConversationDegradationInfo)->()
    let conversation : ZMConversation
    private var observer : Any? = nil
    
    init(conversation: ZMConversation, callback: @escaping (ConversationDegradationInfo)->()) {
        self.callback = callback
        self.conversation = conversation
        super.init()
        self.observer = NotificationCenter.default.addObserver(forName: contextWasMergedNotification, object: nil, queue: nil) { [weak self] _ in
                                                DispatchQueue.main.async {
                                                    self?.processSaveNotification()
                                                }
        }
    }
    
    deinit {
        tearDown()
    }
    
    func tearDown() {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }
    
    private func processSaveNotification() {
        if !self.conversation.messagesThatCausedSecurityLevelDegradation.isEmpty {
            let untrustedUsers = self.conversation.activeParticipants.filter {
                $0.clients.first { !$0.verified } != nil
            }
            
            self.callback(ConversationDegradationInfo(conversation: self.conversation,
                                                      users: untrustedUsers)
            )
        }
    }
    
    func conversationDidChange(_ note: ConversationChangeInfo) {
        if note.causedByConversationPrivacyChange {
            self.callback(ConversationDegradationInfo(conversation: note.conversation,
                                                      users: Set(note.usersThatCausedConversationToDegrade)))
        }
    }
}
