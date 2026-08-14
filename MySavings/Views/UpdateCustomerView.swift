//
//  UpdateCustomerView.swift
//  Invoice_ One-Many
//
//  Created by Terje Moe on 06/12/2025.
//

import SwiftUI
import SwiftData

struct UpdateCustomerView: View {
    @Environment(\.dismiss) var dismiss
    @State var selectedCustomer: Customer?
    @Query(sort: \Customer.title, order: .forward) private var customers: [Customer]
    @Bindable var customer: Customer
    @State private var title = ""
    @AppStorage("darkModeEnambled") private var darkModeEnabled = false
    
    var body: some View {
        List {
            Section("Klient") {
                TextField("Navn", text: $title)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.sentences)
            }
            Image("BusinessMan")
                .resizable()
                .scaledToFit()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction){
                Button("Ferdig") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            ToolbarItem(placement: .topBarTrailing){
                Button("Oppdater") {
                    customer.title = title
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(customer.title == title)
            }
        }
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
        .onAppear() {
            // Laster inn verdier til variablene fra databasen når vi åpner listen
            self.title = customer.title
        }
        .navigationTitle("Oppdater Klient")
    }
}
