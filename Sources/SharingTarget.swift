//
//

import Foundation
import WireDataModel

/// A target of sharing content
public protocol SharingTarget {
    
    /// Appends a text message in the conversation
    func appendTextMessage(_ message: String, fetchLinkPreview: Bool) -> Sendable?
    
    /// Appends an image in the conversation
    func appendImage(_ data: Data) -> Sendable?
    
    /// Appends a file in the conversation
    func appendFile(_ metaData: ZMFileMetadata) -> Sendable?
    
    /// Append a location in the conversation
    func appendLocation(_ location: LocationData) -> Sendable?
}
