//
//  ChatView.swift
//  EridaniExampleSwiftUIChatApp
//
//  Created by Peter Liddle on 12/5/25.
//

import SwiftUI
import EridaniSwift

extension String: @retroactive Identifiable {
    public var id: String {
        return self
    }
}

struct ChatView: View {
    
    @EnvironmentObject var chatState: ChatState
    @State var inputText: String = ""
    
    var body: some View {
        VStack {
            List(chatState.chatMessages) { msg in
                HStack {
                    Text(msg.role)
                        .padding(.horizontal, 10)
                        .fontWeight(.bold)
                        .frame(width: 60)
                    Text(msg.output)
                        .padding(.trailing, 10)
                        .foregroundStyle(msg.isError ? Color.red : Color.black)
                }
                
            }
            HStack {
                if chatState.isAsking {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
                else {
                    TextField("Ask anything here", text: $inputText)
                    Button("Ask") {
                        Task {
                            await chatState.ask(input: inputText)
                            inputText = ""
                        }
                    }
                }
            }
            if let errorMsg = chatState.displayableError {
                Text(errorMsg)
                    .font(.subheadline)
                    .padding(10)
            }
        }
    }
}

#Preview {
    ChatView()
}
