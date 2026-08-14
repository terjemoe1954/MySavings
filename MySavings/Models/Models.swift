//
//  Models.swift
//  Invoice_ One-Many
//
//  Created by Terje Moe on 03/12/2025.
//
// Endret Category to Customer
// Ser Bra Ut


import Foundation
import SwiftData
import Combine

class AppModel: ObservableObject {
    @Published var klientname: String = "Guest"
}

@Model
class Customer {
    // @Attribute(.unique)
    var title: String = ""
    @Relationship(deleteRule: .cascade, inverse: \Invoice.customer)
    var invoices: [Invoice]?
    
    init(title: String ) {
        self.title = title
    }
}

@Model
class Invoice {
    // var id: UUID = UUID()
    var title: String = ""
    var type: TransactionType = TransactionType.expense
    var state: TransactionState = TransactionState.pending
    var dueDate: Date = Date()
    var paidDate: Date = Date()
    var amount: Double = 0.0
    var isPaid: Bool = false
    var interval: Int = 0
    var customer: Customer?
    var progress: Int = 0
    
    init(
        title: String = "",
        type: TransactionType = .expense,
        state: TransactionState = .pending,
        dueDate: Date = .now,
        paidDate: Date = .now,
        amount: Double = 0.0,
        isPaid: Bool = false,
        interval: Int = 0,
        progress: Int = 0
    ) {
        self.title = title
        self.type = type
        self.state = state
        self.dueDate = dueDate
        self.paidDate = paidDate
        self.amount = amount
        self.isPaid = isPaid
        self.interval = interval
        self.progress = progress
    }
    
    @Transient
    var displayPaidDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        return dateFormatter.string(from: paidDate)
    }
    
    @Transient
    var displayDueDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        return dateFormatter.string(from: dueDate)
    }
    
    @Transient
    var displayAmount: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        // numberFormatter.numberStyle = .currency
        numberFormatter.minimumFractionDigits = 2
        return numberFormatter.string(from: amount as NSNumber) ?? "$0.00"
    }
    
}

extension Array where Element == Invoice {
    func monthlySummary() -> [MonthlyInvoiceStats] {
        let calendar = Calendar.current
        
        // ✅ FIXED: Create Hashable key struct instead of tuple
        let grouped = Dictionary(grouping: self) { invoice in
            let components = calendar.dateComponents([.year, .month], from: invoice.dueDate)
            return YearMonth(year: components.year ?? 0, month: components.month ?? 0)
        }
        
        return grouped.compactMap { (yearMonth, invoices) -> MonthlyInvoiceStats? in
            // Determine signed amount: income positive, expense negative
            func signedAmount(for invoice: Invoice) -> Double {
                switch invoice.type {
                case .income:
                    return invoice.amount
                case .expense:
                    return -invoice.amount
                case .all:
                    return 0.0
                }
            }

            let totalAmount = invoices.reduce(0) { $0 + signedAmount(for: $1) }

          //  let paidInvoices = invoices.filter { $0.isPaid }
            let paidInvoices = invoices.filter { $0.type == .expense && $0.state != .pending }
          
            let paidAmount = paidInvoices.reduce(0) { $0 + signedAmount(for: $1) }

            let pendingCount = invoices.filter { $0.state == .pending }.count

            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"

            let calendar = Calendar.current
            var components = DateComponents()
            components.year = yearMonth.year
            components.month = yearMonth.month
            guard let date = calendar.date(from: components) else { return nil }

            return MonthlyInvoiceStats(
                year: yearMonth.year,
                month: yearMonth.month,
                monthName: formatter.string(from: date),
                invoiceCount: invoices.count,
                totalAmount: totalAmount,
                paidAmount: paidAmount,
                unpaidAmount: totalAmount - paidAmount,
                pendingCount: pendingCount
            )
        }
        .sorted { $0.year > $1.year || ($0.year == $1.year && $0.month > $1.month) }
    }
}

// ✅ Hashable key struct (add this)
struct YearMonth: Hashable {
    let year: Int
    let month: Int
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(year)
        hasher.combine(month)
    }
    
    static func == (lhs: YearMonth, rhs: YearMonth) -> Bool {
        return lhs.year == rhs.year && lhs.month == rhs.month
    }
}

