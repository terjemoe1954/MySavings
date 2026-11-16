import Foundation
import SwiftData

struct SaldoPilotRestorePackage {
    let categories: [RestoreCategory]
    let transactions: [RestoreTransaction]
    let settings: RestoreSettings

    var categoryCount: Int {
        categories.count
    }

    var transactionCount: Int {
        transactions.count
    }
}

struct RestoreSettings {
    let displayName: String
    let darkModeEnabled: Bool
    let showName: Bool
    let showStatus: Bool
}

struct RestoreCategory {
    let id: String
    let name: String
}

struct RestoreTransaction {
    let exportID: String
    let exportSeriesID: String?
    let title: String
    let type: TransactionType
    let state: TransactionState
    let dueDate: Date
    let paidDate: Date
    let amount: Double
    let isPaid: Bool
    let interval: Int
    let categoryID: String
}

enum SaldoPilotImporter {
    static func decode(_ data: Data) throws -> SaldoPilotRestorePackage {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractionalFormatter.date(from: value) {
                return date
            }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: value) else {
                throw RestoreError.invalidDate(value)
            }
            return date
        }

        let backup: Backup
        do {
            backup = try decoder.decode(Backup.self, from: data)
        } catch let error as RestoreError {
            throw error
        } catch {
            throw RestoreError.invalidBackup(error.localizedDescription)
        }

        guard backup.formatVersion == 4 else {
            throw RestoreError.unsupportedVersion(backup.formatVersion)
        }
        guard !backup.transactions.isEmpty else {
            throw RestoreError.emptyBackup
        }

        let categoryIDs = Set(backup.categories.map(\.id))
        guard categoryIDs.count == backup.categories.count else {
            throw RestoreError.duplicateCategoryID
        }

        let transactionIDs = Set(backup.transactions.map(\.id))
        guard transactionIDs.count == backup.transactions.count else {
            throw RestoreError.duplicateTransactionID
        }

        let categories = backup.categories.map {
            RestoreCategory(id: $0.id, name: $0.name)
        }

        let transactions = try backup.transactions.map { transaction in
            guard categoryIDs.contains(transaction.category) else {
                throw RestoreError.missingCategory(transaction.title)
            }
            guard let amount = Double(transaction.amount),
                  amount.isFinite,
                  amount >= 0 else {
                throw RestoreError.invalidAmount(transaction.title)
            }

            let type: TransactionType
            switch transaction.type {
            case "income":
                type = .income
            case "expense":
                type = .expense
            default:
                throw RestoreError.invalidType(transaction.title)
            }

            let state: TransactionState
            switch transaction.status {
            case "pending":
                state = .pending
            case "received":
                state = .resieved
            case "paid":
                state = type == .income ? .resieved : .paid
            default:
                throw RestoreError.invalidStatus(transaction.title)
            }

            let completed = transaction.isCompleted || state != .pending
            return RestoreTransaction(
                exportID: transaction.id,
                exportSeriesID: transaction.recurrenceSeriesID,
                title: transaction.title,
                type: type,
                state: state,
                dueDate: transaction.dueDate,
                paidDate: transaction.paidDate ?? transaction.dueDate,
                amount: amount,
                isPaid: completed,
                interval: recurrenceInterval(
                    recurrence: transaction.recurrence,
                    intervalMonths: transaction.recurrenceIntervalMonths,
                    notes: transaction.notes
                ),
                categoryID: transaction.category
            )
        }

        return SaldoPilotRestorePackage(
            categories: categories,
            transactions: transactions,
            settings: RestoreSettings(
                displayName: backup.settings.displayName,
                darkModeEnabled: backup.settings.appearance == "dark",
                showName: backup.settings.showNameOnDashboard,
                showStatus: backup.settings.showCompletedStatus
            )
        )
    }

    @MainActor
    static func replaceData(
        with package: SaldoPilotRestorePackage,
        in modelContext: ModelContext
    ) throws {
        do {
            try modelContext.transaction {
                try modelContext.delete(model: Invoice.self)
                try modelContext.delete(model: Customer.self)

                var customersByID: [String: Customer] = [:]
                for category in package.categories {
                    let customer = Customer(title: category.name)
                    customersByID[category.id] = customer
                    modelContext.insert(customer)
                }

                for transaction in package.transactions {
                    guard let customer = customersByID[transaction.categoryID] else {
                        throw RestoreError.missingCategory(transaction.title)
                    }

                    let invoice = Invoice(
                        title: transaction.title,
                        type: transaction.type,
                        state: transaction.state,
                        dueDate: transaction.dueDate,
                        paidDate: transaction.paidDate,
                        amount: transaction.amount,
                        isPaid: transaction.isPaid,
                        interval: transaction.interval,
                        progress: 0
                    )
                    invoice.saldoPilotExportID = transaction.exportID
                    invoice.saldoPilotExportSeriesID = transaction.exportSeriesID
                    invoice.customer = customer
                    modelContext.insert(invoice)
                }
            }
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private static func recurrenceInterval(
        recurrence: String,
        intervalMonths: Int?,
        notes: String
    ) -> Int {
        switch recurrence {
        case "everyNMonths", "custom": return max(intervalMonths ?? 1, 1)
        case "quarterly": return 3
        case "halfYearly": return 6
        case "yearly": return 12
        case "monthly": break
        default: return 0
        }

        let prefix = "Opprinnelig intervall i MySavings: "
        guard let range = notes.range(of: prefix),
              let end = notes[range.upperBound...].firstIndex(where: { !$0.isNumber }),
              let interval = Int(notes[range.upperBound..<end]),
              interval > 0 else {
            return 1
        }
        return interval
    }
}

private struct Backup: Decodable {
    let formatVersion: Int
    let categories: [BackupCategory]
    let transactions: [BackupTransaction]
    let settings: BackupSettings
}

private struct BackupCategory: Decodable {
    let id: String
    let name: String
}

private struct BackupTransaction: Decodable {
    let id: String
    let title: String
    let amount: String
    let type: String
    let status: String
    let category: String
    let dueDate: Date
    let paidDate: Date?
    let recurrence: String
    let recurrenceIntervalMonths: Int?
    let recurrenceSeriesID: String?
    let isCompleted: Bool
    let notes: String
}

private struct BackupSettings: Decodable {
    let appearance: String
    let displayName: String
    let showCompletedStatus: Bool
    let showNameOnDashboard: Bool
}

enum RestoreError: LocalizedError {
    case invalidBackup(String)
    case unsupportedVersion(Int)
    case emptyBackup
    case duplicateCategoryID
    case duplicateTransactionID
    case missingCategory(String)
    case invalidAmount(String)
    case invalidDate(String)
    case invalidType(String)
    case invalidStatus(String)

    var errorDescription: String? {
        switch self {
        case .invalidBackup(let message):
            "Backupfilen kunne ikke leses: \(message)"
        case .unsupportedVersion(let version):
            "Backupformat versjon \(version) støttes ikke."
        case .emptyBackup:
            "Backupfilen inneholder ingen bilag."
        case .duplicateCategoryID:
            "Backupfilen inneholder dupliserte kategori-ID-er."
        case .duplicateTransactionID:
            "Backupfilen inneholder dupliserte bilags-ID-er."
        case .missingCategory(let title):
            "Bilaget «\(title)» mangler en gyldig kategori."
        case .invalidAmount(let title):
            "Bilaget «\(title)» har et ugyldig beløp."
        case .invalidDate(let value):
            "Backupfilen inneholder en ugyldig dato: \(value)."
        case .invalidType(let title):
            "Bilaget «\(title)» har en ukjent type."
        case .invalidStatus(let title):
            "Bilaget «\(title)» har en ukjent status."
        }
    }
}
