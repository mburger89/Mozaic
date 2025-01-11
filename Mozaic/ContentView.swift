//
//  ContentView.swift
//  Mozaic
//
//  Created by Max Burger on 5/16/24.
//

import SwiftUI
import SwiftData

struct ContentView: View {

    var body: some View {
        mozaicMain().environment(ProjectModel())
    }
}

#Preview {
    ContentView()
}
