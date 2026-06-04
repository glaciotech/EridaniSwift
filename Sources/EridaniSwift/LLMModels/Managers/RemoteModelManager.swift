//
//  RemoteModelManager.swift
//  _EridaniSwiftSDK
//
//  Created by Peter Liddle on 8/15/25.
//
import Foundation
import SwiftyPrompts
import SwiftyJSONTools

@available(*, deprecated, message: "Use LLMInputContent.imageData(_:subtype:) to provide image bytes and format without enforcing PNG")
public protocol PngDataRepresentable {
    var pngData: Data? { get }
}


/// Content that can be passed to or returned from an LLM
public enum LLMInputContent {
    case text(String)

    case imageData(Data, subtype: String)

    @available(*, deprecated, message: "Use imageData(_:subtype:) to send JPEG/PNG (or other) bytes with the correct subtype")
    case image(PngDataRepresentable)
    case error(String)          // Used to store an error that occurs during processing
    case toolExchange(ToolCallExchange)
    case thinking(ReasoningItem)
}

public enum RemoteModelManagerError: Error {
    case invalidRemoteModel(String)
}

public protocol RemoteModelManagerProtocol: ModelManager {
    typealias Model = RemoteLLMModel
    func resolveModel(fromFullName name: String) async throws -> RemoteLLMModel
    func checkModelAvailability(allowAll: Bool) async -> (available: [RemoteLLMModel], unavailable: [RemoteLLMModel])
    
    var modelSuggestions: ModelSuggestions { get }
    var areAvailableModelsLoaded: Bool { get }
}
    
public class RemoteModelManager: RemoteModelManagerProtocol {
    
    public var modelSuggestions = ModelSuggestions(cheapestModel: RemoteLLMModel.gpt5Nano, suggestedModel: RemoteLLMModel.gpt5Mini)
    public var areAvailableModelsLoaded: Bool {
        return true
    }
    
        
    public typealias Model = RemoteLLMModel
    
    public struct RemoteConfiguredLLM: LocalOrRemoteConfiguredLLM {

        public typealias Model = RemoteLLMModel
        
        public let remoteService: RemoteAIService
        public let activeModel: RemoteLLMModel
        
        var toolManager: ToolManagerProtocol?
        
        init(remoteService: RemoteAIService, model: RemoteLLMModel, toolManager: ToolManagerProtocol?) {
            self.remoteService = remoteService
            self.activeModel = model
            
            self.toolManager = toolManager
        }
        
        public typealias IC = [SwiftyPrompts.Message]
        
        public typealias R = LLMResult<String>
        
        private func createLLM() async throws -> SwiftyPrompts.LLM {
            if let tm = toolManager, tm.currentlyEnabled {
                return try await remoteService.createServiceLLM(model: activeModel, temperature: 1.0, topP: 1.0, tools: Array(tm.availableTools.values))
            }
            else {
                return try await remoteService.createServiceLLM(model: activeModel, temperature: 1.0, topP: 1.0, tools: [])
            }
        }
  
        public func infer(msg: [SwiftyPrompts.Message]) async throws -> LLMResult<String>? {
            
            let llm = try await createLLM()
            
            let llmRunner = SwiftyPrompts.BasicToolCapablePromptRunner()
            
            let response = try await llmRunner.run(with: msg, on: llm)
            
            Log.debug("Full prompt sent to \(activeModel.id) \n \(msg)")
            
            return response
        }
    }
    
    public typealias LLM = RemoteConfiguredLLM
    
    let remoteLLMServices: RemoteLLMServiceContainer
    
    var toolManager: ToolManagerProtocol?

//    #error("Set default for toolManager to nil")
    public init(with remoteLLMServices: RemoteLLMServiceContainer = RemoteLLMServiceContainer(), toolManager: ToolManagerProtocol? = nil) {
        self.remoteLLMServices = remoteLLMServices
        self.toolManager = toolManager
    }
    
    public func isModelSetupAndAvailable(model: any AnyLLMModel) throws -> Bool {
        guard let remoteModel = model as? RemoteLLMModel else {
            throw AskLLMError.notAValidRemoteModel(model)
        }
        
        let apiKeySetup = try remoteLLMServices.areApiKeysSetup(forModel: remoteModel)
        
        guard apiKeySetup else {
            throw AskLLMError.noAPIKeyForModelProvider(remoteModel.provider.rawValue)
        }
        
        return apiKeySetup
    }
    
    public func isValidLLM(selectedModel: String) throws -> any AnyLLMModel {
        return try RemoteLLMModel.resolve(withId: selectedModel)
    }
    
    public func checkModelAvailability(allowAll: Bool = false) async -> (available: [RemoteLLMModel], unavailable: [RemoteLLMModel]) {
    
        if allowAll {
            return (RemoteLLMModel.allKnown, [])
        }
        
        var availableLLMs = [RemoteLLMModel]()
        var unavailableLLMs = [RemoteLLMModel]()
        
        for model in RemoteLLMModel.allKnown {
            guard let available: Bool = try? remoteLLMServices.areApiKeysSetup(forModel: model) else {
                continue
            }
            
            if available {
                availableLLMs.append(model)
            }
            else {
                unavailableLLMs.append(model)
            }
        }
        
        return (availableLLMs, unavailableLLMs)
    }
    
    /// Return a configured LLM ready for inference
    /// - Returns: A RemoteConfiguredLLM  object
    public func configuredLLM(for model: any AnyLLMModel) throws -> RemoteConfiguredLLM {
        try self.configuredLLM(for: model, with: [])
    }
    
    public func configuredLLM(for model: any AnyLLMModel, with tools: [MCPTool]) throws -> RemoteConfiguredLLM {
        guard let remoteModel = model as? RemoteLLMModel else {
            throw ModelManagerError.notAValidRemoteModel
        }
        
        let remoteLLMService = try remoteLLMServices.resolveAIService(for: remoteModel)
        return RemoteConfiguredLLM(remoteService: remoteLLMService, model: remoteModel, toolManager: toolManager)
    }
    
    
    /// Finds a model based on a full name structured as {Provider}.{Modle} for instance OpenAI.gpt-4
    /// - Parameter name: The full name of the model, including provider name. i.e OpenAI.gpt-4o
    /// - Returns: A valid remote AI model
    public func resolveModel(fromFullName name: String) async throws -> RemoteLLMModel {
        
        let nameComps = name.split(separator: RemoteLLMModel.separator)
        
        guard nameComps.isEmpty == false, nameComps.count == 2 else {
            throw LLMModelError.notAValidModelFullName(name)
        }
        
        let models = RemoteLLMModel.allKnown.filter({ $0.provider.rawValue == String(nameComps[0]) && $0.id == String(nameComps[1]) })
        
        guard models.count == 1 else {
            throw LLMModelError.modelIdConflict
        }
        
        guard let model = models.first else {
            throw LLMModelError.noModelMatchingFullName(name)
        }
        
        return model
    }
}
