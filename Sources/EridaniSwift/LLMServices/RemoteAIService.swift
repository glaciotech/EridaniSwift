//
//  RemoteAIService.swift
//  VentusAI
//
//  Created by Peter Liddle on 4/16/24.
//

import Foundation
import SwiftyPrompts
import SwiftyPrompts_OpenAI
import MCP

public typealias LLMResult = ExchangeOutput

extension LLMResult {
    var hasResponse: Bool {
        return !((output == nil) && (toolCalls?.isEmpty ?? true) && (reasoning?.isEmpty ?? true))
    }
}

struct SystemTemplate: KeyPathPromptTemplate {
    static var template: String = "You are a helpful assistant that \(\Self.ability)"
    var ability: String
}

struct UserTemplate: KeyPathPromptTemplate {
    static var template: String = "\(\Self.userQuestion)"
    var userQuestion: String
}

public protocol RemoteAIService {
    func createServiceLLM(model: RemoteLLMModel, temperature: Double, topP: Double, tools: [Tool]) async throws -> LLM
}
