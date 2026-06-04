//
//  BaseProxyHandler.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 10/8/25.
//
import Foundation

class BaseProxyHandler {
    
    internal static let maxRetries = 3
    internal let decoder: JSONDecoder = JSONDecoder()
    
    enum ProxyError: Error, LocalizedError {
        case serverError(Error?, String)
        case tokenExpired
        
        var errorDescription: String? {
            switch self {
            case .serverError(let underlyingError, let message):
                return message
            case .tokenExpired:
                return "Token has expired, login again"
            }
        }
    }
    
    struct ServerError: Codable, Error {
        var error: Bool = false
        var reason: String = ""
    }
    
    struct ProxyAPIDetails {
        var proxyUrl: URL
        var appAPIKey: String
    }
    
    internal var retryCount = 0  // This is used to stop endless loops when we need to retry
    
    
    internal var proxyUrl: URL {
        return proxyDetails.proxyUrl
    }
    
    internal let proxyDetails: ProxyAPIDetails
    
    internal var sessionRefreshHandler: ProxySessionHandler
    
    internal var config: URLSessionConfiguration {
        get async throws {
            let config = URLSessionConfiguration.default
            let accessToken = try await sessionRefreshHandler.currentSession().proxyAuthToken.accessToken
            config.httpAdditionalHeaders = [
                "Authorization": "Bearer \(accessToken)",
                "X-ProxyApp-Api-Key": proxyDetails.appAPIKey,
                "Content-Type": "application/json"
            ]
            return config
        }
    }
    
    init(proxyDetails: ProxyAPIDetails, sessionRefreshHandler: ProxySessionHandler) {
        self.proxyDetails = proxyDetails
        self.sessionRefreshHandler = sessionRefreshHandler
    }
    
    func extractProxyError(data: Data) throws -> ProxyError? {
        // Check for a proxy error
        guard let proxyError = try? decoder.decode(ServerError.self, from: data) else {
            return ProxyError.serverError(nil, "An error occured on the server. Try again later")
        }
        if proxyError.error, proxyError.reason.contains("token is expired") {
            return ProxyError.tokenExpired
        }
        
        return ProxyError.serverError(nil, proxyError.reason)
    }
}
