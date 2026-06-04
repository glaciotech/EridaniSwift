//
//  ToolCallState.swift
//  EridaniExampleSwiftUIChatApp
//
//  Created by Peter Liddle on 5/16/26.
//

import SwiftUI
import EridaniSwift
import MCP
import SwiftyPrompts

struct EridaniAgent {
    
    enum ConnectionType {
        case proxy
        case direct
    }
    
    static let agentPrompt = """
        You're an expert in reading web content provided to you and summarizing it into markdown notes which you will write to a file. You should then read the file and show it to the user. In order to achieve this you should make use of any tools provided to you.
        """
    
    // This is a very simple in-memory storage service. There is no update mechanism so updates are done by polling
    // For this app it means UI won't update until the end of flow when ask() finishes and updateMessages() is called
    let storageService = SimpleInMemoryStorageService()
    
    private let exchangeManager: ToolCallingExchangeManager<SimpleInMemoryStorageService, EmptyStorageOptions>
    
    init(toolManager: any ToolManagerProtocol, toolApprovalCoordinator: ToolExecutionInterceptor, connection: ConnectionType = .proxy) async throws {
        
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
        let llm = try RemoteModelManager(with: remoteServiceContainer, toolManager: toolManager).configuredLLM(for: RemoteLLMModel.gpt5Nano)
        self.exchangeManager = ToolCallingExchangeManager(withSeedMessages: [.system(.text(Self.agentPrompt))], withStorageService: storageService,
                                                     withToolManager: toolManager, and: llm, toolExecutionInterceptor: toolApprovalCoordinator)
        
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

class ToolCallState: ObservableObject {
    
    let pollMessageUpdates = false  // Alter this to poll for message updates or listen for updates provided by the storage service
    
    struct SimpleMessage: Identifiable {
        
        var id: String {
            return output
        }
        
        var role: String = ""
        var output: String = ""
        
        var tokens: Int = 0
        var isError: Bool = false
    }
    
    @Published var chatMessages: [SimpleMessage] = []
    @Published var displayableError: String?
    @Published var isAsking: Bool = false
    @Published var pendingToolApprovalRequest: ToolApprovalRequest?
    
    // Create a server with a number of tools for the example ToolAgent
    private let eridaniToolsServer = EridaniToolsServer()
    
    let tm: MCPToolManager
    let toolApprovalCoordinator: ToolExecutionUserApprovalCoordinator
    var agent: EridaniAgent?
    
    init() {
        self.tm = MCPToolManager(currentlyEnabled: true)
        toolApprovalCoordinator = ToolExecutionUserApprovalCoordinator(toolManager: tm)
        
        // Start a listening task for events from the approval coordinator
        Task { [weak self] in
            guard let wSelf = self else {
                return
            }
            
            for try await request in wSelf.toolApprovalCoordinator.approvalEventStream() {
                await MainActor.run {
                    wSelf.pendingToolApprovalRequest = request
                }
            }
        }
    }
    
    func loadTools() async throws {
        let clientTransport = try await eridaniToolsServer.start()
        try await tm.loadDirect(name: "EridaniTools", version: "0.1", clientTransport: clientTransport)
    }
    
    
    func resolveAgent() async throws -> EridaniAgent {
        
        let useDirect = UserDefaults.standard.string(forKey: "OPENAI_API_KEY") != nil
        
        func listenForUpdates(on agent: EridaniAgent) {
            // This is optional. You can also poll the messages using update message after ask and tool updates.
            Task {
                for try await _ in agent.storageService.updateStream {
                    try await self.updateMessages()
                }
            }
        }
        
        guard let agent = self.agent else {
            let agent = try await EridaniAgent(toolManager: tm, toolApprovalCoordinator: toolApprovalCoordinator, connection: useDirect ? .direct : .proxy)
            self.agent = agent
            
            if !pollMessageUpdates {
                listenForUpdates(on: agent)
            }
            
            return agent
        }
        
        if !pollMessageUpdates {
            listenForUpdates(on: agent)
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
            
            if pollMessageUpdates {
                try await updateMessages()
            }
        }
        catch {
            if pollMessageUpdates {
                try? await updateMessages()
            }
            
            await MainActor.run {
                displayableError = "Error during chat exchange: \(error)"
                self.isAsking = false
            }
        }
    }
    
    private func updateMessages() async throws {
        
        // In a real app you'd likely want to hand decode the stored messages, rather then using the history. This is just a quick hack for the example
        let history = try await resolveAgent().history()
        let rawMessages = try await resolveAgent().storedMessages()
        
        // At this point these should be the same size. For the example just show an error message if these get out of sync
        if history.count == rawMessages.count {
            await MainActor.run {
                displayableError = nil
            }
        }
        else {
            await MainActor.run {
                displayableError = "Tokens and messages are likely out of sync"
            }
        }
        
        let fullHistory = zip(history, rawMessages)
        
        await MainActor.run {
            chatMessages = fullHistory.map({ SimpleMessage.init(role: $0.0.author, output: $0.0.text, tokens: $0.1.metadata?.tokensUsedForMessage ?? 0, isError: $0.0.isError) })
        }
    }
}
