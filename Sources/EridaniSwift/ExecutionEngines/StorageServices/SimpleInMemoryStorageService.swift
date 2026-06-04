//
//  SimpleInMemoryStorageService.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 11/23/25.
//

import Foundation
import SwiftyPrompts
import OrderedCollections
import SwiftyJSONTools

enum StorageServiceErrors: Swift.Error {
    case noExistingMessageWithId(String)
}

public struct EmptyStorageOptions: HasDefaultStorageOptions {
    public static var `default` = EmptyStorageOptions()
    public init() {}
}

public typealias SendableMessage = SwiftyPrompts.Message

/// A simple StorageService with support for text and images that stores user questions and ai responses in memory.
open class SimpleInMemoryStorageService: BasicStorableMessageExchangeStoreServiceProtocol {
    
    public enum Event {
        case update
        case newMessage
    }
    
    private let encoder = JSONEncoder()
    
    typealias O = EmptyStorageOptions
         
    public typealias ID = UUID
    
    public typealias SHM = Message
    
    private var storage = OrderedCollections.OrderedDictionary<UUID, SHM>()
    
    private var updatesStream: AsyncStream<Event>?
    private var updatesStreamContinuation: AsyncStream<Event>.Continuation?
    
    public init(storage: OrderedDictionary<UUID, SimpleInMemoryStorageService.SHM> = OrderedCollections.OrderedDictionary<UUID, SHM>()) {
        self.storage = storage
    }
    
    public var updateStream: AsyncStream<Event> {
        let stream = AsyncStream<Event> { continuation in
            self.updatesStreamContinuation = continuation
        }
        self.updatesStream = stream
        return stream
    }
    
    public var rawStoredMessages: [SimpleInMemoryStorageService.SHM] {
        return Array(self.storage.values)
    }
    
    public func store(message: SHM, options: EmptyStorageOptions?) async throws -> UUID {
        let id = UUID()
        storage[id] = message
        self.updatesStreamContinuation?.yield(.newMessage)
        return id
    }
    
    public func update(message: SHM, with id: UUID) async throws {
        if let _ = storage[id] {
            storage[id] = message
            self.updatesStreamContinuation?.yield(.update)
        }
        else {
            throw StorageServiceErrors.noExistingMessageWithId(id.uuidString)
        }
    }
    
    public func sendableHistory(sendOptions: EridaniModelSendOptions? = nil) async throws -> [SendableMessage] {
        
        let messages: [SwiftyPrompts.Message] = storage.values.reduce(into: [SwiftyPrompts.Message]()) {
            collectedMsgs,
            msg in
            switch msg.author {
            case .ai where !msg.content.isEmpty:
                let sendableContent = self.handleContent(contents: msg.content)
                let aiMessages = sendableContent.map { SwiftyPrompts.Message.ai($0) }
                collectedMsgs.append(contentsOf: aiMessages)
            case .user where !msg.content.isEmpty:
                let sendableContent = self.handleContent(contents: msg.content)
                let userMessages = sendableContent.map { SwiftyPrompts.Message.user($0) }
                collectedMsgs.append(contentsOf: userMessages)
            case .tool where !msg.content.isEmpty:
                guard let first = msg.content.first, case let LLMInputContent.toolExchange(tco) = first else {
                    return
                }
                collectedMsgs.append(.tool(tco))
            case .system where !msg.content.isEmpty:
                let sendableContent = self.handleContent(contents: msg.content)
                let systemMessages = sendableContent.map { SwiftyPrompts.Message.system($0) }
                collectedMsgs.append(contentsOf: systemMessages)
            default:
                return
            }
        }
        return messages
    }
    
    private func handleContent(contents: [LLMInputContent]) -> [Content] {
        
        contents.reduce(into: [Content]()) { partialResult, uic in
            if case let LLMInputContent.text(string) = uic {
                partialResult.append(.text(string))
            }
            else if case let LLMInputContent.imageData(data, subtype) = uic {
                partialResult.append(.image(data, subtype))
            }
            else if case let LLMInputContent.image(pngDataRepresentable) = uic, let pngData = pngDataRepresentable.pngData {
                partialResult.append(.image(pngData, "png"))
            }
            else if case let LLMInputContent.toolExchange(toolCallOutput) = uic {
                fatalError("Content not supported by SimpleInMemoryStorageService")
            }
            else {
                fatalError("Content not supported by SimpleInMemoryStorageService")
            }
        }
    }
}

