//
//  LLMChainManager.swift
//  Ventus
//
//  Created by Peter Liddle on 1/26/24.
//

import Foundation
import SwiftyPrompts

public enum RemoteLLMServiceError: Error, CustomStringConvertible, CustomDebugStringConvertible {

    case noAPIKey(_ model: String)
    case unknownModel(_ model: String)
    case invalidRemoteModel(_ modelName: String)
    
    public var description: String {
        switch self {
        case let .noAPIKey(model): "No API key has been provided for model: \(model)"
        case let .unknownModel(model): "The model: \(model) is unknown and not registered with Ventus, try updating"
        case let .invalidRemoteModel(model): "The model: \(model) is not a valid remote model"
        }
    }
    
    public var debugDescription: String {
        description
    }
}

public class RemoteAIProviders {
    
    let openAIService: OpenAIService
    let anthropicService: AnthropicService
    let xAIService: XAiService
    let inceptionService: InceptionService
    
    public init(openAIService: OpenAIService = OpenAIService(),
                anthropicService: AnthropicService = AnthropicService(),
                xAIService:XAiService = XAiService(),
                inceptionService: InceptionService = InceptionService()
    ) {
        self.openAIService = openAIService
        self.anthropicService = anthropicService
        self.xAIService = xAIService
        self.inceptionService = inceptionService
    }
    
    public func areApiKeysSetup(forModel model: RemoteLLMModel) throws(RemoteLLMServiceError) -> Bool {
        
        switch model.provider {
        case .openAI:
            return !(openAIService.apiKey?.isEmpty ?? true)
        case .anthropic:
            return !(anthropicService.apiKey?.isEmpty ?? true)
        case .xAI:
            return !(xAIService.apiKey?.isEmpty ?? true)
        case .inception:
            return !(inceptionService.apiKey?.isEmpty ?? true)
#if DEBUG
        case .testModel:
            return true
#endif
        }
    }
    
    public func resolveAIService(for model: RemoteLLMModel) throws -> RemoteAIService {
        switch model.provider {
        case .openAI: return openAIService
        case .anthropic: return anthropicService
        case .xAI: return xAIService
        case .inception: return inceptionService
        case .testModel:
            Log.error("Invalid model \(model) when invoking infer for \(Self.self) ")
            throw RemoteLLMServiceError.invalidRemoteModel(model.fullModelID)
        }
    }
}

public typealias RemoteLLMServiceContainer = RemoteAIProviders
