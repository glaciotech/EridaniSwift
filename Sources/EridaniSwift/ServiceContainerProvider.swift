//
//  ServiceContainerProvider.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 5/9/26.
//

import Foundation

public class EridaniProxyFactory {
    
    private static let defaultProxyBaseUrl = "https://ventusai-proxy.glacio.tech"
    
    private static let ventusAIProxyBase = {
        if UserDefaults.standard.bool(forKey: "USE_LOCAL_SERVER") {
            return "http://localhost:8080"
        }
        else {
            return EridaniProxyFactory.defaultProxyBaseUrl
        }
    }()
    
    private static let proxiedLLMRequestEndpoint = ventusAIProxyBase + "/api/proxy"
    
    /// Convenience method which autoresolves proxy container creation based on environment variables
    /// - Returns: Returns a configured proxied remote service container
    public static func createProxiedAIContainer() async throws -> ProxiedRemoteLLMServiceContainer {
        
        if let appApiKey = UserDefaults.standard.string(forKey: "ERIDANI_PROXY_APP_API_KEY") {
            return try await createProxiedAIContainer(with: appApiKey)
        }
        
        // If we got here no environment variables where set
        fatalError("""
                        You need to provide an API_KEY 'ERIDANI_PROXY_APP_API_KEY' in the scheme as a launch or environment variable, to use this initalizer.
                        \n If you want to use the Eridani proxy (typically for production releases), contact us at proxy-inquiry@eridani.tech
                        """)
    }
    
    /// Convenience method for creating an AI container that auto resolves the remote AI service and routes traffic through the proxy
    /// - Parameters:
    ///   - email: Login email address for proxy
    ///   - password: Password for proxy
    /// - Returns: Returns a configured proxied remote service container
    public static func createProxiedAIContainer(with appApiKey: String) async throws -> ProxiedRemoteLLMServiceContainer {
        
        let keyedProxyEndpoint = ventusAIProxyBase + "/apikey/api/proxy"
        return ProxiedRemoteLLMServiceContainer(withProxy: .init(authToken: .init(accessToken: "", refreshToken: "", expiresAt: .infinity), proxyUrl: keyedProxyEndpoint, proxyAppApiKey: appApiKey), sessionRefreshHandler: AppAPIKeySessionHandler())
    }
}

fileprivate struct AppAPIKeySessionHandler: ProxySessionHandler {
    
    private let validSession = AuthSession(proxyAuthToken: .init(accessToken: "", refreshToken: "", expiresAt: .infinity), userId: UUID())
    
    func currentSession() async throws -> AuthSession {
        return validSession
    }
    
    func refresh() async throws {
        // Do nothing
    }
    
    func createAccount(email: String, password: String) async throws -> AuthSession {
        // Not applicable
        return validSession
    }
    
    func signIn(email: String, password: String) async throws -> AuthSession {
        return validSession
    }
    
    func signIn(withApple identityToken: Data) async throws -> AuthSession {
        return validSession
    }
    
    func signOut() async throws {
        // Do nothing
    }
    
    var userLoggedIn: Bool = true
}
