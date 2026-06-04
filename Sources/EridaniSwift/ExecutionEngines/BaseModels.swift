//
//  BaseModels.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 11/23/25.
//

public struct MessageMetadata {
    public var tokensUsedForMessage: Int = 0
  
    public init(tokensUsedForMessage: Int) {
        self.tokensUsedForMessage = tokensUsedForMessage
    }
}

public enum Author: Int {
    case user = 0
    case ai
    case tool
    case system
}

public struct Message {
    public var content: [LLMInputContent]
    public var author: Author
    public var metadata: MessageMetadata?
    
    public init(content: [LLMInputContent], author: Author, metadata: MessageMetadata? = nil) {
        self.content = content
        self.author = author
        self.metadata = metadata
    }
}
