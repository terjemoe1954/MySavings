//
//  Funcsions.swift
//  MySavings
//
//  Created by Terje Moe on 16/12/2025.
//

import SwiftUI
import SwiftData

struct BalanceView: View {
    @EnvironmentObject var model: AppModel
    @Query var transactions: [Invoice]
    private let calendar = Calendar.current
    @AppStorage("filterMinimum") var filterMinimum = 1.0
    @AppStorage("showUnpaid") var showUnpaid = false
    @AppStorage("showDueUnpaid") var showDueUnpaid = false
    @AppStorage("showAllPosts") var showAllPosts = true
    @AppStorage("orderDescending") var orderDescending = false
    @AppStorage("sortPaid") var sortPaid = false
    @AppStorage("showFilteredCustomer") var showFilteredCustomer = false
    @AppStorage("fromDate") var fromDate = Date()
    @AppStorage("toDate") var toDate = Date()
    @Query(sort: \Invoice.dueDate, order: .forward) private var invoices: [Invoice]
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("På Konto")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.black)
                        Text("\(total)")
                            .font(.system(size: 42, weight: .light))
                            .foregroundStyle(Color.black)
                    }
                }
                .padding(.top)
                
                HStack(spacing: 25) {
                    VStack(alignment: .leading) {
                        Text("Utgifter")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.black)
                        Text("\(expenses)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.black)
                    }
                    VStack(alignment: .leading) {
                        Text("Intekter")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.black)
                        Text("\(income)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.black)
                    }
                    VStack(alignment: .leading) {
                        Text("Poster")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.black)
                        Text(showAllPosts == true && showFilteredCustomer == false ? "\(showAllTransactions.count)" : "\(displayTransactions.count)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.black)
                    }
                }
                Spacer()
            }
        }
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        .frame(height: 150)
        .padding(.horizontal,7)
    }
   
    
    //***
    
    private var showAllTransactions: [Invoice] {
        // This selects all post sorted on duedate and filtered by from - to date
        let sortedTransactions: [Invoice] = {
            let sortKey: KeyPath<Invoice, Date> = sortPaid ? \.paidDate : \.dueDate
            return transactions.sorted {
                let lhs = calendar.startOfDay(for: $0[keyPath: sortKey])
                let rhs = calendar.startOfDay(for: $1[keyPath: sortKey])
                return orderDescending ? lhs > rhs : lhs < rhs
            }
        }()
        
        _ = model.klientname
        
        func matchesDateRange(_ invoice: Invoice) -> Bool {
            let date = sortPaid ? invoice.paidDate : invoice.dueDate
            let start = calendar.startOfDay(for: fromDate)
            let end = calendar.startOfDay(for: toDate)
            let invoiceDay = calendar.startOfDay(for: date)
            return invoiceDay >= start && invoiceDay <= end
        }
        
        let filtered = sortedTransactions.filter { invoice in
            matchesDateRange(invoice)
        }
        
        return filtered
    }
    
    
    //***
    
  
    
    private var displayTransactions: [Invoice] {
        let sortedTransactions: [Invoice] = {
            let sortKey: KeyPath<Invoice, Date> = sortPaid ? \.paidDate : \.dueDate
            return transactions.sorted {
                let lhs = calendar.startOfDay(for: $0[keyPath: sortKey])
                let rhs = calendar.startOfDay(for: $1[keyPath: sortKey])
                return orderDescending ? lhs > rhs : lhs < rhs
            }
        }()
        
        let myCustomer = model.klientname
        
//        func matchesBasicFilters(_ invoice: Invoice) -> Bool {
//            guard invoice.amount >= filterMinimum else { return false }
//          
//            if showUnpaid && invoice.state != .pending && !showFilteredCustomer { return false }
//            if !showUnpaid && invoice.isPaid == false && !showFilteredCustomer { return false }
//           
//            return true
//        }
        
        func matchesBasicFilters(_ invoice: Invoice) -> Bool {
            guard invoice.amount >= filterMinimum else { return false }
            if invoice.interval == 0 { return showUnpaid ? false : true }
            if invoice.isPaid { return showUnpaid ? false : true }

            if showUnpaid && invoice.state != .pending && !showFilteredCustomer { return false }
            if !showUnpaid && invoice.isPaid == false && !showFilteredCustomer { return false }

            return true
        }
        
        
        
        func matchesDateRange(_ invoice: Invoice) -> Bool {
            let date = sortPaid ? invoice.paidDate : invoice.dueDate
            let start = calendar.startOfDay(for: fromDate)
            let end = calendar.startOfDay(for: toDate)
            let invoiceDay = calendar.startOfDay(for: date)
            return invoiceDay >= start && invoiceDay <= end
        }
        
        func matchesCustomer(_ invoice: Invoice) -> Bool {
            guard showFilteredCustomer else { return true }
            return invoice.customer?.title == myCustomer
        }
        
        func matchesDueUnpaid(_ invoice: Invoice) -> Bool {
            guard showDueUnpaid else { return true }
            let today = calendar.startOfDay(for: Date())
            let invoiceDay = calendar.startOfDay(for: invoice.dueDate)
            return invoiceDay <= today && invoice.isPaid == false
        }
        
        let filtered = sortedTransactions.filter { invoice in
              matchesBasicFilters(invoice)
          &&  matchesDateRange(invoice)
          &&  matchesCustomer(invoice)
          &&  matchesDueUnpaid(invoice)
        }
        
        return filtered
        
    }
    
   private var expenses: String {
        let sumExpenses = (showAllPosts == true && showFilteredCustomer == false ? showAllTransactions : displayTransactions)
            .filter { $0.type == .expense && $0.amount >= filterMinimum }
            .reduce(0, { $0 + $1.amount })
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.maximumFractionDigits = 2
        
        return numberFormatter.string(from: sumExpenses as NSNumber) ?? "NOK 0.00"
    }
    
    private var income: String {
        let sumIncome = (showAllPosts == true && showFilteredCustomer == false ? showAllTransactions : displayTransactions)
            .filter { $0.type == .income && $0.amount >= filterMinimum }
            .reduce(0, { $0 + $1.amount })
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.maximumFractionDigits = 2
        
        return numberFormatter.string(from: sumIncome as NSNumber) ?? "NOK 0.00"
    }
    
    private var total: String {
        let sumExpenses = (showAllPosts == true && showFilteredCustomer == false ? showAllTransactions : displayTransactions)
            .filter { $0.type == .expense && $0.amount >= filterMinimum }
            .reduce(0, { $0 + $1.amount })
        let sumIncome = (showAllPosts == true && showFilteredCustomer == false ? showAllTransactions : displayTransactions)
            .filter { $0.type == .income && $0.amount >= filterMinimum }
            .reduce(0, { $0 + $1.amount })
        let total = sumIncome - sumExpenses
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.maximumFractionDigits = 2
        return numberFormatter.string(from: total as NSNumber) ?? "NOK 0.00"
    }
}

#Preview {
    BalanceView()
}
