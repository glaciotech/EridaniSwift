//
//  AnthropicService.swift
//  VentusAI
//
//  Created by Peter Liddle on 4/16/24.
//

import Foundation
import SwiftAnthropic
import SwiftyPrompts
import SwiftyPrompts_Anthropic
import MCP
import SwiftyJsonSchema

extension SwiftAnthropic.JSONSchema {
    public init(withMCPValue schema: MCPValue) throws {
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let encodedJson = try encoder.encode(schema)
        self = try decoder.decode(Self.self, from: encodedJson)
    }
}

extension MCP.Tool {
    func toAnthropicTool() throws -> SwiftAnthropic.MessageParameter.Tool {
        //.init(with: self.inputSchema)
        let toolSchema = try SwiftAnthropic.JSONSchema.init(withMCPValue: self.inputSchema)
        return .function(name: self.name, description: self.description ?? "", inputSchema: toolSchema, cacheControl: .none)
    }
}

extension SwiftAnthropic.Model: CaseIterable {
    public static var allCases: [SwiftAnthropic.Model] = [
        .claudeInstant12,
        .claude2,
        .claude21,
        .claude3Opus,
        .claude3Sonnet,
        .claude35Sonnet,
        .claude3Haiku,
        .claude35Haiku,
        .claude37Sonnet,
    ]
}

extension RemoteLLMModel {
    var anthropicModel: SwiftAnthropic.Model {
        
        get throws {
            guard self.provider == .anthropic else {
                throw AnthropicError.notAnAnthropicModel("\(self.provider).\(self.id)")
            }
            
            if let foundModel = SwiftAnthropic.Model.allCases.filter({ $0.value == self.id }).first {
                return foundModel
            }
            else {
                return SwiftAnthropic.Model.other(self.id)
            }
        }
    }
}

open class AnthropicService: RemoteAIService {
    
    private let overridenApiKey: String?
    private let overridenBaseUrl: String?
    private let proxyAppAPIKey: String?
    
    public static let AnthropicAPIKeyStorageKey = "AnthropicAPIKey"
    
    private let sessionRefreshHandler: ProxySessionHandler?
    
    var apiKey: String? {
        return overridenApiKey ?? UserDefaults.standard.string(forKey: Self.AnthropicAPIKeyStorageKey)
    }
    
    public init(baseUrl: String? = nil, apiKey: String? = nil, proxyAppAPIKey: String? = nil, sessionRefreshHandler: ProxySessionHandler? = nil) {
        self.overridenBaseUrl = baseUrl
        self.overridenApiKey = apiKey
        self.sessionRefreshHandler = sessionRefreshHandler
        self.proxyAppAPIKey = proxyAppAPIKey
    }
    
    public func createServiceLLM(model: RemoteLLMModel, temperature: Double, topP: Double, tools: [MCP.Tool] = []) async throws -> any SwiftyPrompts.LLM {
        guard let apiKey = self.apiKey else {
            throw RemoteLLMServiceError.noAPIKey(model.fullModelID)
        }
        
        let anthropicLLM = try {
            if let baseUrlString = overridenBaseUrl, let baseUrl = URL(string: baseUrlString),
               let apiKey = overridenApiKey, let proxyAppAPIKey = proxyAppAPIKey {
                let httpClient = AnthropicProxiedHTTPClientAdapter(
                    proxyDetails: .init(proxyUrl: baseUrl, appAPIKey: proxyAppAPIKey),
                    sessionRefreshHandler: sessionRefreshHandler!)
                return AnthropicLLM(httpClient: httpClient, apiKey: apiKey, model: try model.anthropicModel, temperature: temperature, tools: tools.compactMap({ try? $0.toAnthropicTool() }))
            }
            else if let baseUrl = overridenBaseUrl, let apiKey = overridenApiKey {
                return AnthropicLLM(baseUrl: baseUrl, apiKey: apiKey, model: try model.anthropicModel, temperature: temperature, tools: tools.compactMap({ try? $0.toAnthropicTool() }))
            } else {
                return AnthropicLLM(apiKey: apiKey, model: try model.anthropicModel, temperature: temperature, tools: tools.compactMap({ try? $0.toAnthropicTool() }))
            }
        }()
        
        return anthropicLLM
    }
}
