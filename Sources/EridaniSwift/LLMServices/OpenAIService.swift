//
//  OpenAIService.swift
//  VentusAI
//
//  Created by Peter Liddle on 4/16/24.
//

import Foundation
import OpenAIKit
import SwiftyPrompts
import SwiftyPrompts_OpenAI
import MCP

extension RemoteLLMModel: ModelID { } // Already has a field called id, just make it adhere to OpenAIs ModelID

extension MCP.Tool {
    func toOpenAITool() -> OpenAIKit.Tool {
        .init(type: .function, name: self.name, description: self.description ?? "", parameters: .init(with: self.inputSchema))
    }
}

// Have the API errors map through message so it displays meaningful error
extension OpenAIKit.APIError: LocalizedError {
    public var errorDescription: String? {
        return self.message
    }
}

extension APIErrorResponse: LocalizedError {
    public var errorDescription: String? {
        return self.error.message
    }
}

open class OpenAIService: RemoteAIService {

    private let overridenApiKey: String?
    private let overridenBaseUrl: String?
    private let proxyAppAPIKey: String?
    
    private let sessionRefreshHandler: ProxySessionHandler?
    
    public static let OpenAIAPIKeyStorageKey = "OpenAIAPIKey"
    
    var apiKey: String? {
        return overridenApiKey ?? UserDefaults.standard.string(forKey: Self.OpenAIAPIKeyStorageKey)
    }
    
    var storeResponses = false
    
    public init(apiKey: String? = nil) {
        self.overridenApiKey = apiKey
        self.overridenBaseUrl = nil
        self.proxyAppAPIKey = nil
        self.sessionRefreshHandler = nil
    }
    
    public init(baseUrl: String, apiKey: String? = nil, proxyAppAPIKey: String?, sessionRefreshHandler: ProxySessionHandler) {
        self.overridenBaseUrl = baseUrl
        self.overridenApiKey = apiKey
        self.proxyAppAPIKey = proxyAppAPIKey
        self.sessionRefreshHandler = sessionRefreshHandler
    }
    
    public func createServiceLLM(model: RemoteLLMModel, temperature: Double = 1.0, topP: Double = 0.2, tools: [MCP.Tool]) async throws -> LLM {
        
        guard let apiKey = self.apiKey else {
            throw RemoteLLMServiceError.noAPIKey(model.id)
        }
        
        let llm = {
            if let baseUrlString = overridenBaseUrl, let baseUrl = URL(string: baseUrlString), let apiKey = overridenApiKey, let proxyAppAPIKey = proxyAppAPIKey {
                let requestHandler = OpenAIProxiedRequestHandler(
                    proxyDetails: .init(proxyUrl: baseUrl, appAPIKey: proxyAppAPIKey),
                    sessionRefreshHandler: sessionRefreshHandler!)
                return OpenAILLM(with: requestHandler, baseUrl: "https://not.used", apiKey: apiKey, model: model, systemPromptPrefix: model.configuration.modelSpecificPrompt ?? nil, temperature: temperature, topP: topP, tools: tools.map({ $0.toOpenAITool() }), storeResponses: storeResponses)
            }
            else {
                return OpenAILLM(apiKey: apiKey, model: model, systemPromptPrefix: model.configuration.modelSpecificPrompt ?? nil, temperature: temperature, topP: topP, tools: tools.map({ $0.toOpenAITool() }), storeResponses: storeResponses)
            }
        }()
        
        return llm
    }
}
