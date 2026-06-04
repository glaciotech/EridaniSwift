//
//  OpenAIProxiedRequestHandler.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 10/8/25.
//
import Foundation
import OpenAIKit

class OpenAIProxiedRequestHandler: BaseProxyHandler, DelegatedRequestHandler {
    
    var configuration: OpenAIKit.Configuration = Configuration(apiKey: "NA") // This isn't used for the proxy request

    override init(proxyDetails: ProxyAPIDetails, sessionRefreshHandler: ProxySessionHandler) {
        super.init(proxyDetails: proxyDetails, sessionRefreshHandler: sessionRefreshHandler)
    }
    
    func perform<T>(request: OpenAIKit.DelegatedRequest) async throws -> T where T : Decodable {
        
        decoder.keyDecodingStrategy = request.keyDecodingStrategy
        decoder.dateDecodingStrategy = request.dateDecodingStrategy
        
        let fullUrl = proxyUrl.appending(path: request.path)
        
        var urlRequest = URLRequest(url: fullUrl)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        
        let session = URLSession.init(configuration: try await config)
        let (data, response) = try await session.data(for: urlRequest)
        
        do {
            let object = try decoder.decode(T.self, from: data)
            return object
        }
        catch {
            guard let proxyError = try extractProxyError(data: data) else {
                throw error
            }
            if case ProxyError.tokenExpired = proxyError {
                try await sessionRefreshHandler.refresh()
                // Call self to retry
                if retryCount < Self.maxRetries {
                    
                    retryCount += 1
                    
                    let result: T = try await self.perform(request: request)
                    
                    // Reset retry count on success
                    retryCount = 0
                    
                    return result
                }
                else {
                    throw ProxyError.serverError(error, "Retries failed, please try again later")
                }
            }
            else {
                throw proxyError
            }
        }
    }
    
    func stream<T>(request: OpenAIKit.DelegatedRequest) async throws -> AsyncThrowingStream<T, any Error> where T : Decodable {
        
        decoder.keyDecodingStrategy = request.keyDecodingStrategy
        decoder.dateDecodingStrategy = request.dateDecodingStrategy
        
        var urlRequest = URLRequest(url: proxyUrl)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        
        let session = URLSession.init(configuration: try await config)
        let (data, response) = try await session.data(for: urlRequest)
        
        let object = try decoder.decode(T.self, from: data)
        return .init {
            object
        }
    }
}
