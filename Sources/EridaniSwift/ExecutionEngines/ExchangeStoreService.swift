//
//  ExchangeStoreService.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 9/12/25.
//

import Foundation
import SwiftyPrompts

public typealias EridaniMessage = EridaniSwift.Message

public protocol SwiftyPromptsExchangeStoreService {
    typealias SHM = SwiftyPrompts.Message
}

public protocol HasDefaultStorageOptions {
    static var `default`: Self {get set}
}

public struct EridaniModelSendOptions {
    public var maxImageDimension: Double
}

// Internal protocol to give us flexibility later to implement other StorageProviders. Has to be made public but not used or documented
public protocol ExchangeStoreServiceProtocol {
//    associatedtype MC             // The content type of the messages being exchanged
    associatedtype StorageOptions   // Options that effect the storage of the object. This can be anything, such as the data store to use a flag to set, etc. This just isn't relevant to the LLM
    associatedtype SendOptions      // Options that impact sending of messages to the LLM
//    associatedtype M              // Any metadata, such as number of tokens used to be stored with the exchange fragment
    associatedtype ID               // The id of the latest stored exchange fragment
    associatedtype SendableMessage  // The message type returned by sendableHistory
    associatedtype StorableMessage  // The structure to be stored, or holding the data that is stored internally in a different format
//    associatedtype A              // Type representing the author of the message
    
    // Store the message along with options that dictate how the message should be stored
//    func store(_ messageContents: [MC], author: A, metadata: M?, options: O?) async throws -> ID
//    func update(id: ID, content: [MC]?, metadata: M?) async throws  // Used to update existing exchange messages, you can leave this as a blank implementation if not used
    func sendableHistory(sendOptions: SendOptions?) async throws -> [SendableMessage] // Return the full conversation history stored so far as Messages for sending to the LLM
    
    func store(message: StorableMessage, options: StorageOptions?) async throws -> ID
    func update(message: StorableMessage, with id: ID) async throws
}

// MARK: These are protocols that build up and define various requirements for the storage service allowing for us to easily create StorageServices customizing at any level necessary

// Protocol that constrains the SendableMessage to a type that can be use with SwiftyPrompts llms
public protocol SendableMessageExchangeStoreServiceProtocol: ExchangeStoreServiceProtocol where SendableMessage == SwiftyPrompts.Message {}

// Protocol that pre constrains both SendableMessage and StorableMessage
public protocol BasicStorableMessageExchangeStoreServiceProtocol: SendableMessageExchangeStoreServiceProtocol where StorableMessage == EridaniSwift.Message, StorageOptions: HasDefaultStorageOptions, SendOptions == EridaniModelSendOptions {}


