//
//  UpdateToDoView.swift
//  ToDos
//
//  Created by Tunde Adegoroye on 08/06/2023.
//

import SwiftUI
import SwiftData

struct UpdateInvoiceView: View {
    @Environment(\.dismiss) var dismiss
    @State var selectedCustomer: Customer?
    @Query(sort: \Customer.title, order: .forward) private var customers: [Customer]
    @Bindable var invoice: Invoice
    @State private var amount = 0.0
    @State private var title = ""
    @State private var type = TransactionType.expense
    @State private var state: TransactionState = .pending
    @State private var dueDate: Date = Date()
    @State private var paidDate: Date = Date()
    @State private var isPaid: Bool = false
    @State private var selectedType: TransactionType = .expense
    @State private var selectedState: TransactionState = .pending
    @State private var interval = 0
    @State private var progress = 0
    @AppStorage("filterMinimum") var filterMinimum = 1.0
    @AppStorage("darkModeEnambled") private var darkModeEnabled = false
    @AppStorage("ShowStatus") private var showStatus = false
    
    var body: some View {
        
        NavigationStack {
            List {
                Section("Bilag For") {
                    TextField("Navn", text: $title)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.sentences)
                }
                
                Section {
                    DatePicker("Forfallsdato",
                               selection: $dueDate, displayedComponents: .date)
                    DatePicker("Betalt dato",
                               selection: $paidDate, displayedComponents: .date)
                    HStack{
                        Text("Beløp:")
                        TextField("Beløp", value: $amount, formatter: numberFormatter)
                            .keyboardType(.decimalPad)
                    } .onChange(of: amount) { oldValue, newValue in
                        if newValue < filterMinimum {
                            amount = filterMinimum
                        }
                    }
                    
                    Picker("Velg Type", selection: $selectedType) {
                        ForEach(TransactionType.allCases.dropLast()) { transactionType in
                            Text(transactionType.title)
                                .tag(transactionType)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 50)
                    
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
                    
                    if showStatus{
                        Toggle("Generer ny fra denne (Status = 0", isOn: $isPaid)
                        HStack {
                            Text("Progress:")
                            TextField("Progress", value: $progress, formatter: intFormatter)
                        }
                        }
                    
                    Picker("Velg en Klient", selection: $selectedCustomer){
                        ForEach(customers) { customer in
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction){
                    Button("Avbryt") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                ToolbarItem(placement: .topBarTrailing){
                    Button("Oppdater") {
                        updateInvoice()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonStyle(.borderedProminent)
                    .disabled(changed || amount < filterMinimum || selectedCustomer == nil )
                }
            }
            .preferredColorScheme(darkModeEnabled ? .dark : .light)
            .onAppear() {
                selectedType = invoice.type
                selectedState = invoice.state
                self.title = invoice.title
                self.type = invoice.type
                self.state = invoice.state
                self.amount = invoice.amount
                self.dueDate = invoice.dueDate
                self.paidDate = invoice.paidDate
                self.isPaid = invoice.isPaid
                self.interval = invoice.interval
                self.selectedCustomer = invoice.customer
            }
            .navigationTitle("Oppdater Bilag")
        }
    }
    
    func updateInvoice() {
        // setter verdiene fra variablene til databasen
        
        if selectedType == .income && (selectedState == .paid || selectedState == .taken) {
            selectedState = .resieved
        }
        
        if selectedType == .expense && selectedState == .resieved {
            selectedState = .paid
        }
        
        if amount < filterMinimum {
            amount = filterMinimum
        }
        invoice.title = title
        invoice.type = selectedType
        invoice.state = selectedState
        invoice.amount = amount
        invoice.dueDate = dueDate
        invoice.paidDate = paidDate
        invoice.isPaid = isPaid
        invoice.interval = interval
        invoice.customer = selectedCustomer
    }
    
    var changed: Bool {
        invoice.type.title == selectedType.title
        && invoice.state.title == selectedState.title
        && invoice.title == title
        && invoice.amount == amount
        && invoice.dueDate == dueDate
        && invoice.paidDate == paidDate
        && invoice.isPaid == isPaid
        && invoice.interval == interval
        && invoice.customer == selectedCustomer
        // && !invoice.customer!.hasChanges
    }
}
