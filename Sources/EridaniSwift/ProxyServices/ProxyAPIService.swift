//
//  ProxyAPIServices.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 11/8/25.
//

import Foundation

// Models
extension ProxyAPIService {
    
    public struct CreditPackResponse: Codable {
        public let productId: String
        public let title: String
        public let description: String
        public let tokens: Int
        public let additionalInfo: [String: String]
        // Pricing information (amount, currency, trials, etc.) must always be
        // sourced from Adapty / StoreKit on the client side to ensure it is
        // accurate for the user's storefront. Do not add price or currency
        // fields here.
    }
    
    public struct TokenBalanceResponse: Codable {
        public let balance: Int
        public let userId: String
    }
    
    private struct ProxyErrorResponse: Codable {
        let error: Bool?
        let reason: String?
    }
    
    
    struct LLMPricingSnapshot: Codable {
        
        struct Provider: Codable {
            
            struct Model: Codable {
                
                struct TokenPricing: Codable {
                    let currency = "USD"
                    let inputPricePerMillionTokens: Double
                    let outputPricePerMillionTokens: Double
                }
                
                struct UniversalTokenMapping: Codable {
                    let inputTokensPerUniversalToken: Double
                    let outputTokensPerUniversalToken: Double
                }
                
                let id: String
                let displayName: String
                let tokenPricing: TokenPricing
                let universalTokenMapping: UniversalTokenMapping
            }
            
            let id: String
            let displayName: String
            let pricingUrl: String
            let models: [Model]
        }
        
        struct UniversalTokenConfig: Codable {
            let currency: String
            let pricePerUniversalToken: Double
            let providerCostShare: Double
        }

        let version: String
        let currency: String
        let createdAt: String
        let providers: [Provider]
        let universalToken: UniversalTokenConfig
        
        let suggestedModel: String?
        let cheapestModel: String?
    }
}

public struct ModelSuggestions {
    public var cheapestModel: RemoteLLMModel?
    public var suggestedModel: RemoteLLMModel?
}

public class ProxyAPIService {
    
    let decoder = JSONDecoder()
    
    let url: URL
    let sessionManager: ProxySessionHandler
    
    static let balanceEndpoint: String = "/tokens/balance"
    static let creditPacksEndpoint: String = "/store/credit-packs"
    static let cloudPricingEndpoint: String = "/llm/pricing"
    static let availablePricingEndpoint: String = "/llm/available-pricing"

    public init(proxyAPIUrl: URL, sessionManager: ProxySessionHandler) {
        self.url = proxyAPIUrl
        self.sessionManager = sessionManager
    }
    
    private func authorizedRequest(for url: URL) async throws -> URLRequest {
        let accessToken = try await sessionManager.currentSession().proxyAuthToken.accessToken
        
        // Create the request with Bearer token authentication
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        return request
    }
    
    public func fetchTokenBalance() async throws -> TokenBalanceResponse {
        
        let balanceEndpoint = url.appendingPathComponent(Self.balanceEndpoint, conformingTo: .url)
        
        let request = try await authorizedRequest(for: balanceEndpoint)
        
        // Make the API call
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check for HTTP errors
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SimpleError.message("Invalid response from token balance API")
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? decoder.decode(ProxyErrorResponse.self, from: data), let reason = errorResponse.reason {
                throw SimpleError.message(reason)
            }
            throw SimpleError.message("Token balance API returned status code: \(httpResponse.statusCode)")
        }

        let balanceResponse = try decoder.decode(TokenBalanceResponse.self, from: data)
        return balanceResponse
    }

    public func fetchCreditPackProducts() async throws -> [CreditPackResponse] {
        
        let productsEndpoint = url.appendingPathComponent(Self.creditPacksEndpoint, conformingTo: .url)

        let request = try await authorizedRequest(for: productsEndpoint)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SimpleError.message("Invalid response from token products API")
        }

        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? decoder.decode(ProxyErrorResponse.self, from: data), let reason = errorResponse.reason {
                throw SimpleError.message(reason)
            }
            throw SimpleError.message("Token products API returned status code: \(httpResponse.statusCode)")
        }

        let products = try decoder.decode([CreditPackResponse].self, from: data)
        return products
    }
    
    public func fetchAvailableCloudLLMModels() async throws -> ([RemoteLLMModel], ModelSuggestions) {
        
        // We fetch from the pricing as this should contain the latest available models + pricing
        let pricingEndpoint = url.appendingPathComponent(Self.availablePricingEndpoint, conformingTo: .url)
        
        let request = try await authorizedRequest(for: pricingEndpoint)
        
        // Make the API call
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check for HTTP errors
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SimpleError.message("Invalid response from token balance API")
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? decoder.decode(ProxyErrorResponse.self, from: data), let reason = errorResponse.reason {
                throw SimpleError.message(reason)
            }
            throw SimpleError.message("Token balance API returned status code: \(httpResponse.statusCode)")
        }

        let pricingSnapshot = try decoder.decode(LLMPricingSnapshot.self, from: data)
        
        var suggestedModels = ModelSuggestions()
        
        let remoteModels: [RemoteLLMModel] = pricingSnapshot.providers.reduce(into: [RemoteLLMModel](), { models, provider in
            
            guard let resolvedProvider = RemoteLLMModel.Provider(rawValue: provider.id) else { return }
            
            provider.models.forEach { model in
                let inputCost = model.universalTokenMapping.inputTokensPerUniversalToken
                let outputCost = model.universalTokenMapping.outputTokensPerUniversalToken
                
                let costs = ModelCosts(
                    inputTokenCost: inputCost,
                    outputTokenCost: outputCost
                )
                
                let model = RemoteLLMModel(
                    provider: resolvedProvider,
                    id: model.id,
                    name: model.displayName,
                    costs: costs,
                    configuration: .default
                )
                
                if model.id == pricingSnapshot.cheapestModel {
                    suggestedModels.cheapestModel = model
                }
                
                if model.id == pricingSnapshot.suggestedModel {
                    suggestedModels.suggestedModel = model
                }
                
                models.append(model)
            }
        })
        
        return (remoteModels, suggestedModels)
    }
}
