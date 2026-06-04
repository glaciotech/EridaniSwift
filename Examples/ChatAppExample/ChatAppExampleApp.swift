//
//  ChatAppExampleApp.swift
//  ChatAppExample
//
//  Created by Peter Liddle on 5/20/26.
//

import SwiftUI

@main
struct ChatAppExampleApp: App {
    
    @StateObject var chatState = ChatState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(chatState)
        }
    }
}
