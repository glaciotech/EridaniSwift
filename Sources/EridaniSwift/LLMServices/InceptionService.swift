//
//  OpenAIService.swift
//  VentusAI
//
//  Created by Peter Liddle on 4/16/24.
//

import Foundation
import OpenAIKit
import SwiftyPrompts
import SwiftyPrompts_Inception
import MCP

open class InceptionService: RemoteAIService {
    
    private let overridenApiKey: String?
    private let overridenBaseUrl: String?
    private let proxyAppAPIKey: String?
    
    private let sessionRefreshHandler: ProxySessionHandler?
    
    public static let InceptionAPIKeyStorageKey = "InceptionAPIKey"
    
    var apiKey: String? {
        return overridenApiKey ?? UserDefaults.standard.string(forKey: Self.InceptionAPIKeyStorageKey)
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
                return InceptionLLM(with: requestHandler, baseUrl: "https://not.used", apiKey: apiKey, model: model.id, systemPromptPrefix: model.configuration.modelSpecificPrompt ?? nil, temperature: temperature, topP: topP, tools: tools.map({ $0.toOpenAITool() }), storeResponses: storeResponses)
            }
            else {
                return InceptionLLM(apiKey: apiKey, model: model.id, systemPromptPrefix: model.configuration.modelSpecificPrompt ?? nil, temperature: temperature, topP: topP, tools: tools.map({ $0.toOpenAITool() }), storeResponses: storeResponses)
            }
        }()
        
        return llm
    }
}
