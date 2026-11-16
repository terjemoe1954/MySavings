import Foundation
import SwiftData
@main struct ExportAudit {
    @MainActor static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let category = Customer(title: "Bolig & Strøm")
        let custom = Customer(title: "Lån")
        let start = ISO8601DateFormatter().date(from: "2026-11-19T12:00:00Z")!
        let values: [Double] = [1249.50, 0.1 + 0.2, 2000.15, 32000, 19.995, 999.99, 10]
        let intervals = [0,1,3,6,12,5,1]
        let invoices = values.enumerated().map { index, amount in
            let invoice = Invoice(title: "Synthetic \(index)", type: index == 3 ? .income : .expense, dueDate: start.addingTimeInterval(Double(index)*86400), amount: amount, interval: intervals[index])
            invoice.customer = index == 6 ? custom : category
            return invoice
        }
        let schema = Schema([Invoice.self,Customer.self])
        let storeURL = root.appendingPathComponent("export-" + UUID().uuidString + ".store")
        let container = try ModelContainer(for:schema,configurations:[ModelConfiguration(schema:schema,url:storeURL,cloudKitDatabase:.none)])
        let context = ModelContext(container);context.autosaveEnabled = false
        context.insert(category);context.insert(custom);invoices.forEach { context.insert($0) }
        let new = try SaldoPilotExporter.makeDocument(invoices: invoices, customers: [category,custom], displayName: "Test", darkModeEnabled: false, showName: false, showStatus: true)
        let updated = try JSONSerialization.jsonObject(with: new.data) as! [String:Any]
        let after = updated["transactions"] as! [[String:Any]]
        let legacyIDs = ["83169A68-9D38-2A3B-7196-2CA6F88D4681", "3879EAA1-4F3D-A633-CBD2-963A44BA629D", "A6A3C0DF-5DD7-28F4-6755-2BC44B0BD822", "ECF86349-12C6-27EB-D7EF-9FA1D1C3BAB5", "64F05D4E-4664-960F-2C4D-8708F560B295", "5674F277-1B41-2DDB-89E7-4443D8E325D1", "F4F3531C-1152-5437-5E0B-775A659BBC51"]
        precondition(after.map { $0["id"] as! String } == legacyIDs, "Formatting must preserve legacy export IDs")
        let expected = ["1249.5","0.3","2000.15","32000","20","999.99","10"]
        precondition(after.map { $0["amount"] as! String } == expected)
        precondition(after.map { $0["recurrence"] as! String } == ["none","monthly","quarterly","halfYearly","yearly","everyNMonths","monthly"])
        let decoded = try SaldoPilotImporter.decode(new.data)
        precondition(decoded.transactions.map(\.interval) == intervals, "New export restores intervals to MySavings")
        let categories = updated["categories"] as! [[String:Any]]
        precondition(categories.first { $0["name"] as? String == "Lån" }?["isUserDefined"] as? Bool == true)
        precondition(invoices.map(\.amount) == values, "Export must not change source amounts")
        try new.data.write(to: root.appendingPathComponent("corrected-export.json"))
        let idsBefore = invoices.map(\.saldoPilotExportID)
        let seriesBefore = invoices.map(\.saldoPilotExportSeriesID)
        invoices[1].amount = 42.25; invoices[1].title = "Changed"; invoices[1].dueDate = start.addingTimeInterval(99999)
        let changed = try SaldoPilotExporter.makeDocument(invoices: invoices, customers: [category,custom], displayName: "Test", darkModeEnabled: false, showName: false, showStatus: true)
        precondition(invoices.map(\.saldoPilotExportID) == idsBefore)
        precondition(invoices.map(\.saldoPilotExportSeriesID) == seriesBefore)
        try changed.data.write(to: root.appendingPathComponent("changed-export.json"))
        let reopened = try ModelContainer(for:schema,configurations:[ModelConfiguration(schema:schema,url:storeURL,cloudKitDatabase:.none)])
        let reopenedInvoices = try ModelContext(reopened).fetch(FetchDescriptor<Invoice>())
        precondition(Set(reopenedInvoices.compactMap(\.saldoPilotExportID)) == Set(idsBefore.compactMap { $0 }))
        precondition(reopenedInvoices.first { $0.saldoPilotExportID == invoices[1].saldoPilotExportID }?.amount == 42.25)
        let first = Invoice(title: "Identical", type: .expense, dueDate: start, amount: 11, interval: 1)
        let second = Invoice(title: "Identical", type: .expense, dueDate: start, amount: 11, interval: 1)
        _ = try SaldoPilotExporter.makeDocument(invoices: [first,second], customers: [], displayName: "", darkModeEnabled: false, showName: false, showStatus: false)
        precondition(first.saldoPilotExportID != second.saldoPilotExportID)
        precondition(first.saldoPilotExportSeriesID != second.saldoPilotExportSeriesID)
        let duplicateIDs = [first.saldoPilotExportID,second.saldoPilotExportID]
        _ = try SaldoPilotExporter.makeDocument(invoices: [second,first], customers: [], displayName: "", darkModeEnabled: false, showName: false, showStatus: false)
        precondition([first.saldoPilotExportID,second.saldoPilotExportID] == duplicateIDs)
        print("MySavings export passed: currency precision, legacy IDs, source preservation and recurrence roundtrip")
    }
}
