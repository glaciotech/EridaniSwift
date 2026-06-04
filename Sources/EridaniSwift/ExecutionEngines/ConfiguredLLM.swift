//
//  ConfiguredLLM.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 9/9/25.
//

import SwiftyPrompts

/// A configured LLM service ready to perform inference, it just needs input to be provided.
public protocol ConfiguredLLM {
    associatedtype IC   // The expected input type
    associatedtype R   // The response from the LLM
    
    associatedtype Model: AnyLLMModel
    
    var activeModel: Model { get }
    func infer(msg: IC) async throws -> R?
}

// Protocol to adhere to for generating a configuredLLM
public protocol ConfiguredLLMFactoryProtocol {
    func configuredLLM(for model: any AnyLLMModel) throws -> LLM
}
