//
//  ChatState.swift
//  EridaniExampleSwiftUIChatApp
//
//  Created by Peter Liddle on 5/20/26.
//


import SwiftUI
import EridaniSwift

struct EridaniAgent {
    
    enum ConnectionType {
        case proxy
        case direct
    }
    
    static let agentPrompt = """
        You're a helpful assistant with expertise in a broad range of topics.
        """
    
    private let storageService = SimpleInMemoryStorageService()
    
    private let exchangeManager: SimpleChatExchangeManager<SimpleInMemoryStorageService>
    
    init(connection: ConnectionType = .proxy) async throws {
        
        let remoteServiceContainer: RemoteLLMServiceContainer = try await {
            switch connection {
            case .proxy:
                // Creates an LLM container that uses the proxy to talk to remote LLM services (OpenAI, Anthropic, xAI) ideal for production environments.
                let remoteServiceContainer = try await EridaniProxyFactory.createProxiedAIContainer()
                return remoteServiceContainer
            case .direct:
                // Creates a direct connection to the remote LLM provider such as OpenAI.
                let openAIKey = UserDefaults.standard.string(forKey: "OPENAI_API_KEY")
                let remoteServiceContainer = RemoteLLMServiceContainer(openAIService: OpenAIService.init(apiKey: openAIKey))
                return remoteServiceContainer
            }
        }()
        
        // NOTE: You can change the model you want to use below, just use any option on RemoteLLMModel
        let llm = try RemoteModelManager(with: remoteServiceContainer).configuredLLM(for: RemoteLLMModel.gpt5Nano)
        
        self.exchangeManager = SimpleChatExchangeManager(withStorageService: storageService, and: llm)
        
    }
    
    func ask(_ text: String) async throws {
        try await exchangeManager.ask(with: [.text(text)])
    }
    
    func history() async throws -> [SendableMessage] {
        try await exchangeManager.storageService.sendableHistory()
    }
    
    func storedMessages() -> [SimpleInMemoryStorageService.SHM] {
        self.storageService.rawStoredMessages
    }
}

class ChatState: ObservableObject {
    
    struct SimpleMessage: Identifiable {
        
        var id: String {
            return output
        }
        
        var role: String = ""
        var output: String = ""
        var isError: Bool = false
    }
    
    
    @Published var chatMessages: [SimpleMessage] = []
    @Published var displayableError: String?
    
    @Published var isAsking: Bool = false
    
    private var agent: EridaniAgent?
    
    let llmModel: RemoteLLMModel = .gpt5Nano
    
    func resolveAgent() async throws -> EridaniAgent {
        
        let useDirect = UserDefaults.standard.string(forKey: "OPENAI_API_KEY") != nil
        
        guard let agent = self.agent else {
            let agent = try await EridaniAgent(connection: useDirect ? .direct : .proxy)
            self.agent = agent
            return agent
        }
        return agent
    }
    
    func ask(input: String) async {

        do {
            await MainActor.run {
                self.isAsking = true
            }
            
            try await resolveAgent().ask(input)
            
            await MainActor.run {
                self.isAsking = false
            }
            
            try await updateMessages()
        }
        catch {
            await MainActor.run {
                displayableError = "Error during chat exchange: \(error)"
                self.isAsking = false
            }
        }
    }
    
    private func updateMessages() async throws {
        
        let history = try await resolveAgent().history()
        
        await MainActor.run {
            chatMessages = history.map({ SimpleMessage.init(role: $0.author, output: $0.text, isError: $0.isError) })    // This is kind of brute force, you'll want a more efficent way in your app
        }
    }
}
