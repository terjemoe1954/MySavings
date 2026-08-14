//
//  SettingsView.swift
//  Income
//
//  Created by Terje Moe on 09/11/2025.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var name: String
    @Binding var darkModeEnabled: Bool
    @Binding var showName: Bool
    @Binding var showStatus: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Display"),
                        footer: Text("")) {
                    Toggle(isOn: $darkModeEnabled) {
                        Text(!darkModeEnabled ? "Dag modus" : "Natt modus")
                    }
                    
                    Toggle(isOn: $showName) {
                        Text(!showName ? "Skjult bruker navn" : "Vist bruker navn")
                    }
                    HStack {
                        Text("Ditt Navn:          ")
                        TextField("Navn:", text: $name)
                    }
                    
                    Toggle(isOn: $showStatus) {
                        Text(!showStatus ? "Tillat endring av Status (Av)" : "Tillat endring av Status (På)")
                    }
                    .foregroundStyle(.red)
                    
                }
                Section {
                    Link(destination: URL(string: Constants.web)!,
                         label: {
                        Label("Les VG", systemImage: "globe")
                    })
                    HStack {
                        Image(systemName: "envelope")
                        Link("Kontakt meg via mail",
                             destination: URL(string: Constants.email)!)
                    }
                    HStack {
                        Image(systemName: "phone")
                        Link("Ring meg",
                             destination: URL(string: Constants.phone)!)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction){
                    Button("Ferdig") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .foregroundStyle(darkModeEnabled ? Color.white : Color.black)
            .font(.system(size: 16, weight: .semibold))
            .navigationTitle("Instillinger")
        }
        
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
    }
    
}

#Preview {
    SettingsView(name: .constant("Tomle Hue"), darkModeEnabled: .constant(false), showName: .constant(false), showStatus: .constant(false))
}

