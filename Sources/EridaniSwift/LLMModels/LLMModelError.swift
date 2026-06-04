//
//  LLMModelError.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 8/15/25.
//

import Foundation

enum LLMModelError: Error, LocalizedError {
    case modelIdConflict
    case noModelMatchingId(String)
    case modelNameConflict
    case noModelMatchingFullName(String)
    case notAValidModelFullName(String)
    
    var errorDescription: String? {
        switch self {
        case .modelIdConflict: "Model id returns multiple models, can't be correct"
        case .noModelMatchingId(let id): "There is no model that matches this id: \(id)"
        case .noModelMatchingFullName(let name): "There is no model that matches this fullname: \(name)"
        case .modelNameConflict: "Multiple models match this name, please try the id to uniquely identify"
        case .notAValidModelFullName(let name): "This doesn't appear to be a valie model fullname: \(name)"
        }
    }
}
