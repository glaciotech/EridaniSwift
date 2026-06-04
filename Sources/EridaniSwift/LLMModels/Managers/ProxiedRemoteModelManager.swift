//
//  ProxiedRemoteModelManager.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 9/12/25.
//

public struct ProxyDetails {
    public var authToken: ProxyAuthToken
    public var proxyUrl: String
    public var proxyAppApiKey: String
    
    public init(authToken: ProxyAuthToken, proxyUrl: String, proxyAppApiKey: String) {
        self.authToken = authToken
        self.proxyUrl = proxyUrl
        self.proxyAppApiKey = proxyAppApiKey
    }
}

public class ProxiedRemoteModelManager: RemoteModelManager {
    
    public typealias Model = RemoteLLMModel
    
    private let proxyService: ProxyAPIService
    private var cachedModels: [RemoteLLMModel] = []
    
    public override var areAvailableModelsLoaded: Bool {
        return cachedModels.isEmpty
    }
    
    public init(with proxyDetails: ProxyDetails, sessionManager: ProxySessionHandler, proxyService: ProxyAPIService, toolManager: (any ToolManagerProtocol)?) {
        self.proxyService = proxyService
        let remoteLLMServices = ProxiedRemoteLLMServiceContainer(withProxy: proxyDetails, sessionRefreshHandler: sessionManager)
        
        super.init(with: remoteLLMServices, toolManager: toolManager)
        
        self.modelSuggestions = .init() // Reset these to be nil for proxied on init
        
        Task {
            await self.loadModels()
        }
    }
    
    private func loadModels() async {
        if let (models, suggestions) = try? await proxyService.fetchAvailableCloudLLMModels() {
            self.cachedModels = models
            self.modelSuggestions = suggestions
        }
        else {
            self.cachedModels = []
        }
    }
    
    private func fetchModels() async throws -> [RemoteLLMModel] {
        if cachedModels.isEmpty {
            await loadModels()
        }
        return cachedModels
    }
    
    override public func checkModelAvailability(allowAll: Bool = false) async -> (available: [RemoteLLMModel], unavailable: [RemoteLLMModel]) {
        
        // Pull models from the ones available on the proxy
       
        if cachedModels.isEmpty {
            await loadModels()
        }
        
        return (available: cachedModels, unavailable: [])
    }
    
    public override func isModelSetupAndAvailable(model: any AnyLLMModel) throws -> Bool {
        // Determined on the proxy not locally
        return true
    }
    
    
    /// Finds a model based on a full name structured as {Provider}.{Modle} for instance OpenAI.gpt-4
    /// - Parameter name: The full name of the model, including provider name. i.e OpenAI.gpt-4o
    /// - Returns: A valid remote AI model
    public override func resolveModel(fromFullName name: String) async throws -> RemoteLLMModel {
        
        let nameComps = name.split(separator: RemoteLLMModel.separator)
        
        guard nameComps.isEmpty == false, nameComps.count == 2 else {
            throw LLMModelError.notAValidModelFullName(name)
        }
        
        let models = try await fetchModels().filter({ $0.provider.rawValue == String(nameComps[0]) && $0.id == String(nameComps[1]) })
        
        guard models.count == 1 else {
            throw LLMModelError.modelIdConflict
        }
        
        guard let model = models.first else {
            throw LLMModelError.noModelMatchingFullName(name)
        }
        
        return model
    }
}
