//
//  MySavingsApp.swift
//  MySavings
//  New GitIgnor nå
//  Created by Terje Moe on 08/12/2025.
//  Denne bruker iCloude
//  Oppdatert med ny Github 01.01.2026

import SwiftUI
import SwiftData

@main
struct MySavingsApp: App {
    @StateObject var model = AppModel()
    var body: some Scene {
        WindowGroup {
            FirstView()
            .environmentObject(model)
            .modelContainer(for: Invoice.self)
     }
  }
 
  init() {
      print(URL.applicationSupportDirectory.path(percentEncoded: false))
  }
}
