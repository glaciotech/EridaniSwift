//
//  SimpleError.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 10/7/25.
//
import Foundation

public enum SimpleError: Error, LocalizedError {
    case message(String)
    
    public var errorDescription: String? {
        switch self {
        case .message(let msg):
            return msg
        }
    }
}
