//
//  LocalModelManager.swift
//  _EridaniSwiftSDK
//
//  Created by Peter Liddle on 8/15/25.
//

import Foundation
import SwiftyPrompts
import SwiftyPrompts_Local
import MCP

public class LocalModelManager: ModelManager {
    
    public typealias Model = LocalLLMModel
    
    public struct LocalConfiguredLLM: LocalOrRemoteConfiguredLLM {
        
        public let activeModel: LocalLLMModel
        private let localLLM: LocalLLM
        
        init(llm: LocalLLM, model: AnyLLMModel) throws {
            self.localLLM = llm
            guard let activeModel = model as? LocalLLMModel else {
                throw ModelManagerError.notAValidLocalModel
            }
            
            self.activeModel = activeModel
        }
        
        public typealias IC = [SwiftyPrompts.Message]
        
        public typealias R = LLMResult
        
        public func infer(msg: [SwiftyPrompts.Message]) async throws -> LLMResult<String>? {
            
            let llmRunner = SwiftyPrompts.BasicPromptRunner()
            
            let response = try await llmRunner.run(with: msg, on: localLLM)
            
            Log.debug("Full prompt sent to \(activeModel.id) \n \(msg)")
            
            return LLMResult(rawText: response.output, output: response.output, usage: response.usage, toolCalls: [])
        }
    }
    
    
    public typealias LLM = LocalConfiguredLLM
    
    /// Return a configured LLM ready for inference
    /// - Returns: A RemoteConfiguredLLM  object
    public func configuredLLM(for model: any AnyLLMModel) throws -> LocalConfiguredLLM {
        return try LocalConfiguredLLM(llm: localLLM, model: model)
    }
    
    public func configuredLLM(for model: any AnyLLMModel, with tools: [MCP.Tool]) throws -> LocalConfiguredLLM {
        Log.info("NOTICE: Tools are not currently supported on local models. Running as normal chat")
        return try self.configuredLLM(for: model)  // We don't support tools at the moment so just call through to normal mode
    }
    
    
    public let localLLM: LocalLLM
    public let model: LocalLLMModel
    
    public init(for conversationId: UUID?, andModel model: LocalLLMModel) {
        self.model = model
        self.localLLM = SwiftyPrompts_Local.LocalLLM(modelStorageDir: model.baseModelDir, modelRepoId: model.repoId) // "Qwen2.5-Coder-14B-Instruct-4bit")// self.model.info.repoId)
    }
    
    public func isModelSetupAndAvailable(model: any AnyLLMModel) throws -> Bool {
        guard let localModel = model as? LocalLLMModel else {
            throw AskLLMError.notAValidLocalModel(model)
        }
        return try Self.isModelDownloadedAndValid(forModel: localModel)
    }
    
    public func isValidLLM(selectedModel: String) throws -> any AnyLLMModel {
        return try LocalLLMModel.resolve(withId: selectedModel)
    }
    

    public func checkModelAvailability() -> (available: [LocalLLMModel], unavailable: [LocalLLMModel]) {
        
        let availableLLMs = [LocalLLMModel]()
        let unavailableLLMs = [LocalLLMModel]()
        
        return (availableLLMs, unavailableLLMs)
    }
    
    public func resolveModel(fromFullName name: String) throws -> Model {
        return try LocalLLMModel.resolve(withId: name)
    }
    
    public func unload() {
        localLLM.unload()
    }
    
    // MARK: - Helper methods
    
    public static func isModelDownloadedAndValid(forModel model: LocalLLMModel) throws -> Bool {
        return try LocalLLM.isModelDownloadedAndAvailable(modelStorageDir: model.baseModelDir, modelRepo: model.repoId)
    }
    
    public func download() async throws -> AsyncThrowingStream<Progress, Error>  {
        let downloadStatus = try await localLLM.downloadModel()
        return downloadStatus
    }
    
    public static func modelLocation(of modelInfo: LocalLLMModel) -> String {
        return LocalLLM.modelStoragePath(modelStorageDir: modelInfo.baseModelDir, modelRepo: modelInfo.repoId)
    }
}
