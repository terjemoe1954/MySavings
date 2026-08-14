//
//  TransactionType.swift
//  Income
//
//  Created by Terje Moe on 08/11/2025.
//

import Foundation
import SwiftUI

enum TransactionState: String, CaseIterable, Identifiable, Codable {
    case   resieved, pending, paid, taken, all
    var id: Self { self }
    
    var title: String {
        switch self {
        case .paid: return "Betalt"
        case .pending: return "Venter"
        case .resieved: return "Mottatt"
        case .taken: return "Trukket"
        case .all: return "Alle"
            
        }
    }
    
    var color: Color {
        switch self {
        case .paid: return .green
        case .pending: return .yellow
        case .resieved: return .blue
        case .taken: return .red
        case .all: return .black
            
        }
    }
}

enum TransactionType: String, CaseIterable, Identifiable, Codable {
    case income, expense, all
    var id: Self { self }
    
    var title: String {
        switch self {
        case .income: return "Intekt"
        case .expense: return "Utgift"
        case .all: return "Annet"
        }
    }
    
    var color: Color {
        switch self {
        case .income: return .green
        case .expense: return .red
        case .all: return .primary
        }
    }
}

var numberFormatter: NumberFormatter {
    let numberFormatter = NumberFormatter()
    numberFormatter.numberStyle = .decimal
    numberFormatter.minimumFractionDigits = 2
    
    return numberFormatter
}

var intFormatter: NumberFormatter {
    let numberFormatter = NumberFormatter()
    numberFormatter.numberStyle = .none
    return numberFormatter
}
