//
//  AutoToolApproveCoordinator.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 5/15/26.
//

import MCP
import SwiftyPrompts

class AutoToolApproveCoordinator: ToolCallAuthorizer {
    
    var autoApproveList = [String]()
    var autoDenyList = [String]()
    
    var followOnApprover: ToolCallAuthorizer?
    
    init(autoApproveList: [String] = [String](), autoDenyList: [String] = [String](), followOnApprover: ToolCallAuthorizer?) {
        self.autoApproveList = autoApproveList
        self.autoDenyList = autoDenyList
        self.followOnApprover = followOnApprover
    }
    
    func authorize(_ toolCall: MCPToolCallRequest) async throws {
        if autoApproveList.contains(toolCall.toolName) {
            return
        }
        else if autoDenyList.contains(toolCall.toolName) {
            throw ToolApprovalError.denied("On deny list")
        }
        else {
            // Forward to chained approver if setup
            try await followOnApprover?.authorize(toolCall)
        }
    }
}
