//
//  ContentView.swift
//  ToDos
//  dette er for nå
//  Created by Tunde Adegoroye on 06/06/2023.
// bra

import SwiftUI
import SwiftData
import UIKit
import PDFKit

struct ListInvoiceView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("filterMinimum") var filterMinimum = 1.0
    @AppStorage("orderDescending") var orderDescending = false
    @AppStorage("showUnpaid") var showUnpaid = false
    @AppStorage("showDueUnpaid") var showDueUnpaid = false
    @AppStorage("showAllPosts") var showAllPosts = false
    @AppStorage("fromDate") var fromDate = Date()
    @AppStorage("toDate") var toDate = Date()
    @AppStorage("sortPaid") var sortPaid = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @Query var transactions: [Invoice]
    @Query(sort: \Invoice.dueDate, order: .forward) private var invoices: [Invoice]
    @State private var showFilters = false
    @State private var showAddTransactionView = false
    @State private var showCreateCustomer = false
    @State private var showCreateInvoice = false
    @State private var invoiceToEdit: Invoice?
    @State private var showConfirmation: Bool = false
    @State private var invoiceToDelete: Invoice?
    @State private var showShareSheet = false
    @State private var reportShareURL: URL?
    @State private var showReportPreview = false
    @State private var reportPDFData: Data?
    @AppStorage("showFilteredCustomer") var showFilteredCustomer = false
    let calendar = Calendar.current
    @State private var selectedCustomer: Customer?
    @Query private var customers: [Customer]
    
    var body: some View {
        NavigationStack {
            Section {
                Text("Sum : \(total)")
                    .font(.system(size: 16,weight: .black))
                    .background(.blue)
                    .opacity(0.4)
                    .clipShape(.capsule)
                
                Toggle(isOn: $showFilteredCustomer) {
                    Text("Filter Klient")
                    
                }
                Picker("Velg en Klient", selection: $selectedCustomer){
                    ForEach(customers.sorted { $0.title < $1.title }) { customer in
                        Text(customer.title)
                            .tag(customer as Customer?)
                    }
                    .labelsHidden()
                    .pickerStyle(.inline)
                    Text("Klienter")
                        .tag(nil as Customer?)
                }
                .disabled(!showFilteredCustomer)
                .onChange(of: selectedCustomer) { oldValue, newValue in
                    if let title = newValue?.title {
                        model.klientname = title
                    }
                }
            }.frame(width: 200,height: 20,  alignment: .center)
            ZStack {
                List {
                   ForEach(showAllPosts == true && showFilteredCustomer == false ? showAllTransactions : displayTransactions) { invoice in
                        HStack {
                            VStack(alignment: .leading) {
                                HStack {
                                    Spacer()
                                    Text("Forfall : \(invoice.displayDueDate)")
                                    Spacer()
                                    Text(invoice.state != .pending ? "Betalt : \(invoice.displayPaidDate)" : "Reg: \(invoice.displayPaidDate)")
                                    Spacer()
                                }
                                .font(.system(size: 14, weight: .bold))
                                .padding(.vertical, 5)
                                .background(Color.gray.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                
                                HStack{
                                    Text(invoice.title)
                                        .font(.system(size: 15,weight: .bold))
                                    Spacer()
                                    Text("\(invoice.displayAmount)")
                                        .font(.system(size: 15,weight: .bold))
                                }
                                .padding(.horizontal, 8)
                                
                                HStack {
                                    Image(systemName: invoice.type == .income ? "arrow.up.forward" : "arrow.down.forward")
                                        .font(.system(size: 16, weight: .bold ))
                                        .foregroundStyle(invoice.type == .income ? Color.green : Color.red)
                                    HStack{
                                        if let customer = invoice.customer {
                                            Text(customer.title)
                                                .font(.system(size: 14,weight:.bold))
                                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                                                .bold()
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                    
                                    HStack{
                                        Spacer()
                                        Text("\(invoice.state.title)")
                                            .font(.system(size: 14,weight: .bold))
                                            .foregroundStyle(invoice.state.color)
                                        Spacer()
                                        Text("\(invoice.type.title)")
                                            .font(.system(size: 14,weight: .bold))
                                            .foregroundStyle(invoice.type.color)
                                            .padding(.horizontal)
                                    }
                                }
                            }
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                        .onTapGesture {
                            invoiceToEdit = invoice
                        }
                        .swipeActions {
                            
                            Button(role: .destructive) {
                                invoiceToDelete = invoice
                                showConfirmation.toggle()
                            }
                        }
                    }
                }
                FloatingButton()
            }
            .confirmationDialog(
                "Slett",
                isPresented: $showConfirmation,
                titleVisibility: .visible,
                presenting: invoiceToDelete ,
                actions: { item in
                    Button(role: .destructive) {
                        withAnimation {
                            modelContext.delete(item)
                            try? modelContext.save()
                        }
                    } label: {
                        Text("Slett")
                    }
                    Button(role: .confirm) {
                        
                    } label: {
                        Text("Avbryt")
                    }
                },
                message: { item in
                    Text("Er du sikker på at du vil slette \(item.title)?")
                })
            .sheet(item: $invoiceToEdit,
                   onDismiss: {
                invoiceToEdit = nil
            },
                   content: { editInvoice in
                NavigationStack {
                    UpdateInvoiceView(invoice: editInvoice)
                        .interactiveDismissDisabled()
                }
            })
            .sheet(isPresented: $showCreateCustomer,
                   content: {
                NavigationStack {
                    CreateCustomerView()
                }
            })
            .sheet(isPresented: $showCreateInvoice,
                   content: {
                NavigationStack {
                    CreateInvoiceView()
                }
            })
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Tilbake \(Image(systemName: "arrowshape.turn.up.backward.2.fill"))") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.system(size: 15, weight: .bold))
                    .padding(8)
                }
            }
            
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilters = true
                    } label: {
                        HStack {
                            Text("Filtere")
                            Image(systemName: "engine.emission.and.filter")
                                .foregroundStyle(darkModeEnabled ? Color.white : Color.black)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Preview Report") {
                            previewReport()
                        }
                        Button("Print Report") {
                            printReport()
                        }
                        Button("Export PDF") {
                            exportReportPDF()
                        }
                    } label: {
                        Label("Report", systemImage: "printer")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                }
            }
            .sheet(isPresented: $showFilters) {
                FiltersView(filterMinimum: $filterMinimum, orderDescending: $orderDescending,showUnpaid: $showUnpaid,showDueUnpaid: $showDueUnpaid, fromDate: $fromDate, toDate: $toDate, sortPaid: $sortPaid,showAllPosts: $showAllPosts)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = reportShareURL {
                    ActivityView(activityItems: [url])
                } else {
                    Text("Could not create PDF.")
                }
            }
            .sheet(isPresented: $showReportPreview) {
                if let data = reportPDFData {
                    ReportPreviewView(
                        data: data,
                        onPrint: { printReport() },
                        onShare: { exportReportPDF() },
                        onSaveToFiles: { saveReportToFiles() }
                    )
                } else {
                    Text("Could not create PDF.")
                }
            }
        }
        .onDisappear{
           showFilteredCustomer = false
        }
        .onAppear() {
        duplicateAllInvoices()
        }
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
    }
    
    private var total: String {
        let sumExpenses = displayTransactions
            .filter { $0.type == .expense && $0.amount >= filterMinimum }
            .reduce(0, { $0 + $1.amount })
        let sumIncome = displayTransactions
            .filter { $0.type == .income && $0.amount >= filterMinimum }
            .reduce(0, { $0 + $1.amount })
        let total = sumIncome - sumExpenses
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.maximumFractionDigits = 2
        return numberFormatter.string(from: total as NSNumber) ?? "NOK 0.00"
    }

    private var reportInvoices: [Invoice] {
        showAllPosts == true && showFilteredCustomer == false ? showAllTransactions : displayTransactions
    }

    private struct ReportSummary {
        let incomePaid: Double
        let incomeUnpaid: Double
        let expensePaid: Double
        let expenseUnpaid: Double
    }

    private func reportTotalString(for invoices: [Invoice]) -> String {
        let sumExpenses = invoices
            .filter { $0.type == .expense && $0.amount >= filterMinimum }
            .reduce(0, { $0 + $1.amount })
        let sumIncome = invoices
            .filter { $0.type == .income && $0.amount >= filterMinimum }
            .reduce(0, { $0 + $1.amount })
        let total = sumIncome - sumExpenses
        return reportCurrencyString(total)
    }

    private func reportSummary(for invoices: [Invoice]) -> ReportSummary {
        let filtered = invoices.filter { $0.amount >= filterMinimum }
        func isPaid(_ invoice: Invoice) -> Bool {
            invoice.isPaid || invoice.state != .pending
        }

        var incomePaid = 0.0
        var incomeUnpaid = 0.0
        var expensePaid = 0.0
        var expenseUnpaid = 0.0

        for invoice in filtered {
            switch invoice.type {
            case .income:
                if isPaid(invoice) {
                    incomePaid += invoice.amount
                } else {
                    incomeUnpaid += invoice.amount
                }
            case .expense:
                if isPaid(invoice) {
                    expensePaid += invoice.amount
                } else {
                    expenseUnpaid += invoice.amount
                }
            case .all:
                break
            }
        }

        return ReportSummary(
            incomePaid: incomePaid,
            incomeUnpaid: incomeUnpaid,
            expensePaid: expensePaid,
            expenseUnpaid: expenseUnpaid
        )
    }

    private func reportCurrencyString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSNumber) ?? "NOK 0.00"
    }

    private func exportReportPDF() {
        let data = makeReportPDFData(invoices: reportInvoices)
        guard let url = writeReportPDF(data: data) else { return }
        reportShareURL = url
        showShareSheet = true
    }

    private func previewReport() {
        reportPDFData = makeReportPDFData(invoices: reportInvoices)
        showReportPreview = true
    }

    private func saveReportToFiles() {
        let data = makeReportPDFData(invoices: reportInvoices)
        guard let url = writeReportPDF(data: data) else { return }
        reportShareURL = url
        showShareSheet = false
        DocumentPickerCoordinator.shared.presentExportPicker(for: url)
    }

    private func writeReportPDF(data: Data) -> URL? {
        let fileName = "InvoiceReport-\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private func printReport() {
        let data = makeReportPDFData(invoices: reportInvoices)
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "Invoice Report"
        printInfo.outputType = .general
        let controller = UIPrintInteractionController.shared
        controller.printInfo = printInfo
        controller.printingItem = data
        controller.present(animated: true, completionHandler: nil)
    }

    private func makeReportPDFData(invoices: [Invoice]) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 36
        let contentWidth = pageRect.width - (margin * 2)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let headerFont = UIFont.boldSystemFont(ofSize: 18)
        let subHeaderFont = UIFont.systemFont(ofSize: 12)
        let tableHeaderFont = UIFont.boldSystemFont(ofSize: 10)
        let rowFont = UIFont.systemFont(ofSize: 10)
        let metaFont = UIFont.systemFont(ofSize: 10)
        let footerFont = UIFont.systemFont(ofSize: 9)
        let footerHeight: CGFloat = 24

        let columnWidths: [CGFloat] = [
            90,  // Date
            170, // Title (allows wrapping)
            90,  // Amount
            70,  // State
           
            max(0, contentWidth - (90 + 170 + 90 + 70)) // Customer (wider)
        ]

        return renderer.pdfData { context in
            var y = margin
            var pageIndex = 1

            func beginPageIfNeeded(_ height: CGFloat) {
                if y + height > pageRect.height - margin - footerHeight {
                    drawFooter(pageIndex: pageIndex)
                    context.beginPage()
                    pageIndex += 1
                    y = margin
                }
            }

            func drawText(_ text: String, font: UIFont, rect: CGRect, alignment: NSTextAlignment = .left, color: UIColor = .black) {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineBreakMode = .byWordWrapping
                paragraphStyle.alignment = alignment
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .paragraphStyle: paragraphStyle,
                    .foregroundColor: color
                ]
                (text as NSString).draw(in: rect, withAttributes: attributes)
            }

            func textHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineBreakMode = .byWordWrapping
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .paragraphStyle: paragraphStyle
                ]
                let bounding = (text as NSString).boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )
                return ceil(bounding.height)
            }

            func drawSymbol(name: String, size: CGFloat, x: CGFloat, y: CGFloat) {
                if let image = UIImage(systemName: name) {
                    let rect = CGRect(x: x, y: y, width: size, height: size)
                    image.withTintColor(.black, renderingMode: .alwaysOriginal)
                        .draw(in: rect)
                }
            }

            func drawRow(cells: [String], font: UIFont, isHeader: Bool = false, textColors: [UIColor]? = nil) {
                let heights = zip(cells, columnWidths).map { textHeight($0.0, font: font, width: $0.1) }
                let rowHeight = max(18, heights.max() ?? 18) + 4
                beginPageIfNeeded(rowHeight + 8)

                var x = margin
                for index in cells.indices {
                    let width = columnWidths[index]
                    let rect = CGRect(x: x, y: y, width: width, height: rowHeight)
                    let color = textColors?[index] ?? .black
                    drawText(cells[index], font: font, rect: rect, color: color)
                    x += width
                }

                let lineY = y + rowHeight + 2
                let linePath = UIBezierPath()
                linePath.move(to: CGPoint(x: margin, y: lineY))
                linePath.addLine(to: CGPoint(x: margin + contentWidth, y: lineY))
                (isHeader ? UIColor.black : UIColor.lightGray).setStroke()
                linePath.lineWidth = isHeader ? 1.2 : 0.6
                linePath.stroke()

                y += rowHeight + 6
            }

            func drawFooter(pageIndex: Int) {
                let footerY = pageRect.height - margin - footerHeight
                let linePath = UIBezierPath()
                linePath.move(to: CGPoint(x: margin, y: footerY))
                linePath.addLine(to: CGPoint(x: margin + contentWidth, y: footerY))
                UIColor.lightGray.setStroke()
                linePath.lineWidth = 0.6
                linePath.stroke()

                let leftText = "Min Konto"
                let rightText = "Side \(pageIndex)"
                let leftRect = CGRect(x: margin, y: footerY + 4, width: contentWidth / 2, height: footerHeight - 4)
                let rightRect = CGRect(x: margin + contentWidth / 2, y: footerY + 4, width: contentWidth / 2, height: footerHeight - 4)
                drawText(leftText, font: footerFont, rect: leftRect, alignment: .left)
                drawText(rightText, font: footerFont, rect: rightRect, alignment: .right)
            }

            context.beginPage()

            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

            beginPageIfNeeded(56)
            drawSymbol(name: "chart.bar.doc.horizontal", size: 22, x: margin, y: y)
            drawText("Min Konto Bilag Rapport", font: headerFont, rect: CGRect(x: margin + 28, y: y - 2, width: contentWidth - 28, height: headerFont.lineHeight + 4))
            y += headerFont.lineHeight + 10

            let metaText = "Generert: \(formatter.string(from: Date()))    Total: \(reportTotalString(for: invoices))    Antall: \(invoices.count)"
            let metaHeight = textHeight(metaText, font: subHeaderFont, width: contentWidth)
            beginPageIfNeeded(metaHeight + 6)
            drawText(metaText, font: subHeaderFont, rect: CGRect(x: margin, y: y, width: contentWidth, height: metaHeight + 2))
            y += metaHeight + 8

            let sortField = sortPaid ? "Betalt Dato" : "Forfalls Dato"
            let sortOrder = orderDescending ? "Synkende" : "Stigende"
            let customerFilter = showFilteredCustomer ? (selectedCustomer?.title ?? "Alle Klienter") : "Alle Klienter"
            let filterSummary = "Sortert: \(sortField) (\(sortOrder))    Klient: \(customerFilter)    Ubetalt: \(showUnpaid ? "Kunn" : "Innkludert")    Forfallt Ubetalt: \(showDueUnpaid ? "Ja" : "Nei")    Utvalg: \(formatter.string(from: fromDate)) – \(formatter.string(from: toDate))"
            let filterHeight = textHeight(filterSummary, font: metaFont, width: contentWidth)
            beginPageIfNeeded(filterHeight + 6)
            drawText(filterSummary, font: metaFont, rect: CGRect(x: margin, y: y, width: contentWidth, height: filterHeight + 2))
            y += filterHeight + 10

            drawRow(cells: ["Dato", "Tittel", "Beløp", "Status", "Klient"], font: tableHeaderFont, isHeader: true)

            for invoice in invoices {
                let customerName = invoice.customer?.title ?? "-"
                let dateString = sortPaid ? invoice.displayPaidDate : invoice.displayDueDate
                let amountColor: UIColor
                switch invoice.type {
                case .income:
                    amountColor = .systemGreen
                case .expense:
                    amountColor = .systemRed
                case .all:
                    amountColor = .black
                }
                let rowColors: [UIColor] = [
                    .black,
                    .black,
                    amountColor,
                    .black,
                    .black
                ]
                drawRow(
                    cells: [
                        dateString,
                        invoice.title,
                        invoice.displayAmount,
                        invoice.state.title,
                        customerName
                    ],
                    font: rowFont,
                    textColors: rowColors
                )
            }

            let summary = reportSummary(for: invoices)
            let summaryText = """
            Oppsummering
            Inntekt mottatt: \(reportCurrencyString(summary.incomePaid))    Inntekt venter: \(reportCurrencyString(summary.incomeUnpaid))
            Utgift betalt: \(reportCurrencyString(summary.expensePaid))    Utgift ubetalt: \(reportCurrencyString(summary.expenseUnpaid))
            """
            let summaryHeight = textHeight(summaryText, font: metaFont, width: contentWidth)
            beginPageIfNeeded(summaryHeight + 6)
            drawText(summaryText, font: metaFont, rect: CGRect(x: margin, y: y, width: contentWidth, height: summaryHeight + 2))
            y += summaryHeight + 6

            drawFooter(pageIndex: pageIndex)
        }
    }
    
    fileprivate func FloatingButton() -> some View {
        VStack {
            Spacer()
            NavigationLink {
                CreateInvoiceView()
            } label: {
                Text("+")
                    .font(.largeTitle)
                    .frame(width: 70, height: 70)
                    .foregroundStyle(Color.white)
            }
            .background(Color.green)
            .clipShape(Circle())
            .padding(.bottom, 7)
        }
    }
    
    private var displayTransactions: [Invoice] {
        let sortedTransactions: [Invoice] = { 
            let sortKey: KeyPath<Invoice, Date> = sortPaid ? \.paidDate : \.dueDate
            return transactions.sorted {
                let lhs = calendar.startOfDay(for: $0[keyPath: sortKey])
                let rhs = calendar.startOfDay(for: $1[keyPath: sortKey])
                return orderDescending ? lhs > rhs : lhs < rhs
            }
        }()
        
        let myCustomer = selectedCustomer?.title ?? ""
        
        
        func matchesBasicFilters(_ invoice: Invoice) -> Bool {
            // Minimum amount must pass
            guard invoice.amount >= filterMinimum else { return false }

            // Always include one-time payments (interval == 0)
            if invoice.interval == 0 { return showUnpaid ? false : true }

            // Always include paid invoices regardless of the "Show Unpaid" toggle
            if invoice.isPaid { return showUnpaid ? false : true }

            // For unpaid recurring invoices, apply the existing toggles
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
    
    //********
    
    
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
    
    
    //********
    
    
    
    
    private var selectTransactions: [Invoice] {
        // Sort by most recent paidDate first
        let sortedTransactions = transactions.sorted { calendar.startOfDay(for: $0.paidDate) > calendar.startOfDay(for: $1.paidDate) }
        // Filter to only those with dueDate after today
        let filtered = sortedTransactions.filter { (calendar.startOfDay(for: $0.dueDate) <= calendar.startOfDay(for: Date()) && ($0.interval > 0 && $0.isPaid == false ))}
   
        return filtered
    }
    
    private func duplicateAllInvoices() {
        let source = selectTransactions
        guard !source.isEmpty else { return }
        
        for original in source {
            if !original.isPaid && original.state != .pending { original.isPaid = true
                try? modelContext.save()
            }
        guard original.progress < 1 else { return }
            let copy = Invoice()
            copy.title = "Copy of \(original.title)"
            copy.type = original.type
            copy.state = .pending //original.state
            copy.amount = original.amount
            let monthsToAdd = original.interval
            let newDue = Calendar.current.date(byAdding: .month, value: monthsToAdd, to: original.dueDate) ?? original.dueDate
            copy.dueDate = newDue
            copy.paidDate = newDue //original.paidDate
            copy.isPaid = false
            copy.interval = original.interval
            copy.customer = original.customer
            original.progress = original.progress + 1
            modelContext.insert(copy)
            copy.customer?.invoices?.append(copy)
            original.isPaid = ((original.state == .paid) || (original.state == .resieved) || (original.state == .taken))  ? true : false
        }
        try? modelContext.save()
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

struct ReportPreviewView: View {
    let data: Data
    let onPrint: () -> Void
    let onShare: () -> Void
    let onSaveToFiles: () -> Void

    var body: some View {
        NavigationStack {
            PDFKitView(data: data)
                .navigationTitle("Report Preview")
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Print") { onPrint() }
                        Spacer()
                        Button("Save to Files") { onSaveToFiles() }
                        Spacer()
                        Button("Share") { onShare() }
                    }
                }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = .singlePageContinuous
        view.autoScales = true
        view.displayDirection = .vertical
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document == nil {
            uiView.document = PDFDocument(data: data)
        }
    }
}

final class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
    static let shared = DocumentPickerCoordinator()

    func presentExportPicker(for url: URL) {
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        picker.delegate = self
        picker.modalPresentationStyle = .formSheet

        if let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first?.rootViewController {
            root.present(picker, animated: true)
        }
    }
}

#Preview {
    ListInvoiceView()
        .modelContainer(for: Invoice.self, inMemory: true)
}
