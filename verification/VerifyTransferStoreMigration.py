from pathlib import Path
import subprocess
import tempfile
root=Path(tempfile.mkdtemp(prefix='transfer-migration-fixtures-'))
r=Path('/Users/terjemoe/Desktop/My Apps/MySavings')
original=(r/'MySavings/Models/Models.swift').read_text();original=original.replace('    var saldoPilotExportID: String?\n','').replace('    var saldoPilotExportSeriesID: String?\n','');(root/'LegacyModels.swift').write_text(original)
main='''import Foundation
import SwiftData
@main struct Migration {
 @MainActor static func main() throws {
  let schema = Schema([Invoice.self,Customer.self])
  let url = URL(fileURLWithPath:CommandLine.arguments[1])
  let container = try ModelContainer(for:schema,configurations:[ModelConfiguration(schema:schema,url:url,cloudKitDatabase:.none)])
  let ctx = ModelContext(container)
  if CommandLine.arguments[2] == "seed" {
   let customer = Customer(title:"Migration category")
   ctx.insert(customer)
   for n in 0..<5 {
    let t = Invoice(title:"Migration \\(n)",type:.expense,dueDate:Date(timeIntervalSince1970:1700000000+Double(n)),amount:Double(n)+0.25,interval:12)
    t.customer = customer;ctx.insert(t)
   }
   try ctx.save()
  } else {
   let rows = try ctx.fetch(FetchDescriptor<Invoice>()).sorted { $0.title < $1.title }
   precondition(rows.count == 5)
   for (n,t) in rows.enumerated() { precondition(t.amount == Double(n)+0.25 && t.interval == 12 && t.customer?.title == "Migration category") }
   print("MySavings old-store migration preserved all financial fields and category relationships")
  }
 }
}
''';(root/'MyMain.swift').write_text(main)
shared=[r/'MySavings/Models/TransactionTypeModel.swift',r/'MySavings/Statistic/MonthlyInvoiceStats.swift']
for version,model in [('old',root/'LegacyModels.swift'),('new',r/'MySavings/Models/Models.swift')]:
 subprocess.run(['xcrun','swiftc','-parse-as-library','-module-name','MySavingsMigrationAudit','-module-cache-path','/tmp/transfer-migration-cache',str(model),*map(str,shared),str(root/'MyMain.swift'),'-o',str(root/f'mysavings-{version}')],check=True)
subprocess.run([str(root/'mysavings-old'),str(root/'mysavings.store'),'seed'],check=True)
subprocess.run([str(root/'mysavings-new'),str(root/'mysavings.store'),'check'],check=True)
# Compile the pre-provenance and new Spendly models under an identical module name.
r=Path('/Users/terjemoe/Desktop/My Apps/SpendlyAI/SpendlyAI')
for name in ['Transaction','Income','FixedExpense']:
 t=(r/f'Models/{name}.swift').read_text()
 for field,typ in [('mySavingsSourceID','String'),('mySavingsSourceFingerprint','String'),('mySavingsSourceExportedAt','Date')]:
  t=t.replace(f'    var {field}: {typ}?\n','').replace(f'        self.{field} = {field}\n','')
 start=t.index(',\n        mySavingsSourceID:',t.index('    init('));end=t.index('\n    ) {',start);t=t[:start]+t[end:]
 (root/f'Legacy{name}.swift').write_text(t)
main='''import Foundation
import SwiftData
@main struct Migration {
 @MainActor static func main() throws {
  let schema = Schema([Transaction.self,Income.self,FixedExpense.self])
  let c = try ModelContainer(for:schema,configurations:[ModelConfiguration(schema:schema,url:URL(fileURLWithPath:CommandLine.arguments[1]),cloudKitDatabase:.none)])
  let ctx = ModelContext(c)
  if CommandLine.arguments[2] == "seed" {
   ctx.insert(Transaction(amount:123.45,date:Date(timeIntervalSince1970:1700000000),transactionDescription:"Preserve expense"))
   ctx.insert(Income(amount:32000,date:Date(timeIntervalSince1970:1700000000),incomeDescription:"Preserve income"))
   ctx.insert(FixedExpense(name:"Preserve recurring",amount:2000,dueDay:19,recurrence:.yearly))
   try ctx.save()
  } else {
   let a = try ctx.fetch(FetchDescriptor<Transaction>());let b = try ctx.fetch(FetchDescriptor<Income>());let d = try ctx.fetch(FetchDescriptor<FixedExpense>())
   precondition(a.count == 1 && a[0].amount == Decimal(string:"123.45")! && a[0].transactionDescription == "Preserve expense")
   precondition(b.count == 1 && b[0].amount == 32000)
   precondition(d.count == 1 && d[0].amount == 2000 && d[0].recurrence == .yearly)
   print("SpendlyAI old-store migration preserved expenses, income and recurrence")
  }
 }
}
''';(root/'SpendMain.swift').write_text(main)
for version in ['old','new']:
 models=[root/f'Legacy{n}.swift' if version=='old' else r/f'Models/{n}.swift' for n in ['Transaction','Income','FixedExpense']]
 subprocess.run(['xcrun','swiftc','-parse-as-library','-module-name','SpendlyMigrationAudit','-module-cache-path','/tmp/transfer-migration-cache',*map(str,models),str(r/'Models/FinancialEnums.swift'),str(r/'Models/PaymentStatus.swift'),str(root/'SpendMain.swift'),'-o',str(root/f'spendly-{version}')],check=True)
subprocess.run([str(root/'spendly-old'),str(root/'spendly.store'),'seed'],check=True)
subprocess.run([str(root/'spendly-new'),str(root/'spendly.store'),'check'],check=True)
