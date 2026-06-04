//
//  LocalMCPServerConfig.swift
//  MCPHelpers
//
//  Created by Peter Liddle on 11/24/25.
//
import Foundation

public struct LocalMCPServerConfig: Codable {
    public var name: String
    public var executablePath: String
    public var arguments: [String]
    public var environment: [String: String]
    
    public init(name: String, executablePath: String, arguments: [String] = [], environment: [String: String] = [:]) {
        self.name = name
        self.executablePath = executablePath
        self.arguments = arguments
        self.environment = environment
    }
}
