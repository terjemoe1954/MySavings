//
//  CreateInvoiceView.swift
//  Invoice_ One-Many
//
//  Created by Terje Moe on 04/12/2025.

import SwiftUI
import SwiftData

struct CreateInvoiceView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Query private var invoices: [Invoice]
    @Query private var customers: [Customer]
    @State private var invoice = Invoice()
    @State private var selectedCustomer: Customer?
    @State private var title = ""
    @State private var amount: Double = 0.0
    @State private var dueDate = Date()
    @State private var paidDate = Date()
    @State private var selectedType: TransactionType = .expense
    @State private var selectedState: TransactionState = .pending
    @State private var isPaid: Bool = false
    @State private var interval = 0
    @AppStorage("filterMinimum") var filterMinimum = 1.0
    @AppStorage("darkModeEnambled") private var darkModeEnabled = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Bilag For:"){
                    TextField("Navn", text: $title)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.sentences)
                }
                
                Section("Detaljer"){
                    HStack{
                        Text("Beløp:")
                        TextField("Beløp", value: $amount, formatter: numberFormatter)
                            .keyboardType(.decimalPad)
                    }
                    .onChange(of: amount) { oldValue, newValue in
                        if newValue < filterMinimum {
                            amount = filterMinimum
                        }
                    }
                    
                    DatePicker("Forfallsdato:", selection: $dueDate, displayedComponents: .date)
                    DatePicker("Belalt Dato:", selection: $paidDate, displayedComponents: .date)
                    
                    // Picker for Expense / Income
                    Picker("Velg Type", selection: $selectedType) {
                        ForEach(TransactionType.allCases.dropLast()) { transactionType in
                            Text(transactionType.title)
                                .tag(transactionType)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 50)
                    
                    // Picker for Pending / Payed / Recieved / Taken
                    Picker("Velg Type", selection: $selectedState) {
                        ForEach(TransactionState.allCases.dropLast()) { transactionState in
                            Text(transactionState.title)
                                .tag(transactionState)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    HStack{
                        Text("Intervall i måneder:")
                        TextField("Intervall", value: $interval,formatter: intFormatter)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section {
                    Picker("Velg en Klient", selection: $selectedCustomer){
                        ForEach(customers.sorted { $0.title < $1.title }) { customer in
                            Text(customer.title)
                                .tag(customer as Customer?)
                        }
                        .labelsHidden()
                        .pickerStyle(.inline)
                        Text("Ingen")
                            .tag(nil as Customer?)
                    }
                }
            }
            .navigationTitle("Opprett Bilag")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing){
                    Button("Opprett"){
                        save()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.isEmpty || amount < filterMinimum || selectedCustomer == nil)
                }
            }
        }
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
    }
}

#Preview {
    CreateInvoiceView()
        .modelContainer(for: Invoice.self)
}

extension CreateInvoiceView {
    
    func save() {
        // Lagrer verdiene til databasen og oppdaterer relasjon
        if selectedType == .income && (selectedState == .paid || selectedState == .taken) {
            selectedState = .resieved
        }
        
        if selectedType == .expense && selectedState == .resieved {
            selectedState = .paid
        }
        invoice.title = title
        invoice.type = selectedType
        invoice.state = selectedState
        invoice.amount = amount
        invoice.dueDate = dueDate
        invoice.paidDate = paidDate
        invoice.isPaid = isPaid
        invoice.interval = interval
        modelContext.insert(invoice)
        invoice.customer = selectedCustomer
        selectedCustomer?.invoices?.append(invoice)
        try? modelContext.save()
    }
}
