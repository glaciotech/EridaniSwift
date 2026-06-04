//
//  ToolUsingAgentExampleApp.swift
//  ToolUsingAgentExample
//
//  Created by Peter Liddle on 5/20/26.
//

import SwiftUI

@main
struct ToolUsingAgentExampleApp: App {
    
    @StateObject var toolCallState = ToolCallState()
     
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(toolCallState)
        }
    }
}
