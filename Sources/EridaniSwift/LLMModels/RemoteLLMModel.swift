//
//  RemoteLLMModels.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 8/15/25.
//

import Foundation

public struct RemoteLLMModel: AnyLLMModel, Identifiable {
    
    public struct ModelConfiguration {
        
        static let `default` = Self.init(maxSendableImageDimension: 600)
        
        static let anthropicConfiguration = ModelConfiguration(maxSendableImageDimension: 800)
        
        static let openAIConfiguration = ModelConfiguration(maxSendableImageDimension: 1680)
        static let gpt5ModelsConfiguration = ModelConfiguration(modelSpecificPrompt: "Text output should be returned in markdown format", maxSendableImageDimension: 1680)
        
//        static let xAIConfiguration = ModelConfiguration(maxSendableImageDimension: 0)
        
        static let inceptionConfiguration = ModelConfiguration(maxSendableImageDimension: 800)
        
        static let noImageSupportConfig = ModelConfiguration(maxSendableImageDimension: 0)
        
        var modelSpecificPrompt: String? = nil
        var maxSendableImageDimension: Double
    }
    
    public static func == (lhs: RemoteLLMModel, rhs: RemoteLLMModel) -> Bool {
        lhs.id == rhs.id
    }
    
    public enum Provider: String, Codable {
        case openAI
        case anthropic
        case xAI
        case inception
#if DEBUG
        case testModel
#endif
        
        public init?(rawValue: String) {
            switch rawValue.lowercased() {
            case "openai":
                self = .openAI
            case "anthropic":
                self = .anthropic
            case "xai":
                self = .xAI
            case "inception":
                self = .inception
            default:
                Log.error("Provider \(rawValue) is not currently supported, make sure you add to RemoteLLmModel.Provider.init")
                return nil
            }
        }
    }
    
    public var provider: Provider
    public var id: String
    public var name: String
    
    public var costs: ModelCosts?
    public var configuration: ModelConfiguration
    
    public var displayName: String {
        return name
    }
    
    public var fullModelID: FullModelId {
        return "\(provider.rawValue)\(Self.separator)\(id)"
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}

// Add compliance with StorableModel so it can be saved in UserDefaults
extension RemoteLLMModel: StorableModel {
    
    static let separator = ":"
    
    public typealias RawValue = String
    
    public init?(rawValue: String) {
        
        func extractComponents(from rawValue: String) -> (String, String)? {
            let components = rawValue.split(separator: Self.separator).prefix(2)
            guard components.count == 2 else { return nil }
            return (String(components[0]), String(components[1]))
        }

        func matchfilter(item: Self) -> Bool {
            guard let (providerText, id) = extractComponents(from: rawValue) else {
                return false
            }
            return item.provider.rawValue == providerText && item.id == id
        }
        
        if let model = Self.allKnown.first(where: matchfilter) {
            self = model
        }
        else {
            // For things like proxied models we can't resolve all here as they maynot be known, for those just set id. Should still work for most things
            guard let comps = extractComponents(from: rawValue), let provider = Provider.init(rawValue: comps.0) else {
                return nil
            }
            
            let config: ModelConfiguration = {
                switch provider {
                    
                case .openAI: .openAIConfiguration
                case .anthropic: .anthropicConfiguration
                case .xAI: .noImageSupportConfig
                case .inception: .noImageSupportConfig
                case .testModel: .default
                }
            }()
            
            self = .init(provider: provider, id: comps.1, name: comps.1, configuration: config)
        }
    }
    
    public var rawValue: String {
        return provider.rawValue + Self.separator + id
    }
}

// Add available models
extension RemoteLLMModel: HasAvailableModels {
    
    public typealias T = RemoteLLMModel
    
    // MARK: - OpenAI Models
    public static let gpt5 = RemoteLLMModel(provider: .openAI, id: "gpt-5", name: "ChatGPT 5", costs: ModelCosts(inputTokenCost: Double(2.5/1E6), outputTokenCost: Double(10/1E6)), configuration: .gpt5ModelsConfiguration)
    public static let gpt5Mini = RemoteLLMModel(provider: .openAI, id: "gpt-5-mini", name: "ChatGPT 5 Mini", costs: ModelCosts(inputTokenCost: Double(2.5/1E6), outputTokenCost: Double(10/1E6)), configuration: .gpt5ModelsConfiguration)
    public static let gpt5Nano = RemoteLLMModel(provider: .openAI, id: "gpt-5-nano", name: "ChatGPT 5 Nano", costs: ModelCosts(inputTokenCost: Double(2.5/1E6), outputTokenCost: Double(10/1E6)), configuration: .gpt5ModelsConfiguration)
    
    public static let gpt4o = RemoteLLMModel(provider: .openAI, id: "gpt-4o", name: "ChatGPT 4o", costs: ModelCosts(inputTokenCost: Double(2.5/1E6), outputTokenCost: Double(10/1E6)), configuration: .openAIConfiguration)
    public static let gpt4oMini = RemoteLLMModel(provider: .openAI, id: "gpt-4o-mini", name: "ChatGPT 4o Mini", costs: ModelCosts(inputTokenCost: Double(2.5/1E6), outputTokenCost: Double(10/1E6)), configuration: .openAIConfiguration)
    
    // MARK: - Anthropic Models
    public static let anthropicOpus41 = RemoteLLMModel(
        provider: .anthropic,
        id: "claude-opus-4-1-20250805",
        name: "Claude Opus 4.1",
        costs: nil,
        configuration: .anthropicConfiguration
    )
    
    public static let anthropicOpus4 = RemoteLLMModel(
        provider: .anthropic,
        id: "claude-opus-4-20250514",
        name: "Claude Opus 4",
        costs: nil,
        configuration: .anthropicConfiguration
    )
    
    public static let anthropicSonnet4 = RemoteLLMModel(
        provider: .anthropic,
        id: "claude-sonnet-4-20250514",
        name: "Claude Sonnet 4",
        costs: nil,
        configuration: .anthropicConfiguration
    )
    
    public static let anthropicSonnet37 = RemoteLLMModel(
        provider: .anthropic,
        id: "claude-3-7-sonnet-20250219",
        name: "Claude Sonnet 3.7",
        costs: nil,
        configuration: .anthropicConfiguration
    )
    
    public static let anthropicSonnet35New = RemoteLLMModel(
        provider: .anthropic,
        id: "claude-3-5-sonnet-20241022",
        name: "Claude Sonnet 3.5",
        costs: nil,
        configuration: .anthropicConfiguration
    )
    
    public static let anthropicHaiku35 = RemoteLLMModel(
        provider: .anthropic,
        id: "claude-3-5-haiku-20241022",
        name: "Claude Haiku 3.5",
        costs: nil,
        configuration: .anthropicConfiguration
    )
    
    public static let inceptionMercury = RemoteLLMModel(provider: .inception, id: "mercury", name: "Mercury", costs: .zero, configuration: .noImageSupportConfig)
    public static let inceptionMercury2 = RemoteLLMModel(provider: .inception, id: "mercury-2", name: "Mercury 2", costs: .zero, configuration: .inceptionConfiguration)
    
    // Convenience array containing all Anthropic models
    // Anthropic https://docs.anthropic.com/en/docs/about-claude/models
    public static let allAnthropicModels: [RemoteLLMModel] = [
        anthropicOpus41,
        anthropicOpus4,
        anthropicSonnet4,
        anthropicSonnet37,
        anthropicSonnet35New,
        anthropicHaiku35
    ]
    
    
    public static let allKnown = {
        var allLLMs: [RemoteLLMModel] = [

            .init(provider: .xAI, id: "grok-3", name: "Grok 3",  costs: ModelCosts(inputTokenCost: Double(3/1E6), outputTokenCost: Double(15/1E6)), configuration: .noImageSupportConfig),
            .init(provider: .xAI, id: "grok-3-mini", name: "Grok 3 Mini", costs: ModelCosts(inputTokenCost: Double(0.3/1E6), outputTokenCost: Double(0.5/1E6)), configuration: .noImageSupportConfig),
            
            // OpenAI https://openai.com/api/pricing/
            gpt5,
            gpt5Mini,
            gpt5Nano,
            
            gpt4o,
            gpt4oMini,
            
            .init(provider: .openAI, id: "gpt-4", name: "ChatGPT 4", costs: ModelCosts(inputTokenCost: Double(30/1E6), outputTokenCost: Double(60/1E6)), configuration: .noImageSupportConfig),
            .init(provider: .openAI, id: "gpt-3.5-turbo", name: "ChatGPT 3.5 Turbo", costs: ModelCosts(inputTokenCost: Double(0.50/1E6), outputTokenCost: Double(1.50/1E6)), configuration: .noImageSupportConfig),
            
            inceptionMercury,
            inceptionMercury2
        ]
        
        allLLMs.append(contentsOf: allAnthropicModels)
#if DEBUG
        allLLMs.append(.init(provider: .testModel, id: "invalid", name: "Invalid", costs: ModelCosts.zero, configuration: .default))
#endif
        
        return allLLMs
    }()
}
