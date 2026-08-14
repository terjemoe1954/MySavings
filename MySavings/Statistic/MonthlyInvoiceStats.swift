//
//  MonthlyInvoiceStats.swift
//  MySavings
//
//  Created by Terje Moe on 11/01/2026.
//
import SwiftUI

struct MonthlyInvoiceStats: Identifiable {
    let id = UUID()
    let year: Int
    let month: Int
    let monthName: String
    let invoiceCount: Int
    let totalAmount: Double
    let paidAmount: Double
    let unpaidAmount: Double
    let pendingCount: Int
}
