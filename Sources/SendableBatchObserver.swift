//
//

import Foundation

public final class SendableBatchObserver {
    
    public let sendables: [Sendable]
    
    public var sentHandler: (() -> Void)?
    public var progressHandler: ((Float) -> Void)?
    private var observerToken : Any?
    
    public init(sendables: [Sendable]) {
        self.sendables = sendables
        self.observerToken = NotificationCenter.default.addObserver(forName: contextWasMergedNotification,
                                                                    object: nil,
                                                                    queue: nil) { [weak self] _ in
            DispatchQueue.main.async {
                self?.onDeliveryChanged()
            }
        }
    }
    
    deinit {
        if let observer = self.observerToken {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    public var allSendablesSent: Bool {
        return !sendables.contains { !$0.isSent }
    }
    
    public func onDeliveryChanged() {
        if allSendablesSent {
            DispatchQueue.main.async { [weak self] in
                self?.sentHandler?()
            }
        }
        
        updateProgress()
    }
    
    private func updateProgress() {
        var totalProgress: Float = 0
        
        sendables.forEach { message in
            if message.isSent {
                totalProgress = totalProgress + 1.0 / Float(sendables.count)
            } else {
                let messageProgress = (message.deliveryProgress ?? 0)
                totalProgress = totalProgress +  messageProgress / Float(sendables.count)
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.progressHandler?(totalProgress)
        }
    }
    
}
