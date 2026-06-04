//
//  BasicChatWithToolUseExchangeManager.swift
//  _EridaniSwiftSDK
//
//  Created by Peter Liddle on 11/22/25.
//

import SwiftyPrompts
import MCP
import SwiftyJsonSchema
import Foundation
import OpenAIKit
import OrderedCollections
import SwiftyJSONTools

public extension MCP.Value {
    public init(from spValue: SwiftyJsonSchema.Value) {
        self = Self.from(spValue: spValue)
    }
    
    private static func from(spValue: SwiftyJsonSchema.Value) -> MCP.Value {
        switch spValue {
        case .null: return MCP.Value.null
        case .bool(let bool): return MCP.Value.bool(bool)
        case .int(let int): return MCP.Value.int(int)
        case .double(let double): return MCP.Value.double(double)
        case .string(let string): return MCP.Value.string(string)
        case .array(let array): return MCP.Value.array(array.map({ Self.from(spValue: $0) }))
        case .object(let object): return MCP.Value.object( object.mapValues({ Self.from(spValue: $0)}) )
        }
    }
}

public struct ToolNameComponents: Hashable, Identifiable, Equatable {
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id
    }
   
    public var id: String {
        return fullName
    }
    
    private static let nameSeparator = "_"
   
    public var mcpServer: String
    public var toolName: String
    
    public init(fullName: String) throws {
        let comps = fullName.split(separator: "_", maxSplits: 2)
        
        guard comps.count == 2 else  {
            throw NSError(domain: "Invalid number of name components", code: 0)
        }
        
        self = .init(mcpServer: String(comps[0]), toolName: String(comps[1]))
    }
    
    public init(mcpServer: String, toolName: String) {
        self.mcpServer = mcpServer
        self.toolName = toolName
    }
    
    public var fullName: String {
        return "\(mcpServer)\(Self.nameSeparator)\(toolName)"
    }
}

public protocol ToolExecutionInterceptor {
    func beforeExecution(_ toolCall: MCPToolCallRequest) async throws
    func afterExecuted(_ content: [MCPTool.Content]) async throws
}

public protocol ToolCallAuthorizer: ToolExecutionInterceptor {
    func authorize(_ toolCall: MCPToolCallRequest) async throws
}

public extension ToolCallAuthorizer {
    
    public func beforeExecution(_ toolCall: MCPToolCallRequest) async throws {
        try await self.authorize(toolCall)
    }
    
    public func afterExecuted(_ content: [MCPTool.Content]) {
        // Do nothing
    }
}

public struct AlwaysApproveAuthorizer: ToolCallAuthorizer {
    
    public init() {}
    
    public func authorize(_ toolCall: MCPToolCallRequest) async throws {
        return
    }
}

public struct ClosureAuthorizer: ToolCallAuthorizer {
    private let authorizeClosure: @Sendable (MCPToolCallRequest) async throws -> Void
 
    public init(_ authorizeClosure: @escaping @Sendable (MCPToolCallRequest) async throws -> Void) {
        self.authorizeClosure = authorizeClosure
    }
 
    public func authorize(_ toolCall: MCPToolCallRequest) async throws {
        try await authorizeClosure(toolCall)
    }
}

protocol LoopControlConfig {
    func shouldCallNextStep(stepNo: Int) -> Bool
    var maxLoops: Int { get }
}

struct AlwaysContinueLoopConfig: LoopControlConfig {
    var maxLoops: Int = 0
    func shouldCallNextStep(stepNo: Int) -> Bool {
        true
    }
}


public extension ToolCallingExchangeManager {
    public func ask(_ text: String) async throws {
        try await ask(with: [.text(text)])
    }
    
    public func ask(_ content: LLMInputContent...) async throws {
        try await ask(with: content)
    }
}

open class ToolCallingExchangeManager<StoreService: BasicStorableMessageExchangeStoreServiceProtocol, SO>: ExchangeManagerProtocol where StoreService.StorageOptions == SO {
    
    // Some aliases to make things a little cleaner
    public typealias SendableMessageType = StoreService.SendableMessage
    public typealias StorageOptions = SO
    public var storageService: StoreService
    private let seedMessages: [SendableMessageType]
    
    public let llm: any LocalOrRemoteConfiguredLLM
    
    var toolExecutionInterceptor: any ToolExecutionInterceptor
    
    // Tool call execution handling
    var didCallTool: (String, Content) -> Void = {_, _ in }
    
    // Loop control config
    public var shouldCallNextStep: () -> Bool = { return true }
    var maxLoops = 7    // Stops it looping forever, and jamming machine
    
    var toolManager: any ToolManagerProtocol
    
    let encoder = JSONEncoder()
    
    public init(withSeedMessages: [SendableMessageType] = [], withStorageService ess: StoreService, withToolManager tm: any ToolManagerProtocol,
                and llm: any LocalOrRemoteConfiguredLLM, shouldCallNextStep: @escaping () -> Bool = { return true }, toolExecutionInterceptor: any ToolExecutionInterceptor = AlwaysApproveAuthorizer()) {
        self.seedMessages = withSeedMessages
        self.storageService = ess
        self.llm = llm
        self.toolManager = tm
        self.shouldCallNextStep = shouldCallNextStep
        self.toolExecutionInterceptor = toolExecutionInterceptor
    }
    
    private func convertInputToMessages(_ content: [LLMInputContent]) -> [SendableMessageType] {
        content.compactMap { uic -> SendableMessageType? in
            switch uic {
            case .imageData(let data, let subtype):
                return .user(.image(data, subtype))
            case .image(let image):
                if let imageData = image.pngData {
                    return .user(.image(imageData, "png"))
                }
                else {
                    return nil
                }
            case .text(let text):
                return .user(.text(text))
            case .error(let message):
                return .ai(.text(message))
            case .toolExchange(let toolCallOutput):
                return .tool(toolCallOutput)
            case .thinking(let thinkingItems):
                return .thinking(.init(id: thinkingItems.id, reasoning: thinkingItems.reasoning))
            }
        }
    }
    
    var maxImageSizeForModel: CGFloat {
        if let model = self.llm.activeModel as? RemoteLLMModel, model.provider == .anthropic {
            return model.configuration.maxSendableImageDimension
        }
        else {
            return RemoteLLMModel.ModelConfiguration.default.maxSendableImageDimension
        }
    }
    
    private func prepAndStoreContent(content: [LLMInputContent], author: Author, tokensUsedForMessage: Int, options: StorageOptions) async throws {
        let message = Message.init(content: content, author: author, metadata: .init(tokensUsedForMessage: tokensUsedForMessage))
        _ = try await storageService.store(message: message, options: options)
    }
    
    open func ask(with input: [LLMInputContent]) async throws {
        try await loopableAsk(with: input, loopCount: 0, afterToolCall: false)
    }
    
    private func handleToolCalls(toolCalls: [MCPToolCallRequest], usage: SwiftyPrompts.Usage) async throws {
        for toolCall in toolCalls where toolCalls != nil {
            
            do {
                let storableToolResult = try await callToolAndProcessResult(toolCall)
                
                let succesfulToolCallContent = LLMInputContent.toolExchange(try .init(callId: toolCall.callId, request: toolCall, response: storableToolResult))
                
                // The tokens are just the ones used by the request
                let message = Message.init(content: [succesfulToolCallContent], author: .tool, metadata: .init(tokensUsedForMessage: usage.completionTokens))
                _ = try await storageService.store(message: message, options: .default)
            }
            catch {
                // If we have an error store the request, the error and then rethrow the error, to stop processing
                let toolErrorResponse = MCPToolCallResponse(id: "error", callId: toolCall.callId, toolName: toolCall.toolName, output: AnyJSON.string(error.localizedDescription), errorMessage: error.localizedDescription)
                let message = Message.init(content: [LLMInputContent.toolExchange(try .init(callId: toolCall.callId, request: toolCall, response: toolErrorResponse))], author: .tool, metadata: .init(tokensUsedForMessage: usage.completionTokens))
                _ = try await storageService.store(message: message, options: .default)
                throw error
            }
        }
    }
    
    // THIS HANDLES THE bit after the tool call, i.e. sends back the response if there was a tool call loop
    private func handleSendingToolResultToAI(loopCount: Int) async throws {
        if shouldCallNextStep(), loopCount < maxLoops  {
            try await self.loopableAsk(with: [], loopCount: loopCount + 1, afterToolCall: true) // Invoke again as info should be stored
        }
    }
    
    private func loopableAsk(with input: [LLMInputContent], loopCount: Int, afterToolCall: Bool) async throws {
        
        let sendableHistory = try await storageService.sendableHistory(sendOptions: .init(maxImageDimension: maxImageSizeForModel))
        let allSendableMsgs = seedMessages + sendableHistory + convertInputToMessages(input)
        
        Log.debug("CURRENT HISTORY \(allSendableMsgs)")
        
#warning("We need to handle reasoning as well, store and send back")
        guard let answer = try await llm.infer(msg: allSendableMsgs) else {
            throw AskLLMError.noReply
        }
        
        // Check we have some sort of response otherwise store an error along with any tokens used
        guard answer.hasResponse else {
            try await prepAndStoreContent(content: [.error("Something went wrong, try again")], author: .ai, tokensUsedForMessage: answer.usage.totalTokens, options: .default)
            Log.error("No response from LLM")
            return
        }
        
        let (answerText, usage, reasoning) = (answer.output, answer.usage, answer.reasoning)
        var totalUsage = usage.completionTokens
        
        // Don't store anything until we get a succesful response
        // Store the input from the user
        if !afterToolCall { // Stop us storing a blank response, we should add the tokens used to the MCP call
            try await prepAndStoreContent(content: input, author: .user, tokensUsedForMessage: usage.promptTokens, options: .default)
        }
        else {
            totalUsage += usage.promptTokens
        }
        
        // store answerText if it isn't empty
        if !answerText.isEmpty {
            try await prepAndStoreContent(content: [.text(answerText)], author: .ai, tokensUsedForMessage: totalUsage, options: .default)
        }
        
        if let reasoning = reasoning, !reasoning.isEmpty {
            let reasoningText = reasoning.reasoning.joined(separator: ";")
            try await prepAndStoreContent(content: [.text(reasoningText)], author: .ai, tokensUsedForMessage: totalUsage, options: .default)
        }
        
        // --- Handle calling and storing tool calls //
        if let toolCalls = answer.toolCalls, !toolCalls.isEmpty {
            
            try await handleToolCalls(toolCalls: toolCalls, usage: usage)
            
            try await handleSendingToolResultToAI(loopCount: loopCount)
        }
        
        try await finishedAsk()
    }
    
    func callToolAndProcessResult(_ toolCall: MCPToolCallRequest) async throws -> MCPToolCallResponse {
        
        var toolResult: MCPToolCallResponse
        do {
            let resultContent = try await callTool(toolCall: toolCall)
            let anyJSONContent = try AnyJSON(from: resultContent)
            toolResult = MCPToolCallResponse(id: toolCall.id, callId: toolCall.callId, toolName: toolCall.toolName, output: anyJSONContent, errorMessage: nil)
        }
        catch let ToolManagerError.recoverableErrorFromToolCall(toolName, errorMsg){
            Log.error("Error calling MCP Tool \(toolName)")
            toolResult = MCPToolCallResponse(id: toolCall.id, callId: toolCall.callId, toolName: toolCall.toolName, output: AnyJSON.string(errorMsg), errorMessage: errorMsg)
        }
        
        return toolResult
    }
    
    func callTool(toolCall: MCPToolCallRequest) async throws -> [MCP.Tool.Content] {
        
        try await toolExecutionInterceptor.beforeExecution(toolCall)
        
        Log.debug("Call tool \(toolCall.toolName)")
        let resultContent = try await toolManager.handleToolCall(for: toolCall)
        
        try await toolExecutionInterceptor.afterExecuted(resultContent)
        
        return resultContent
    }
    
    open func finishedAsk() async throws {
        // Do nothing here. Placeholder for subclasses to initiate post ask logic
    }
}

public typealias InMemoryChatExchangeManager = SimpleChatExchangeManager<SimpleInMemoryStorageService>
public typealias InMemoryToolCallingExchangeManager = ToolCallingExchangeManager<SimpleInMemoryStorageService, SimpleInMemoryStorageService.StorageOptions>
