//
//  ContentView.swift
//  EridaniToolCallExample
//
//  Created by Peter Liddle on 5/9/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Welcome to the Eridani Tool Using Agent Example")
                .font(.headline)
                .padding(10)
            ToolCallView()
                .padding(10)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
