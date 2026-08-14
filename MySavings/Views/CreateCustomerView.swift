//
//  ContentView.swift
//  Invoice_ One-Many
//
//  Created by Terje Moe on 03/12/2025.
//

import SwiftUI
import SwiftData

struct CreateCustomerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Customer.title, order: .forward) private var customers: [Customer]
    @AppStorage("darkModeEnambled") private var darkModeEnabled = false
    @State private var title: String = ""
    @State private var customerToEdit: Customer?
    @State private var customerToDelete: Customer?
    @State private var showConfirmation: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                Image(systemName: "person.3.fill")
                    .background(.white)
                    .foregroundStyle(.blue)
                    .font(Font.largeTitle.bold())
                    .clipShape(.capsule)
                Section("Klient: ") {
                    TextField("Klient Navn", text: $title)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.sentences)
                    
                    Button("Opprett Klient") {
                        withAnimation{
                            let customer = Customer(title: title)
                            modelContext.insert(customer)
                            customer.invoices = []
                            title = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.isEmpty)
                }
                
                Section("Klienter") {
                    ForEach(customers) { customer in
                        Text(customer.title)
                            .swipeActions {
                                Button(role: .destructive){
                                    customerToDelete = customer
                                    showConfirmation.toggle()
                                } label: {
                                    Label("Slett" , systemImage: "trash.fill")
                                }
                            }
                            .onTapGesture {
                                customerToEdit = customer
                            }
                    }
                    .confirmationDialog(
                        "Slett",
                        isPresented: $showConfirmation,
                        titleVisibility: .visible,
                        presenting: customerToDelete ,
                        actions: { item in
                            Button(role: .destructive) {
                                withAnimation {
                                    modelContext.delete(item)
                                    try? modelContext.save()
                                }
                            } label: {
                                Text("Slett")
                            }
                            Button(role: .confirm) {
                                
                            } label: {
                                Text("Avslut")
                            }
                        },
                        message: { item in
                            Text("Alle poster registrert på \(item.title) Blir også Slettet")
                    })
                }
            }
            .navigationTitle("Opprett Klient")
            .sheet(item: $customerToEdit,
                   onDismiss: {
                customerToEdit = nil
            },
                   content: { editCustomer in
                NavigationStack {
                    UpdateCustomerView(customer: editCustomer)
                }
                .interactiveDismissDisabled()
            })
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Ferdig") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
    }
}

#Preview {
    CreateCustomerView()
}
