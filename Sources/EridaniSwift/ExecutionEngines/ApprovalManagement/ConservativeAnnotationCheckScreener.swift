//
//  ConservativeAnnotationCheckScreener.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 5/15/26.
//

import MCP
import SwiftyPrompts

public protocol RequiresApprovalScreener {
    func requiresApproval(for tool: MCP.Tool) -> Bool
}


/// Will require approval for any MCP that is likely to alter data or interact with the outside world
public struct ConservativeAnnotationCheckScreener: RequiresApprovalScreener {
    
    public init() {}
    
    public func requiresApproval(for tool: MCP.Tool) -> Bool {
        
        if tool.annotations.readOnlyHint == false || tool.annotations.destructiveHint == true || tool.annotations.openWorldHint == true {
            return true
        }
        
        return false
    }
}
