//
//  AnthropicService.swift
//  VentusAI
//
//  Created by Peter Liddle on 4/16/24.
//

import Foundation
import SwiftAnthropic
import SwiftyPrompts
import SwiftyPrompts_xAI
import MCP

open class XAiService: RemoteAIService {

    private let overridenApiKey: String?
    private let overridenBaseUrl: String?
    private let proxyAppAPIKey: String?
    
    public static let xAIAPIKeyStorageKey = "xaiAPIKey"
    
    private let sessionRefreshHandler: ProxySessionHandler?
    
    var apiKey: String? {
        return overridenApiKey ?? UserDefaults.standard.string(forKey: Self.xAIAPIKeyStorageKey)
    }
    
    public init(baseUrl: String? = nil, apiKey: String? = nil, proxyAppAPIKey: String? = nil, sessionRefreshHandler: ProxySessionHandler? = nil) {
        self.overridenBaseUrl = baseUrl
        self.overridenApiKey = apiKey
        self.sessionRefreshHandler = sessionRefreshHandler
        self.proxyAppAPIKey = proxyAppAPIKey
    }

    public func createServiceLLM(model: RemoteLLMModel, temperature: Double, topP: Double) async throws -> any SwiftyPrompts.LLM {
        try await self.createServiceLLM(model: model, temperature: temperature, topP: topP, tools: [])
    }
    
    public func createServiceLLM(model: RemoteLLMModel, temperature: Double, topP: Double, tools: [MCP.Tool] = []) async throws -> any SwiftyPrompts.LLM {
        
        guard let apiKey = self.apiKey else {
            throw RemoteLLMServiceError.noAPIKey(model.fullModelID)
        }
        
        let xAiLLM = try {
            if let baseUrlString = overridenBaseUrl, let baseUrl = URL(string: baseUrlString),
                let apiKey = overridenApiKey, let proxyAppAPIKey = proxyAppAPIKey {
                let httpClient = try AnthropicProxiedHTTPClientAdapter(
                    proxyDetails: .init(proxyUrl: baseUrl, appAPIKey: proxyAppAPIKey),
                    sessionRefreshHandler: sessionRefreshHandler!)
                return xAILLM(httpClient: httpClient, apiKey: apiKey, model: try model.id, temperature: temperature, tools: tools.compactMap({ try? $0.toAnthropicTool() }))
            }
            else if let baseUrl = overridenBaseUrl, let apiKey = overridenApiKey {
                return xAILLM(baseUrl: baseUrl, apiKey: apiKey, model: try model.id, temperature: temperature, tools: tools.compactMap({ try? $0.toAnthropicTool() }))
            } else {
                return xAILLM(apiKey: apiKey, model: try model.id, temperature: temperature, tools: tools.compactMap({ try? $0.toAnthropicTool() }))
            }
        }()
        
        return xAiLLM
    }
}
