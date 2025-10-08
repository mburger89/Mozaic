//
//  MozaicApp.swift
//  Mozaic
//
//  Created by Max Burger on 5/16/24.
//

import SwiftUI
import SwiftData

@main
struct MozaicApp: App {
	var sharedModelContainer: ModelContainer = {
		let schema = Schema([
			MDataModel.self,
		])
		let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

		do {
			return try ModelContainer(for: schema, configurations: [modelConfiguration])
		} catch {
			fatalError("Could not create ModelContainer: \(error)")
		}
	}()

    var body: some Scene {
        WindowGroup {
			ContentView()
				.modelContainer(sharedModelContainer)
//			#if os(macOS)
//				.frame(minWidth: 1300)
//			#endif
        }
    }
}

