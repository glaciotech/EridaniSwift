//
//  AnyAIModel.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 8/15/25.
//

public struct ModelCosts: Codable {
        
    public static let zero = Self(inputTokenCost: 0, outputTokenCost: 0)
    
    public var inputTokenCost: Double
    public var outputTokenCost: Double
}


public protocol HasAvailableModels {
    associatedtype T: AnyLLMModel
    static var allKnown: [T] { get }
    static func resolve(withId id: String) throws -> T
}

// Adhering to RawRepresentable allows us to store it in things like UserDefaults, but we have to have a resolve mechanism dependent on known llms
public protocol StorableModel: RawRepresentable where Self: HasAvailableModels { }

extension HasAvailableModels {
    public static func resolve(withId id: String) throws -> T {
        let models = Self.allKnown.filter({ $0.id == id })
       
        switch models.count {
        case 0:
            throw LLMModelError.noModelMatchingId(id)
        case 1:
            return models.first!
        case 2...:
            throw LLMModelError.modelIdConflict
        default:
            throw LLMModelError.noModelMatchingId(id)
        }
    }
}

public typealias FullModelId = String

public protocol AnyLLMModel: Hashable, StorableModel where RawValue == String {
    var id: String { get }
    var name: String { get }
}
