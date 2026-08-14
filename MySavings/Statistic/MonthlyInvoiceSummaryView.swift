//
//  MonthlyInvoiceSummaryView.swift
//  MySavings
//
//  Created by Terje Moe on 11/01/2026.
//
import SwiftUI
import SwiftData
import UIKit

struct MonthlyInvoiceSummaryView: View {
    @StateObject private var viewModel = InvoiceViewModel()
    @Query(sort: \Invoice.dueDate, order: .reverse) private var invoices: [Invoice]
    @State private var showShareSheet = false
    @State private var reportShareURL: URL?
    @State private var showReportPreview = false
    @State private var reportPDFData: Data?
   
    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text("Alle Bilag")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                let totalExpenses = invoices.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
                let totalIncome = invoices.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
                Text("Intekter: " + String(Int(totalIncome)))
                    .foregroundStyle(.green)
                Text("Utgifter: " + String(Int(totalExpenses)))
                    .foregroundStyle(.red)
                Text("Tilgode: " + String(Int(totalIncome) - Int(totalExpenses)))
                    .foregroundStyle(.blue)
            }
            .font(.system(size: 16, weight: .bold))
            .padding()
           
            VStack(spacing: 0) {
                // Yearly Summary Header
               
                
                List(viewModel.monthlyStats) { stats in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(stats.monthName)
                                .font(.headline)
                            Spacer()
                            Text("\(stats.invoiceCount) Bilag")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.black)
                        }
                        
                        HStack(spacing: 16) {
                            statCard(title: "Tilgode", amount: Double(Int(stats.totalAmount)), color: .blue)
                            statCard(title: "Betalt", amount: Double(Int(stats.paidAmount)), color: .green)
                            statCard(title: "Intekt", amount: Double(Int(stats.unpaidAmount)), color: .orange)
                        }
                        
                        HStack {
                            Text("Venter: \(stats.pendingCount)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.orange)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
         //   .navigationTitle("Bilag Sammendrag")
            .onAppear {
                viewModel.loadInvoices(invoices)
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
    }
    
    private var totalIncome: Double {
        invoices.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var totalExpenses: Double {
        invoices.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var balance: Double {
        totalIncome - totalExpenses
    }

    private func exportReportPDF() {
        let data = makeReportPDFData(stats: viewModel.monthlyStats)
        guard let url = writeReportPDF(data: data) else { return }
        reportShareURL = url
        showShareSheet = true
    }

    private func previewReport() {
        reportPDFData = makeReportPDFData(stats: viewModel.monthlyStats)
        showReportPreview = true
    }

    private func saveReportToFiles() {
        let data = makeReportPDFData(stats: viewModel.monthlyStats)
        guard let url = writeReportPDF(data: data) else { return }
        reportShareURL = url
        showShareSheet = false
        DocumentPickerCoordinator.shared.presentExportPicker(for: url)
    }

    private func writeReportPDF(data: Data) -> URL? {
        let fileName = "MonthlyInvoiceSummary-\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private func printReport() {
        let data = makeReportPDFData(stats: viewModel.monthlyStats)
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "Monthly Invoice Summary"
        printInfo.outputType = .general
        let controller = UIPrintInteractionController.shared
        controller.printInfo = printInfo
        controller.printingItem = data
        controller.present(animated: true, completionHandler: nil)
    }

    private func makeReportPDFData(stats: [MonthlyInvoiceStats]) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 36
        let contentWidth = pageRect.width - (margin * 2)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let headerFont = UIFont.boldSystemFont(ofSize: 18)
        let subHeaderFont = UIFont.systemFont(ofSize: 12)
        let tableHeaderFont = UIFont.boldSystemFont(ofSize: 10)
        let rowFont = UIFont.systemFont(ofSize: 10)
        let footerFont = UIFont.systemFont(ofSize: 9)
        let footerHeight: CGFloat = 24
        let columnWidths: [CGFloat] = [150, 70, 90, 90, 90, 50]

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

            func currencyString(_ value: Double) -> String {
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.maximumFractionDigits = 0
                return formatter.string(from: value as NSNumber) ?? "NOK 0"
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

                drawText("Min Konto", font: footerFont, rect: CGRect(x: margin, y: footerY + 4, width: contentWidth / 2, height: footerHeight - 4))
                drawText("Side \(pageIndex)", font: footerFont, rect: CGRect(x: margin + contentWidth / 2, y: footerY + 4, width: contentWidth / 2, height: footerHeight - 4), alignment: .right)
            }

            context.beginPage()

            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

            drawText("Min Konto Månedlig Bilag Sammendrag", font: headerFont, rect: CGRect(x: margin, y: y, width: contentWidth, height: headerFont.lineHeight + 4))
            y += headerFont.lineHeight + 10

            let metaText = "Generert: \(formatter.string(from: Date()))    Inntekter: \(currencyString(totalIncome))    Utgifter: \(currencyString(totalExpenses))    Tilgode: \(currencyString(balance))"
            let metaHeight = textHeight(metaText, font: subHeaderFont, width: contentWidth)
            drawText(metaText, font: subHeaderFont, rect: CGRect(x: margin, y: y, width: contentWidth, height: metaHeight + 2))
            y += metaHeight + 10

            drawRow(cells: ["Måned", "Bilag", "Tilgode", "Betalt", "Inntekt", "Venter"], font: tableHeaderFont, isHeader: true)

            for item in stats {
                drawRow(
                    cells: [
                        item.monthName,
                        String(item.invoiceCount),
                        currencyString(item.totalAmount),
                        currencyString(item.paidAmount),
                        currencyString(item.unpaidAmount),
                        String(item.pendingCount)
                    ],
                    font: rowFont,
                    textColors: [.black, .black, .systemBlue, .systemGreen, .systemOrange, .systemOrange]
                )
            }

            drawFooter(pageIndex: pageIndex)
        }
    }
    
    @ViewBuilder
    private func statCard(title: String, amount: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
            Text(amount, format: .currency(code: "").precision(.fractionLength(0)))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
     MonthlyInvoiceSummaryView()
}

