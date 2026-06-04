//
//  AskLLMError.swift
//  VentusAI
//
//  Created by Peter Liddle on 8/15/25.
//

import Foundation

public enum AskLLMError: Error, LocalizedError {
    case noModelSelected
    case noReply
    case notAValidRemoteModel(any AnyLLMModel)
    case notAValidLocalModel(any AnyLLMModel)
    case noLoadedConversation
    case noAPIKeyForModelProvider(String?)
    
    public var errorDescription: String? {
        switch self {
        case .noModelSelected: "No model was selected"
        case .noReply: "No reply was received"
        case .notAValidLocalModel(let model): "\(model.name) is not a valid local model"
        case .notAValidRemoteModel(let model): "\(model.name) is not a valid remote model"
        case .noLoadedConversation: "No conversation is loaded to perform ask against"
        case let .noAPIKeyForModelProvider(provider): "No API key. Go to settings and add an \(provider ?? "unknown") API key"
        }
    }
}
