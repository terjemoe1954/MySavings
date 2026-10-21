import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct SaldoPilotBackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum SaldoPilotExporter {
    static func makeDocument(
        invoices: [Invoice],
        customers: [Customer],
        displayName: String,
        darkModeEnabled: Bool,
        showName: Bool,
        showStatus: Bool
    ) throws -> SaldoPilotBackupDocument {
        let categoryRecords = makeCategories(customers: customers)
        let categoryIDs = Dictionary(
            uniqueKeysWithValues: categoryRecords.map { ($0.sourceName, $0.id) }
        )

        let backup = SaldoPilotBackup(
            formatVersion: 4,
            exportedAt: .now,
            categories: categoryRecords.map {
                SaldoPilotCategory(id: $0.id, name: $0.sourceName, icon: "person")
            },
            transactions: invoices.map {
                makeTransaction(invoice: $0, categoryIDs: categoryIDs)
            },
            budgets: [],
            settings: SaldoPilotSettings(
                appearance: darkModeEnabled ? "dark" : "light",
                defaultDateType: "dueDate",
                defaultPeriod: "thisMonth",
                displayName: displayName,
                language: "system",
                notificationAdvanceDays: 7,
                notifyDueInAdvance: true,
                notifyDueToday: true,
                notifyDueTomorrow: true,
                notifyPendingIncome: true,
                openingBalanceAmount: "0",
                showCompletedStatus: showStatus,
                showNameOnDashboard: showName,
                showSettledTransactions: true
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try SaldoPilotBackupDocument(data: encoder.encode(backup))
    }

    static func suggestedFilename(date: Date = .now) -> String {
        "SaldoPilot-Backup-\(date.formatted(.iso8601.year().month().day().dateSeparator(.omitted)))"
    }

    static func makeTemporaryFile(
        invoices: [Invoice],
        customers: [Customer],
        displayName: String,
        darkModeEnabled: Bool,
        showName: Bool,
        showStatus: Bool
    ) throws -> URL {
        let document = try makeDocument(
            invoices: invoices,
            customers: customers,
            displayName: displayName,
            darkModeEnabled: darkModeEnabled,
            showName: showName,
            showStatus: showStatus
        )
        let filename = "\(suggestedFilename())-\(UUID().uuidString.prefix(8)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try document.data.write(to: url, options: .atomic)
        return url
    }

    private static func makeCategories(customers: [Customer]) -> [CategoryRecord] {
        let names = Set(
            customers
                .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )

        var records = names
            .filter { $0.caseInsensitiveCompare("Annet") != .orderedSame }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map {
                CategoryRecord(
                    sourceName: $0,
                    id: "mysavings-\(slug(for: $0))-\(shortHash($0))"
                )
            }

        records.append(CategoryRecord(sourceName: "Annet", id: "other"))
        return records
    }

    private static func makeTransaction(
        invoice: Invoice,
        categoryIDs: [String: String]
    ) -> SaldoPilotTransaction {
        let customerName = invoice.customer?.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryID = customerName.flatMap { categoryIDs[$0] } ?? "other"
        let completed = invoice.isPaid || invoice.state != .pending
        let recurrence = invoice.interval > 0 ? "monthly" : "none"
        let canonicalID = [
            invoice.title,
            invoice.type.rawValue,
            invoice.state.rawValue,
            amountString(invoice.amount),
            invoice.dueDate.ISO8601Format(),
            customerName ?? "",
            String(invoice.interval)
        ].joined(separator: "|")

        return SaldoPilotTransaction(
            id: deterministicUUID(from: canonicalID),
            title: invoice.title,
            amount: amountString(invoice.amount),
            type: invoice.type == .income ? "income" : "expense",
            status: status(for: invoice),
            category: categoryID,
            dueDate: invoice.dueDate,
            paidDate: completed ? invoice.paidDate : nil,
            recurrence: recurrence,
            recurrenceAnchorDay: invoice.interval > 0
                ? Calendar.current.component(.day, from: invoice.dueDate)
                : nil,
            recurrenceSeriesID: invoice.interval > 0
                ? deterministicUUID(from: "series|\(canonicalID)")
                : nil,
            isCompleted: completed,
            isArchived: false,
            notes: invoice.interval > 1
                ? "Opprinnelig intervall i MySavings: \(invoice.interval) måneder."
                : "",
            createdAt: invoice.dueDate,
            updatedAt: invoice.dueDate
        )
    }

    private static func status(for invoice: Invoice) -> String {
        switch invoice.state {
        case .resieved:
            return "received"
        case .paid, .taken:
            return invoice.type == .income ? "received" : "paid"
        case .pending, .all:
            return "pending"
        }
    }

    private static func amountString(_ amount: Double) -> String {
        NSDecimalNumber(decimal: Decimal(amount)).stringValue
    }

    private static func slug(for value: String) -> String {
        let folded = value.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        let parts = folded.lowercased().split { !$0.isLetter && !$0.isNumber }
        let slug = parts.joined(separator: "-")
        return slug.isEmpty ? "kategori" : slug
    }

    private static func shortHash(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16).suffix(8).lowercased()
    }

    private static func deterministicUUID(from value: String) -> String {
        func hash(seed: UInt64) -> UInt64 {
            var result = seed
            for byte in value.utf8 {
                result ^= UInt64(byte)
                result &*= 1_099_511_628_211
            }
            return result
        }

        let first = hash(seed: 14_695_981_039_346_656_037)
        let second = hash(seed: 7_804_984_896_213_499_899)
        let hex = String(format: "%016llx%016llx", first, second)
        let firstIndex = hex.index(hex.startIndex, offsetBy: 8)
        let secondIndex = hex.index(firstIndex, offsetBy: 4)
        let thirdIndex = hex.index(secondIndex, offsetBy: 4)
        let fourthIndex = hex.index(thirdIndex, offsetBy: 4)
        return [
            String(hex[..<firstIndex]),
            String(hex[firstIndex..<secondIndex]),
            String(hex[secondIndex..<thirdIndex]),
            String(hex[thirdIndex..<fourthIndex]),
            String(hex[fourthIndex...])
        ].joined(separator: "-").uppercased()
    }
}

private struct CategoryRecord {
    let sourceName: String
    let id: String
}

private struct SaldoPilotBackup: Encodable {
    let formatVersion: Int
    let exportedAt: Date
    let categories: [SaldoPilotCategory]
    let transactions: [SaldoPilotTransaction]
    let budgets: [SaldoPilotBudget]
    let settings: SaldoPilotSettings
}

private struct SaldoPilotCategory: Encodable {
    let id: String
    let name: String
    let icon: String
}

private struct SaldoPilotTransaction: Encodable {
    let id: String
    let title: String
    let amount: String
    let type: String
    let status: String
    let category: String
    let dueDate: Date
    let paidDate: Date?
    let recurrence: String
    let recurrenceAnchorDay: Int?
    let recurrenceSeriesID: String?
    let isCompleted: Bool
    let isArchived: Bool
    let notes: String
    let createdAt: Date
    let updatedAt: Date
}

private struct SaldoPilotBudget: Encodable {}

private struct SaldoPilotSettings: Encodable {
    let appearance: String
    let defaultDateType: String
    let defaultPeriod: String
    let displayName: String
    let language: String
    let notificationAdvanceDays: Int
    let notifyDueInAdvance: Bool
    let notifyDueToday: Bool
    let notifyDueTomorrow: Bool
    let notifyPendingIncome: Bool
    let openingBalanceAmount: String
    let showCompletedStatus: Bool
    let showNameOnDashboard: Bool
    let showSettledTransactions: Bool
}
