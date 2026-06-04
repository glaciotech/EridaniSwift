//
//  SimpleChatExchangeManager.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 12/4/25.
//

import SwiftyPrompts

open class SimpleChatExchangeManager<StoreService: BasicStorableMessageExchangeStoreServiceProtocol>: ExchangeManagerProtocol {

    public enum ImageFormat: String {
        case png = "png"
        case jpeg = "jpeg"
    }
    
    // Some aliases to make things a little cleaner
    public typealias SendableMessageType = StoreService.SendableMessage
    public typealias StorageOptions = StoreService.StorageOptions
    
    public var storageService: StoreService
    private let seedMessages: [SendableMessageType]
    
    public let llm: any LocalOrRemoteConfiguredLLM
    
    public var shouldCallNextStep: () -> Bool = { return false }
    
    public let imageType: ImageFormat
    
    public init(withSeedMessages: [SendableMessageType] = [], withStorageService ess: StoreService,
                and llm: any LocalOrRemoteConfiguredLLM, shouldCallNextStep: @escaping () -> Bool = { return false }, imageFormat: ImageFormat = .jpeg) {
        self.seedMessages = withSeedMessages
        self.storageService = ess
        self.llm = llm
        self.shouldCallNextStep = shouldCallNextStep
        self.imageType = imageFormat
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
//                
//                switch imageType {
//                case .png:
//                    if let pngImageData = image.pngData {
//                        return .user(.image(pngImageData, imageType.rawValue))
//                    }
//                    else {
//                        return nil
//                    }
//                case .jpeg:
//                    if let jpegImageData = image.jpegData {
//                        return .user(.image(jpegImageData, imageType.rawValue))
//                    }
//                    else {
//                        return nil
//                    }
//                }
                
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
    
    private func prepAndStoreContent(content: [LLMInputContent], author: Author, tokensUsedForMessage: Int, options: StorageOptions) async throws {
        let message = Message.init(content: content, author: author, metadata: .init(tokensUsedForMessage: tokensUsedForMessage))
        _ = try await storageService.store(message: message, options: options)
    }
    
    open func ask(with input: [LLMInputContent]) async throws {
        try await loopableAsk(with: input, loopCount: 0)
    }

    private func loopableAsk(with input: [LLMInputContent], loopCount: Int) async throws {
        
        let sendableHistory = try await storageService.sendableHistory(sendOptions: nil)
        
        //        #error("We need to handle taking tool string from storage and converting to sendable type at the moment it's a string, which is failing on conversion to OpenAIFormat")
        
        //        #error("We need to handle decoding the tool result here to send it properly")
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
        
        
        // Don't store anything until we get a succesful response
        // Store the input from the user
        try await prepAndStoreContent(content: input, author: .user, tokensUsedForMessage: usage.promptTokens, options: .default)
        // Store the response from the AI #warning("Handle empty respnses?")
        
        // store answerText if it isn't empty
        if !answerText.isEmpty {
            try await prepAndStoreContent(content: [.text(answerText)], author: .ai, tokensUsedForMessage: usage.completionTokens, options: .default)
        }
        
        if let reasoning = reasoning, !reasoning.isEmpty {
            let reasoningText = reasoning.reasoning.joined(separator: ";")
            try await prepAndStoreContent(content: [.text(reasoningText)], author: .ai, tokensUsedForMessage: usage.completionTokens, options: .default)
        }
        
        try await finishedAsk()
    }
    
    open func finishedAsk() async throws {
        // Do nothing here. Placeholder for subclasses to initiate post ask logic
    }
}

extension SimpleChatExchangeManager {

    open func ask(_ text: String) async throws {
        try await ask(with: [.text(text)])
    }

    open func ask(_ content: LLMInputContent...) async throws {
        try await ask(with: content)
    }
}