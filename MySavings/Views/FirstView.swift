//
//  FirstView.swift
//  MySavings
//
//  Created by Terje Moe on 13/12/2025.
// 14.12.25

import SwiftUI
import SwiftData

struct FirstView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage("darkModeEnambled") private var darkModeEnabled = false
    @AppStorage("filterMinimum") var filterMinimum = 1.0
    @AppStorage("orderDescending") var orderDescending = false
    @AppStorage("showUnpaid") var showUnpaid = true
    @AppStorage("showDueUnpaid") var showDueUnpaid = true
    @AppStorage("showAllPosts") var showAllPosts = false
    @AppStorage("fromDate") var fromDate = Date()
    @AppStorage("toDate") var toDate = Date()
    @AppStorage("sortPaid") var sortPaid = false
    @AppStorage("ShowName") private var showName = false
    @AppStorage("ShowStatus") private var showStatus = false
    @AppStorage("YourName") private var name: String = ""
    @AppStorage("showFilteredCustomer") var showFilteredCustomer = false
    @State private var showCreateCustomer = false
    @State private var showInvoiceList = false
    @State private var showingSettings = false
    @State private var showFilters = false
    @State private var showStatistic = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var context
    @Query var transactions: [Invoice]
    let calendar = Calendar.current
    @State private var realInvoices: [Invoice] = []
    var body: some View {
        NavigationStack {
            ZStack {
                Color(Color.cyan)
                    .ignoresSafeArea()
                    .opacity(0.1)
                
                Image("CityViewC")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.8)
                    .ignoresSafeArea()
                
                VStack {
                    Text(showName ? name : "")
                        .font(.largeTitle)
                        .bold()
                        .foregroundStyle(Color.white)
                    Spacer()
                    BalanceView()
                        .padding(.horizontal,60)
                    HStack {
                        Spacer()
                        VStack {
                            Button {
                                showCreateCustomer.toggle()
                            } label: {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 50, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.borderedProminent)
                            Text("Klienter")
                                .font(.system(size: 25, weight: .black))
                                .foregroundColor(.white)
                                .opacity(0.8)
                        }
                        .padding(.horizontal)
                        Spacer()
                        VStack {
                            Button {
                                showInvoiceList.toggle()
                            } label: {
                                Image(systemName: "norwegiankronesign.arrow.trianglehead.counterclockwise.rotate.90")
                                    .font(.system(size: 50, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.borderedProminent)
                            Text("Bilag")
                                .font(.system(size: 25, weight: .black))
                                .foregroundColor(.white)
                                .opacity(0.8)
                        }
                        .padding(.horizontal)
                        Spacer()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showStatistic = true
                    } label: {
                        HStack {
                            Text("Stat.")
                            Image(systemName: "function")
                                .foregroundStyle(darkModeEnabled ? Color.white : Color.black)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .sheet(isPresented: $showStatistic) {
                MonthlyInvoiceSummaryView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
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
            .sheet(isPresented: $showFilters) {
                FiltersView(filterMinimum: $filterMinimum, orderDescending: $orderDescending,showUnpaid: $showUnpaid, showDueUnpaid: $showDueUnpaid, fromDate: $fromDate, toDate: $toDate, sortPaid: $sortPaid, showAllPosts: $showAllPosts)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(Font.system(size: 25, weight: .black))
                            .background(.clear)
                    }
                }
            }
            .sheet(isPresented: $showCreateCustomer,
                   content: {
                NavigationStack {
                    CreateCustomerView()
                }
            })
            .sheet(isPresented: $showInvoiceList,
                   content: {
                NavigationStack {
                    ListInvoiceView()
                        .environmentObject(model)
                }
            })
            .sheet(isPresented: $showingSettings) {
                SettingsView(name: $name, darkModeEnabled: $darkModeEnabled, showName: $showName, showStatus: $showStatus)
            }
        }
        .onAppear {
            showDueUnpaid = true
            showUnpaid = true
            showAllPosts = true
            showAllPosts = false
        }
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
    }
    
}
