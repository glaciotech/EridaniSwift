//
//  SessionRefreshHandler.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 6/18/25.
//

import Foundation


/// Authentication Sesison object used to abstract underlying auth process
public struct AuthSession {
    public var proxyAuthToken: ProxyAuthToken
    public var userId: UUID
    public var email: String?
    
    public init(proxyAuthToken: ProxyAuthToken, userId: UUID, email: String? = nil) {
        self.proxyAuthToken = proxyAuthToken
        self.userId = userId
        self.email = email
    }
}

public protocol ProxySessionHandler {
    func currentSession() async throws -> AuthSession
    func refresh() async throws -> Void
    
    func createAccount(email: String, password: String) async throws -> AuthSession
    
    func signIn(email: String, password: String) async throws -> AuthSession
    func signIn(withApple identityToken: Data) async throws -> AuthSession
    
    func signOut() async throws
        
    var userLoggedIn: Bool { get async }
}
