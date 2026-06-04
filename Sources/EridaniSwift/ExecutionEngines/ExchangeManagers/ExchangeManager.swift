//
//  ExchangeManager.swift
//  _EridaniSwiftSDK
//
//  Created by Peter Liddle on 9/11/25.
//

public protocol ExchangeManagerProtocol {
    
    associatedtype IC
    associatedtype ESS: ExchangeStoreServiceProtocol
    
    var storageService: ESS { get set }
    
    func ask(with input: IC) async throws
}
