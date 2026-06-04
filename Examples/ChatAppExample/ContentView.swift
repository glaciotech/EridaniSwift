//
//  ContentView.swift
//  EridaniExampleSwiftUIChatApp
//
//  Created by Peter Liddle on 12/5/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Welcome to the Eridani Example Chat App")
                .padding(10)
            ChatView()
                .padding()
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
