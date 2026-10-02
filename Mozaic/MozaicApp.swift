//
//  MozaicApp.swift
//  Mozaic
//
//  Created by Max Burger on 5/16/24.
//

import SwiftUI

@main
struct MozaicApp: App {
	var body: some Scene {
		DocumentGroup(newDocument: { MozaicDocument() }) { configuration in
			ContentView(document: configuration.document)
		}
	}
}
