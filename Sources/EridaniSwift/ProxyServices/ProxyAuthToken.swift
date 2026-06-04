//
//  ProxyAuthToken.swift
//  VentusAI
//
//  Created by Peter Liddle on 6/5/25.
//

import Foundation

public struct ProxyAuthToken: Codable {
    
    private let defaultExpiryMargin: TimeInterval
    
    public var accessToken: String
    public var refreshToken: String

    /// UNIX timestamp after which the ``Session/accessToken`` should be renewed by using the refresh
    /// token with the `refresh_token` grant type.
    public var expiresAt: TimeInterval

    /// Returns `true` if the token is expired or will expire in the next 30 seconds.
    ///
    /// The 30 second buffer is to account for latency issues.
    public var isExpired: Bool {
      let expiresAt = Date(timeIntervalSince1970: expiresAt)
      return expiresAt.timeIntervalSinceNow < defaultExpiryMargin
    }
    
    
    /// <#Description#>
    /// - Parameters:
    ///   - accessToken: <#accessToken description#>
    ///   - refreshToken: <#refreshToken description#>
    ///   - expiresAt: <#expiresAt description#>
    ///   - defaultExpiryMargin: This is set as 30sec by default which is what Supabase dictates in Supabase.Session
    public init(accessToken: String, refreshToken: String, expiresAt: TimeInterval, defaultExpiryMargin: TimeInterval = 30) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.defaultExpiryMargin = defaultExpiryMargin
    }
}
