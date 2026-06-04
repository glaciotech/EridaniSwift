//
//  ToolCallView.swift
//  EridaniToolCallExample
//
//  Created by Peter Liddle on 5/9/26.
//

import SwiftUI
import EridaniSwift
import MCP
import SwiftyPrompts

struct ToolCallView: View {
    
    @EnvironmentObject var toolCallState: ToolCallState
    @State var inputText: String = ""
    @State var areToolsShowing = false
    
    var body: some View {
        VStack {
            Button(areToolsShowing ? "Hide Tools" : "Show Tools" ) {
                areToolsShowing.toggle()
            }
            
            HStack {
                
                ChatInteractionView()
                
                if areToolsShowing {
                    let availableTools = toolCallState.tm.availableTools
                    if !availableTools.isEmpty {
                        List(Array(availableTools.keys), id: \.self) { toolInfo in
                            Text(toolInfo.fullName)
                        }
                    }
                    else {
                        Text("No tools loaded")
                    }
                }
            }
        }
        .alert("Approve Tool Call", isPresented: Binding(get: { toolCallState.pendingToolApprovalRequest != nil }, set: {_ in }), presenting: toolCallState.pendingToolApprovalRequest) { request in
            Button("Allow") {
                toolCallState.pendingToolApprovalRequest = nil
                Task {
                    toolCallState.toolApprovalCoordinator.submitDecision(id: request.id, decision: .allow)
                }
            }
            Button("Deny", role: .cancel) {
                toolCallState.pendingToolApprovalRequest = nil
                Task {
                    toolCallState.toolApprovalCoordinator.submitDecision(id: request.id, decision: .deny)
                }
            }
        } message: { request in
            let server = request.serverName ?? "Unknown server"
            let args = request.arguments.map { String(describing: $0) } ?? "(no arguments)"
            Text("Server: \(server)\nTool: \(request.toolName)\nArguments: \(args)")
        }
        
        .task {
            do {
                try await toolCallState.loadTools()
            }
            catch {
                Log.error("Error loading tools: \(error.localizedDescription)")
            }
        }
    }
    
    func ChatInteractionView() -> some View {
        VStack {
            List(toolCallState.chatMessages) { msg in
                HStack {
                    VStack {
                        Text(msg.role)
                            .padding(.horizontal, 10)
                            .fontWeight(.bold)
                            .frame(width: 60)
                        Text(msg.tokens, format: .number)
                            .font(.caption)
                    }
                    Text(msg.output)
                        .padding(.trailing, 10)
                        .foregroundStyle(msg.isError ? Color.red : Color.black)
                }
            }
            HStack {
                if toolCallState.isAsking {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
                else {
                    TextField("Ask anything here", text: $inputText)
                    Button("Ask") {
                        Task {
                            await toolCallState.ask(input: inputText)
                            inputText = ""
                        }
                    }
                }
            }
            if let errorMsg = toolCallState.displayableError {
                Text(errorMsg)
                    .font(.subheadline)
                    .padding(10)
            }
        }
    }
}

#Preview {
    ToolCallView()
}
