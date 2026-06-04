//
//  ModelManager.swift
//  Ventus
//
//  Created by Peter Liddle on 2/28/24.
//

import Foundation
import SwiftyPrompts

enum ModelManagerError: Error {
    case notAValidLocalModel
    case notAValidRemoteModel
    case notCurrentlyAvailable
}

public protocol LocalOrRemoteConfiguredLLM: ConfiguredLLM where IC == [SwiftyPrompts.Message], R == LLMResult<String> { }

public protocol ModelManager {
    
    associatedtype LLM: LocalOrRemoteConfiguredLLM
    associatedtype Model: AnyLLMModel
    
    func configuredLLM(for model: any AnyLLMModel) throws -> LLM
    func configuredLLM(for model: any AnyLLMModel, with tools: [MCPTool]) throws -> LLM
    
    func isModelSetupAndAvailable(model: any AnyLLMModel) throws -> Bool
    func isValidLLM(selectedModel: String) throws -> any AnyLLMModel
    
    func resolveModel(fromFullName name: String) async throws -> Model
}

