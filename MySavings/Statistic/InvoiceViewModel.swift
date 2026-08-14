//
//  InvoiceViewModel.swift
//  MySavings
//
//  Created by Terje Moe on 11/01/2026.
//
import SwiftUI
import Combine
import SwiftData

@MainActor
class InvoiceViewModel: ObservableObject {
    @Published var invoices: [Invoice] = []
    @Published var monthlyStats: [MonthlyInvoiceStats] = []
    
    func loadInvoices(_ invoices: [Invoice]) {
        self.invoices = invoices
        monthlyStats = invoices.monthlySummary()
    }
    
    func addInvoice(_ invoice: Invoice) {
        invoices.append(invoice)
        monthlyStats = invoices.monthlySummary()
    }
}
