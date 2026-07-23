import SwiftUI
import SwiftData
#if canImport(MessageUI)
import MessageUI
#endif

// Move these OUTSIDE the struct so they are in scope for the whole file
enum OwnerTab { case dashboard, employees, revenue, business }
enum CalendarScope: String, CaseIterable { case day = "Day", week = "Week", month = "Month" }

struct OwnerDashboard: View {
    @Environment(\.modelContext) private var modelContext
    var onLogout: (() -> Void)? = nil
    
    @Query(sort: \Appointment.startTime) private var allAppointments: [Appointment]
    @Query private var loggedInUsers: [User]
    @Query private var profiles: [BusinessProfile]
    
    // UI State
    @State private var isShowingSidePanel = false
    @State private var activeTab: OwnerTab = .dashboard
    @State private var selectedViewMode = "Calendar"
    @State private var calendarScope: CalendarScope = .day
    @State private var selectedDate = Date()
    @State private var searchText = ""
    
    // Business Management State
    @State private var isShowingServiceManager = false
    @State private var isShowingEmployeeManager = false
    @State private var isShowingBusinessProfile = false
    
    // Revenue Toggle State
    @State private var revenuePeriod: RevenuePeriod = .day
    
    // Appointment Management
    @State private var isShowingAddSheet = false
    @State private var selectedApptForChat: Appointment?
    @State private var selectedApptForEdit: Appointment?
    
    // Deletion State
    @State private var isShowingDeleteAlert = false
    @State private var appointmentToDelete: Appointment?
    
    let hours = Array(0...23)
    
    /// The owner's business code from their profile
    private var ownerBusinessCode: String {
        profiles.first?.businessCode ?? ""
    }
    
    var filteredAppointments: [Appointment] {
        let cleanSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cleanSearch.isEmpty { return allAppointments }
        return allAppointments.filter {
            $0.customerName.lowercased().contains(cleanSearch) ||
            $0.employeeName.lowercased().contains(cleanSearch)
        }
    }
    
    private var calculatedRevenue: Double {
        let calendar = Calendar.current
        let appointments: [Appointment]
        
        switch revenuePeriod {
        case .day:
            appointments = allAppointments.filter { calendar.isDate($0.startTime, inSameDayAs: selectedDate) }
        case .week:
            guard let range = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return 0 }
            appointments = allAppointments.filter { range.contains($0.startTime) }
        case .month:
            guard let range = calendar.dateInterval(of: .month, for: selectedDate) else { return 0 }
            appointments = allAppointments.filter { range.contains($0.startTime) }
        }
        return appointments.reduce(0.0) { $0 + $1.price }
    }
    
    var body: some View {
        ZStack {
            NavigationStack {
                ZStack {
                    Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                    VStack(spacing: 0) {
                        headerInterface
                        searchBarSection
                        
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(spacing: 20) {
                                    if activeTab == .dashboard {
                                        dashboardContent
                                    } else {
                                        ContentUnavailableView(columnTitle, systemImage: "hourglass")
                                    }
                                }
                                .padding(.top)
                            }
                            .onAppear { proxy.scrollTo(8, anchor: .top) }
                        }
                    }
                }
                .navigationTitle(columnTitle)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { withAnimation(.spring()) { isShowingSidePanel.toggle() } } label: {
                            Image(systemName: "line.3.horizontal.decrease").fontWeight(.bold).foregroundColor(.teal)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { isShowingAddSheet = true } label: {
                            Text("Add Appointment").font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(Color.teal).foregroundColor(.white).cornerRadius(8)
                        }
                    }
                }
                .sheet(isPresented: $isShowingAddSheet) { AddAppointmentSheet(businessCode: ownerBusinessCode) }
                .sheet(item: $selectedApptForChat) { appt in ModernChatView(appointment: appt) }
                .sheet(item: $selectedApptForEdit) { appt in
                    EditAppointmentSheet(appointment: appt, onOpenChat: { selectedApptForChat = appt })
                }
                .sheet(isPresented: $isShowingServiceManager) { ServiceManagerSheet(businessCode: ownerBusinessCode) }
                .sheet(isPresented: $isShowingEmployeeManager) { EmployeeManagerSheet(businessCode: ownerBusinessCode) }
                .sheet(isPresented: $isShowingBusinessProfile) { BusinessProfileSheet() }
                .alert("Delete Appointment?", isPresented: $isShowingDeleteAlert, presenting: appointmentToDelete) { appt in
                    Button("Delete", role: .destructive) { modelContext.delete(appt) }
                    Button("Cancel", role: .cancel) { appointmentToDelete = nil }
                } message: { appt in
                    Text("Are you sure you want to delete the appointment for \(appt.customerName)?")
                }
            }
            
            if isShowingSidePanel { sidePanelMenu }
        }
    }
    
    @ViewBuilder
    private var dashboardContent: some View {
        if selectedViewMode == "Calendar" {
            switch calendarScope {
            case .day: visualDayGrid
            case .week: weekGridView
            case .month: monthGridView
            }
        } else {
            supervisionQueue
        }
    }
    
    private var supervisionQueue: some View {
        VStack(spacing: 12) {
            if filteredAppointments.isEmpty {
                ContentUnavailableView("No Results", systemImage: "magnifyingglass")
                    .padding(.top, 40)
            } else {
                // Section header showing total count
                HStack {
                    Text("\(filteredAppointments.count) appointment\(filteredAppointments.count == 1 ? "" : "s")")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                
                ForEach(filteredAppointments) { appt in
                    // isOwner: true so employee name chip is shown on each card
                    AppointmentActionCard(
                        appt: appt,
                        actorName: loggedInUsers.first?.name ?? "Owner",
                        isOwner: true
                    )
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var sidePanelMenu: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.spring()) { isShowingSidePanel = false } }
            
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "crown.fill").foregroundColor(.teal)
                    Text("Pianivo Owner").font(.headline)
                }
                .padding(.top, 60)
                
                SideMenuButton(title: "Dashboard", icon: "square.grid.2x2.fill", isSelected: activeTab == .dashboard) {
                    withAnimation { isShowingSidePanel = false }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("MANAGE BUSINESS").font(.caption.bold()).foregroundColor(.secondary)
                    Button {
                        isShowingBusinessProfile = true
                        withAnimation { isShowingSidePanel = false }
                    } label: {
                        Label("Business Profile", systemImage: "building.2.fill")
                            .font(.subheadline).foregroundColor(.primary)
                    }
                    Button { isShowingServiceManager = true } label: { Label("Services & Prices", systemImage: "tag.fill").font(.subheadline).foregroundColor(.primary) }
                    Button { isShowingEmployeeManager = true } label: { Label("Staff Members", systemImage: "person.2.fill").font(.subheadline).foregroundColor(.primary) }
                }.padding(.horizontal, 5)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("REVENUE HUB").font(.caption.bold()).foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        ForEach([("D", RevenuePeriod.day), ("W", .week), ("M", .month)], id: \.1) { label, period in
                            Button(label) { revenuePeriod = period }
                                .font(.system(size: 10, weight: .bold)).frame(width: 32, height: 32)
                                .background(revenuePeriod == period ? Color.teal : Color.teal.opacity(0.1))
                                .foregroundColor(revenuePeriod == period ? .white : .teal)
                                .clipShape(Circle())
                        }
                    }
                    Text("$\(calculatedRevenue, specifier: "%.2f")").font(.title2.bold())
                }.padding(.horizontal, 5)

                Divider().padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 10) {
                    Text("PREFERENCES").font(.caption.bold()).foregroundColor(.secondary)
                    SoundToggleRow()
                        .padding(.horizontal, 2)
                }.padding(.horizontal, 5)

                Spacer()

                Button(role: .destructive) {
                    withAnimation { isShowingSidePanel = false }
                    onLogout?()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                    }
                    .font(.subheadline.bold()).padding().frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1)).cornerRadius(12)
                }
                .padding(.horizontal).padding(.bottom, 30)
            }
            .padding()
            .frame(width: 270)
            .background(Color(uiColor: .systemBackground))
            .transition(.move(edge: .leading))
        }
    }
    
    private var headerInterface: some View {
        VStack(spacing: 10) {
            HStack {
                ForEach(["Calendar", "List"], id: \.self) { mode in
                    Button { withAnimation { selectedViewMode = mode } } label: {
                        Text(mode).bold().frame(maxWidth: .infinity).padding(8)
                            .background(selectedViewMode == mode ? Color.teal : Color.clear)
                            .foregroundColor(selectedViewMode == mode ? .white : .primary).cornerRadius(8)
                    }
                }
            }
            if selectedViewMode == "Calendar" {
                Picker("", selection: $calendarScope) { ForEach(CalendarScope.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            }
        }.padding().background(Color(.systemBackground))
    }
    
    private var searchBarSection: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("Search name or staff...", text: $searchText).textFieldStyle(.plain).autocorrectionDisabled()
        }.padding(10).background(Color(.secondarySystemBackground)).cornerRadius(12).padding(.horizontal)
    }
    
    // MARK: - Calendar Views
    
    private var visualDayGrid: some View {
        VStack(spacing: 0) {
            dayNavigationHeader
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(hours, id: \.self) { hour in
                        HStack {
                            Text(formatHour(hour)).font(.system(size: 10)).foregroundColor(.secondary).frame(width: 50)
                            Rectangle().fill(Color.gray.opacity(0.15)).frame(height: 1)
                        }.frame(height: 60)
                    }
                }
                let dayAppts = filteredAppointments.filter { Calendar.current.isDate($0.startTime, inSameDayAs: selectedDate) }
                GeometryReader { geo in
                    ForEach(dayAppts) { appt in
                        dayApptBlock(appt: appt, dayAppts: dayAppts, totalWidth: geo.size.width)
                    }
                }
            }
            .frame(height: 60 * 24)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemBackground)))
        .padding(.horizontal)
    }
    
    private var dayNavigationHeader: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide))).font(.caption.bold()).foregroundColor(.teal)
                Text(selectedDate.formatted(.dateTime.day().month())).font(.title3.bold())
            }
            Spacer()
            HStack(spacing: 15) {
                Button("Today") { withAnimation { selectedDate = Date() } }.font(.caption.bold())
                Button(action: { changeDate(by: -1) }) { Image(systemName: "chevron.left").padding(8).background(Circle().fill(Color.teal.opacity(0.1))) }
                Button(action: { changeDate(by: 1) }) { Image(systemName: "chevron.right").padding(8).background(Circle().fill(Color.teal.opacity(0.1))) }
            }.foregroundColor(.teal)
        }.padding(.horizontal).padding(.bottom, 15)
    }
    
    private var weekGridView: some View {
        let weekDates = getWeekDates()
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer().frame(width: 45)
                ForEach(weekDates, id: \.self) { date in
                    VStack {
                        Text(date.formatted(.dateTime.weekday(.abbreviated))).font(.system(size: 10, weight: .bold))
                        Text(date.formatted(.dateTime.day())).font(.system(size: 10))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(Calendar.current.isDate(date, inSameDayAs: selectedDate) ? .teal : .secondary)
                }
            }.padding(.bottom, 10)
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    ForEach(hours, id: \.self) { hour in
                        Text(formatHour(hour)).font(.system(size: 8)).frame(height: 50).foregroundColor(.secondary)
                    }
                }.frame(width: 45)
                ForEach(weekDates, id: \.self) { date in
                    weekDayColumn(for: date).frame(maxWidth: .infinity).clipped()
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func weekDayColumn(for date: Date) -> some View {
        let dayAppts = filteredAppointments.filter { Calendar.current.isDate($0.startTime, inSameDayAs: date) }
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(hours, id: \.self) { _ in Rectangle().stroke(Color.gray.opacity(0.1), lineWidth: 0.5).frame(height: 50) }
            }
            GeometryReader { columnGeo in
                ForEach(dayAppts) { appt in
                    weekApptBlock(appt: appt, dayAppts: dayAppts, columnWidth: columnGeo.size.width)
                }
            }
        }
    }
    
    @ViewBuilder
    private func weekApptBlock(appt: Appointment, dayAppts: [Appointment], columnWidth: CGFloat) -> some View {
        let layout = weekBlockLayout(for: appt, in: dayAppts, columnWidth: columnWidth)
        AppointmentBlock(appt: appt, isMini: true)
            .onTapGesture { selectedApptForEdit = appt }
            .frame(width: layout.width, height: 45)
            .offset(x: layout.xOffset, y: layout.yOffset)
    }
    
    private struct BlockLayout { let width: CGFloat; let xOffset: CGFloat; let yOffset: CGFloat }
    
    private func weekBlockLayout(for appt: Appointment, in dayAppts: [Appointment], columnWidth: CGFloat) -> BlockLayout {
        let cal = Calendar.current
        let apptEnd = cal.date(byAdding: .hour, value: 1, to: appt.startTime) ?? appt.startTime
        let conflicts = dayAppts.filter { other in
            let otherEnd = cal.date(byAdding: .hour, value: 1, to: other.startTime) ?? other.startTime
            return other.startTime < apptEnd && appt.startTime < otherEnd
        }
        let myIndex = CGFloat(conflicts.firstIndex(where: { $0.id == appt.id }) ?? 0)
        let count = CGFloat(max(1, conflicts.count))
        let hour = cal.component(.hour, from: appt.startTime)
        let minute = cal.component(.minute, from: appt.startTime)
        let yOffset = (CGFloat(hour) * 50) + (CGFloat(minute) / 60 * 50)
        let width = columnWidth / count
        return BlockLayout(width: width, xOffset: myIndex * width, yOffset: yOffset)
    }
    
    private var monthGridView: some View {
        let days = getMonthDates()
        let columns = Array(repeating: GridItem(.flexible()), count: 7)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(["M","T","W","T","F","S","S"], id: \.self) { Text($0).font(.caption.bold()).foregroundColor(.secondary) }
            ForEach(days, id: \.self) { date in
                let dayAppts = filteredAppointments.filter { Calendar.current.isDate($0.startTime, inSameDayAs: date) }
                VStack(spacing: 2) {
                    Text(date.formatted(.dateTime.day())).font(.system(.subheadline, design: .rounded).bold()).frame(width: 28, height: 28)
                        .background(Calendar.current.isDate(date, inSameDayAs: selectedDate) ? Color.teal.opacity(0.2) : Color.clear)
                        .clipShape(Circle())
                    if !dayAppts.isEmpty { Circle().fill(Color.teal).frame(width: 5, height: 5) }
                }
                .onTapGesture { selectedDate = date; calendarScope = .day }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemBackground)))
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func dayApptBlock(appt: Appointment, dayAppts: [Appointment], totalWidth: CGFloat) -> some View {
        let cal = Calendar.current
        let apptEnd = cal.date(byAdding: .hour, value: 1, to: appt.startTime) ?? appt.startTime
        let conflicts = dayAppts.filter { other in
            let otherEnd = cal.date(byAdding: .hour, value: 1, to: other.startTime) ?? other.startTime
            return other.startTime < apptEnd && appt.startTime < otherEnd
        }
        let myIndex = CGFloat(conflicts.firstIndex(where: { $0.id == appt.id }) ?? 0)
        let count = CGFloat(max(1, conflicts.count))
        let hour = cal.component(.hour, from: appt.startTime)
        let minute = cal.component(.minute, from: appt.startTime)
        let yOffset = (CGFloat(hour) * 60) + (CGFloat(minute) / 60 * 60)
        let width = (totalWidth - 60) / count
        AppointmentBlock(appt: appt, isMini: false)
            .frame(width: width, height: 55)
            .onTapGesture { selectedApptForEdit = appt }
            .offset(x: 60 + (myIndex * width), y: yOffset)
    }
    
    private func getEmployeeColor(for name: String) -> Color {
        let palette: [Color] = [.teal, .indigo, .blue, .purple, .orange, .cyan, .mint, .pink]
        return palette[abs(name.hashValue) % palette.count]
    }
    
    private func changeDate(by days: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            withAnimation { selectedDate = d }
        }
    }
    
    private func getWeekDates() -> [Date] {
        let start = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
        return (0...6).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }
    
    private func getMonthDates() -> [Date] {
        let start = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: selectedDate))!
        return Calendar.current.range(of: .day, in: .month, for: start)!.compactMap { Calendar.current.date(byAdding: .day, value: $0 - 1, to: start) }
    }
    
    private func formatHour(_ hour: Int) -> String { "\(hour == 0 || hour == 12 ? 12 : hour % 12) \(hour >= 12 ? "PM" : "AM")" }
    private var columnTitle: String { "Management Dashboard" }
}

// MARK: - HELPERS

struct SideMenuButton: View {
    let title: String; let icon: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon).foregroundColor(isSelected ? .teal : .secondary).frame(width: 24)
                Text(title).foregroundColor(isSelected ? .primary : .secondary).font(.subheadline.bold()); Spacer()
            }.padding(.vertical, 12).padding(.horizontal, 10).background(isSelected ? Color.teal.opacity(0.1) : Color.clear).cornerRadius(10)
        }
    }
}

// MARK: - ADD APPOINTMENT SHEET (Owner — scoped to business)

struct AddAppointmentSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    let businessCode: String
    
    @Query(sort: \Employee.name) private var allEmployees: [Employee]
    @Query(sort: \Service.name) private var allServices: [Service]
    
    @State private var customerName = ""
    @State private var selectedEmployeeName = ""
    @State private var selectedService: Service?
    @State private var date = Date()
    @State private var duration: TimeInterval = 3600
    
    /// Only employees in this business
    private var employees: [Employee] {
        businessCode.isEmpty ? allEmployees : allEmployees.filter { $0.businessCode == businessCode }
    }
    
    /// Only services in this business
    private var services: [Service] {
        businessCode.isEmpty ? allServices : allServices.filter { $0.businessCode == businessCode }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Client Information") {
                    TextField("Customer Name", text: $customerName)
                }
                
                Section("Assign Staff & Service") {
                    Picker("Staff Member", selection: $selectedEmployeeName) {
                        Text("Select Staff").tag("")
                        ForEach(employees) { emp in Text(emp.name).tag(emp.name) }
                    }
                    Picker("Service Type", selection: $selectedService) {
                        Text("Select Service").tag(nil as Service?)
                        ForEach(services) { service in
                            Text("\(service.name) — \(service.price.formatted(.currency(code: "USD")))").tag(service as Service?)
                        }
                    }
                }
                
                Section("Schedule") {
                    DatePicker("Start Time", selection: $date)
                    Text("Price: \(selectedService?.price.formatted(.currency(code: "USD")) ?? "$0.00")")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("New Appointment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAppointment() }
                        .disabled(customerName.isEmpty || selectedEmployeeName.isEmpty || selectedService == nil)
                }
            }
        }
    }
    
    private func saveAppointment() {
        guard let service = selectedService else { return }
        let newAppt = Appointment(
            customerName: customerName, employeeName: selectedEmployeeName,
            startTime: date, endTime: date.addingTimeInterval(duration), price: service.price,
            businessCode: businessCode
        )
        newAppt.service = service
        modelContext.insert(newAppt)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - EDIT APPOINTMENT SHEET

struct EditAppointmentSheet: View {
    let appointment: Appointment
    var onOpenChat: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    Text("Customer: \(appointment.customerName)")
                    Text("Staff: \(appointment.employeeName)")
                }
                Button("Open Chat") { dismiss(); onOpenChat() }
            }
            .navigationTitle("Edit Appointment")
            .toolbar { Button("Close") { dismiss() } }
        }
    }
}

// MARK: - CHAT VIEW

struct ModernChatView: View {
    let appointment: Appointment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query(sort: \OwnerClientMessage.timestamp, order: .forward) private var allMessages: [OwnerClientMessage]
    @State private var newMessageText = ""
    
    var conversation: [OwnerClientMessage] {
        allMessages.filter { $0.clientName == appointment.customerName }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Color(.systemGroupedBackground).ignoresSafeArea()
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(conversation) { msg in ChatBubble(message: msg).id(msg.id) }
                            }.padding()
                        }
                        .onChange(of: conversation.count) { _, _ in
                            if let lastId = conversation.last?.id { withAnimation { proxy.scrollTo(lastId, anchor: .bottom) } }
                        }
                        .onAppear {
                            if let lastId = conversation.last?.id { proxy.scrollTo(lastId, anchor: .bottom) }
                        }
                    }
                }
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 12) {
                        TextField("Message \(appointment.customerName)...", text: $newMessageText, axis: .vertical)
                            .padding(10).background(Color(.secondarySystemBackground)).cornerRadius(20).lineLimit(1...5)
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                                .foregroundColor(newMessageText.isEmpty ? .gray : .teal)
                        }.disabled(newMessageText.isEmpty)
                    }
                    .padding(.horizontal).padding(.vertical, 10).background(.ultraThinMaterial)
                }
            }
            .navigationTitle(appointment.customerName).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
    
    private func sendMessage() {
        let trimmed = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let msg = OwnerClientMessage(content: trimmed, isFromOwner: true, clientName: appointment.customerName)
        modelContext.insert(msg); try? modelContext.save(); newMessageText = ""
    }
}

struct ChatBubble: View {
    let message: OwnerClientMessage
    var body: some View {
        HStack {
            if message.isFromOwner { Spacer() }
            VStack(alignment: message.isFromOwner ? .trailing : .leading) {
                Text(message.content).padding(12)
                    .background(message.isFromOwner ? Color.teal : Color(.systemGray5))
                    .foregroundColor(message.isFromOwner ? .white : .primary).cornerRadius(16)
                Text(message.timestamp.formatted(.dateTime.hour().minute())).font(.system(size: 8)).foregroundColor(.secondary)
            }
            if !message.isFromOwner { Spacer() }
        }
    }
}

// MARK: - SERVICE MANAGER (Business-Scoped)

struct ServiceManagerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    let businessCode: String
    
    @Query(sort: \Service.name) private var allServices: [Service]
    
    @State private var serviceName = ""
    @State private var servicePrice: Double? = nil
    @State private var selectedColor = "#008080"
    @State private var durationMinutes = 60
    @State private var category = ""
    @State private var serviceDescription = ""
    
    private let colorOptions = ["#008080", "#4B0082", "#0000FF", "#800080", "#FFA500", "#00FFFF", "#3EB489", "#FFC0CB"]
    private let categoryOptions = ["Hair", "Massage", "Facial", "Nails", "Music", "Fitness", "Wellness", "Other"]
    
    /// Only show services for THIS business
    private var services: [Service] {
        businessCode.isEmpty ? allServices : allServices.filter { $0.businessCode == businessCode }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Add New Service") {
                    VStack(spacing: 12) {
                        TextField("Service Name", text: $serviceName).textFieldStyle(.roundedBorder)
                        TextField("Description (optional)", text: $serviceDescription).textFieldStyle(.roundedBorder)
                        
                        HStack {
                            Text("Price")
                            Spacer()
                            TextField("Amount", value: $servicePrice, format: .number)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder).frame(width: 100)
                        }
                        
                        HStack {
                            Text("Duration")
                            Spacer()
                            Stepper("\(durationMinutes) min", value: $durationMinutes, in: 15...240, step: 15)
                        }
                        
                        Picker("Category", selection: $category) {
                            Text("General").tag("")
                            ForEach(categoryOptions, id: \.self) { Text($0).tag($0) }
                        }
                        
                        HStack {
                            Text("Color")
                            Spacer()
                            HStack(spacing: 8) {
                                ForEach(colorOptions, id: \.self) { hex in
                                    Circle().fill(Color(hex: hex) ?? .gray).frame(width: 20, height: 20)
                                        .overlay(Circle().stroke(Color.primary, lineWidth: selectedColor == hex ? 2 : 0))
                                        .onTapGesture { selectedColor = hex }
                                }
                            }
                        }
                        
                        Button(action: addService) {
                            Text("Create Service").frame(maxWidth: .infinity).padding(8)
                                .background(canSave ? Color.teal : Color.gray)
                                .foregroundColor(.white).cornerRadius(8)
                        }
                        .disabled(!canSave)
                    }
                    .padding(.vertical, 5)
                }
                
                Section("Existing Services (\(services.count))") {
                    if services.isEmpty {
                        Text("No services for this business yet.")
                            .font(.caption).foregroundColor(.secondary)
                    } else {
                        ForEach(services) { service in
                            HStack {
                                Circle().fill(service.themeColor).frame(width: 12, height: 12)
                                VStack(alignment: .leading) {
                                    Text(service.name).font(.body.bold())
                                    HStack(spacing: 8) {
                                        Text(service.price.formatted(.currency(code: "USD")))
                                        if !service.category.isEmpty { Text("• \(service.category)") }
                                        Text("• \(service.durationMinutes)min")
                                    }
                                    .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .onDelete(perform: deleteService)
                    }
                }
            }
            .navigationTitle("Services & Pricing")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
        }
    }
    
    private var canSave: Bool { !serviceName.isEmpty && servicePrice != nil }
    
    private func addService() {
        let finalPrice = servicePrice ?? 0.0
        let newService = Service(
            name: serviceName, price: finalPrice, colorHex: selectedColor,
            businessCode: businessCode, durationMinutes: durationMinutes,
            serviceDescription: serviceDescription, category: category
        )
        modelContext.insert(newService)
        serviceName = ""; servicePrice = nil; serviceDescription = ""; category = ""
    }
    
    private func deleteService(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(services[index]) }
    }
}

// MARK: - EMPLOYEE MANAGER WITH DEEP LINK INVITES

struct EmployeeManagerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    let businessCode: String
    
    @Query(sort: \Employee.name) private var allEmployees: [Employee]
    @Query private var profiles: [BusinessProfile]
    
    @State private var newEmployeeName = ""
    @State private var isShowingInviteSheet = false
    
    /// Studio name from profile
    private var studioName: String { profiles.first?.studioName ?? "Our Studio" }
    
    /// Only employees in this business
    private var employees: [Employee] {
        businessCode.isEmpty ? allEmployees : allEmployees.filter { $0.businessCode == businessCode }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Business Code Banner
                if !businessCode.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Your Studio Code", systemImage: "qrcode").font(.caption.bold()).foregroundColor(.teal)
                            Text(businessCode)
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .foregroundColor(.teal)
                            Text("Employees enter this code when signing up to join your studio.")
                                .font(.caption).foregroundColor(.secondary)
                            
                            Button {
                                UIPasteboard.general.string = businessCode
                            } label: {
                                Label("Copy Code", systemImage: "doc.on.doc")
                                    .font(.caption.bold()).foregroundColor(.teal)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    
                    Section {
                        Button {
                            isShowingInviteSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "envelope.badge.fill").foregroundColor(.teal)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Send Invite Link").font(.subheadline.bold())
                                    Text("Email a deep link that auto-fills your studio code").font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Section("Add Staff Manually") {
                    HStack {
                        TextField("Employee Name", text: $newEmployeeName)
                        Button(action: addEmployee) {
                            Image(systemName: "plus.circle.fill").foregroundColor(.teal).font(.title3)
                        }
                        .disabled(newEmployeeName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                
                Section("Current Staff (\(employees.count))") {
                    if employees.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "person.2.slash").font(.title2).foregroundColor(.secondary)
                            Text("No staff yet. Add manually or send an invite link.")
                                .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                    } else {
                        ForEach(employees) { employee in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(Color.teal.opacity(0.1)).frame(width: 36, height: 36)
                                    Text(employee.name.prefix(1).uppercased())
                                        .font(.subheadline.bold()).foregroundColor(.teal)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(employee.name).font(.body)
                                    Text("Joined \(employee.joinDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption2).foregroundColor(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteEmployees)
                    }
                }
            }
            .navigationTitle("Staff Management")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
            .sheet(isPresented: $isShowingInviteSheet) {
                StaffInviteSheet(businessCode: businessCode, studioName: studioName)
            }
        }
    }
    
    private func addEmployee() {
        let employee = Employee(name: newEmployeeName, businessCode: businessCode)
        modelContext.insert(employee)
        newEmployeeName = ""
        try? modelContext.save()
    }
    
    private func deleteEmployees(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(employees[index]) }
    }
}

// MARK: - STAFF INVITE SHEET (with Deep Link)

struct StaffInviteSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let businessCode: String
    let studioName: String
    
    @State private var recipientEmail = ""
    @State private var codeCopied = false
    @State private var linkCopied = false
#if canImport(MessageUI)
    @State private var showMailComposer = false
    @State private var mailNotAvailable = false
#endif
    
    /// Deep link URL employees can tap to auto-fill the invite code on signup
    private var deepLink: String {
        makeInviteDeepLink(businessCode: businessCode, businessName: studioName)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus").font(.system(size: 50)).foregroundColor(.teal)
                        Text("Invite Staff").font(.title2.bold())
                        Text("Share your studio code or send an invite link directly to your employee's email.")
                            .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Studio Code Block
                    VStack(spacing: 12) {
                        Text("STUDIO CODE").font(.caption.bold()).foregroundColor(.secondary).tracking(1.5)
                        Text(businessCode)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundColor(.teal)
                            .padding(.vertical, 18).padding(.horizontal, 30)
                            .background(Color.teal.opacity(0.08)).cornerRadius(16)
                        Button {
                            UIPasteboard.general.string = businessCode
                            withAnimation { codeCopied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { codeCopied = false } }
                        } label: {
                            Label(codeCopied ? "Copied!" : "Copy Code", systemImage: codeCopied ? "checkmark" : "doc.on.doc")
                                .font(.subheadline.bold()).foregroundColor(codeCopied ? .green : .teal)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
                    .padding(.horizontal)
                    
                    // Deep Link Block
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Invite Link", systemImage: "link").font(.caption.bold()).foregroundColor(.secondary)
                        Text(deepLink)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .padding(10)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(8)
                        
                        Text("When tapped on a device with the app, this link will open Pianivo and pre-fill your studio code automatically.")
                            .font(.caption).foregroundColor(.secondary)
                        
                        Button {
                            UIPasteboard.general.string = deepLink
                            withAnimation { linkCopied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { linkCopied = false } }
                        } label: {
                            Label(linkCopied ? "Copied!" : "Copy Link", systemImage: linkCopied ? "checkmark" : "link")
                                .font(.subheadline.bold()).foregroundColor(linkCopied ? .green : .teal)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
                    .padding(.horizontal)
                    
                    // Send Email Section
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("Send Invite via Email")
                        AuthField(icon: "envelope", placeholder: "Employee's email address", text: $recipientEmail, isSecure: false)
                    }
                    .padding(.horizontal)
                    
                    Button {
#if canImport(MessageUI)
                        if MFMailComposeViewController.canSendMail() {
                            showMailComposer = true
                        } else {
                            mailNotAvailable = true
                        }
#endif
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "paperplane.fill")
                            Text("Send Invite Email").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(recipientEmail.contains("@") ? Color.teal : Color.gray.opacity(0.4))
                        .foregroundColor(.white).cornerRadius(16)
                    }
                    .disabled(!recipientEmail.contains("@"))
                    .padding(.horizontal)
                    
                    Text("The email includes your studio code, a tap-to-join link, and sign-up instructions.")
                        .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal).padding(.bottom, 40)
                }
            }
            .navigationTitle("Invite Staff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
#if canImport(MessageUI)
            .sheet(isPresented: $showMailComposer) {
                MailComposerView(recipient: recipientEmail, subject: "You're invited to join \(studioName) on Pianivo!", body: inviteBody())
            }
            .alert("Mail Not Available", isPresented: $mailNotAvailable) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Mail is not configured on this device. Copy the link above and share it manually.")
            }
#endif
        }
    }
    
    private func inviteBody() -> String {
"""
Hi there,

You've been invited to join \(studioName) on Pianivo — mindful appointment scheduling.

Here's how to get started:

1. Open Pianivo on your device (or download it from the App Store).
2. Tap the link below to be taken directly to signup with your studio code pre-filled:

\(deepLink)

   — OR —

   Tap "Create Account", choose "Employee / Staff", and enter your invite code manually:

   Studio Code: \(businessCode)

Once you're in, you'll have access to your schedule, appointments, and client messages.

Looking forward to working with you!

— \(studioName) Team
"""
    }
}

// MARK: - MAIL COMPOSER

#if canImport(MessageUI)
struct MailComposerView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            dismiss()
        }
    }
}
#endif

// MARK: - AppointmentBlock (Calendar visual)

struct AppointmentBlock: View {
    let appt: Appointment
    let isMini: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(appt.customerName).font(.system(size: isMini ? 8 : 12, weight: .bold))
            if !isMini { Text(appt.service?.name ?? "Service").font(.system(size: 10)).opacity(0.8) }
        }
        .padding(4).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.teal.opacity(0.15)).cornerRadius(6)
        .overlay(Rectangle().fill(Color.teal).frame(width: 3), alignment: .leading)
    }
}

// MARK: - BUSINESS PROFILE SHEET

struct BusinessProfileSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [BusinessProfile]
    
    @State private var studioName = ""
    @State private var address = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var website = ""
    @State private var about = ""
    @State private var businessCategory = ""
    @State private var mondayHours = "9:00 AM – 6:00 PM"
    @State private var tuesdayHours = "9:00 AM – 6:00 PM"
    @State private var wednesdayHours = "9:00 AM – 6:00 PM"
    @State private var thursdayHours = "9:00 AM – 6:00 PM"
    @State private var fridayHours = "9:00 AM – 6:00 PM"
    @State private var saturdayHours = "10:00 AM – 4:00 PM"
    @State private var sundayHours = "Closed"
    @State private var saved = false
    
    private let categoryOptions = ["Wellness", "Music", "Beauty", "Fitness", "Healthcare", "Education", "Other"]
    private var existingProfile: BusinessProfile? { profiles.first }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Color.teal.opacity(0.12)).frame(width: 56, height: 56)
                            Image(systemName: "building.2.fill").font(.title2).foregroundColor(.teal)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(studioName.isEmpty ? "Your Studio" : studioName).font(.headline)
                            Text("Business Profile").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Label("Business Info", systemImage: "building.2")) {
                    ProfileField(icon: "building.2", placeholder: "Business name", text: $studioName)
                    ProfileField(icon: "doc.text", placeholder: "About your business", text: $about)
                    Picker("Business Category", selection: $businessCategory) {
                        Text("Select Category").tag("")
                        ForEach(categoryOptions, id: \.self) { Text($0).tag($0) }
                    }
                }
                
                Section(header: Label("Location", systemImage: "mappin.circle")) {
                    ProfileField(icon: "mappin", placeholder: "Street address", text: $address)
                    ProfileField(icon: "building.columns", placeholder: "City", text: $city)
                    HStack(spacing: 12) {
                        ProfileField(icon: "map", placeholder: "State", text: $state)
                        ProfileField(icon: "number", placeholder: "ZIP", text: $zipCode)
                    }
                }
                
                Section(header: Label("Contact", systemImage: "phone.circle")) {
                    ProfileField(icon: "phone", placeholder: "Phone number", text: $phone)
                    ProfileField(icon: "envelope", placeholder: "Business email", text: $email)
                    ProfileField(icon: "globe", placeholder: "Website (optional)", text: $website)
                }
                
                Section(header: Label("Hours of Operation", systemImage: "clock")) {
                    HoursRow(day: "Monday",    hours: $mondayHours)
                    HoursRow(day: "Tuesday",   hours: $tuesdayHours)
                    HoursRow(day: "Wednesday", hours: $wednesdayHours)
                    HoursRow(day: "Thursday",  hours: $thursdayHours)
                    HoursRow(day: "Friday",    hours: $fridayHours)
                    HoursRow(day: "Saturday",  hours: $saturdayHours)
                    HoursRow(day: "Sunday",    hours: $sundayHours)
                }
                
                Section {
                    Button(action: saveProfile) {
                        HStack {
                            Spacer()
                            if saved {
                                Label("Saved!", systemImage: "checkmark.circle.fill").foregroundColor(.green).fontWeight(.semibold)
                            } else {
                                Label("Save Business Profile", systemImage: "square.and.arrow.down").foregroundColor(.white).fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .background(saved ? Color.green.opacity(0.1) : Color.teal).cornerRadius(10)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Business Profile").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear { loadProfile() }
        }
    }
    
    private func loadProfile() {
        guard let p = existingProfile else { return }
        studioName = p.studioName; address = p.address; city = p.city; state = p.state; zipCode = p.zipCode
        phone = p.phone; email = p.email; website = p.website; about = p.about; businessCategory = p.businessCategory
        mondayHours = p.mondayHours; tuesdayHours = p.tuesdayHours; wednesdayHours = p.wednesdayHours
        thursdayHours = p.thursdayHours; fridayHours = p.fridayHours; saturdayHours = p.saturdayHours; sundayHours = p.sundayHours
    }
    
    private func saveProfile() {
        let profile: BusinessProfile
        if let existing = existingProfile {
            profile = existing
        } else {
            profile = BusinessProfile()
            // Generate business code if new profile
            if profile.businessCode.isEmpty {
                profile.businessCode = String(UUID().uuidString.prefix(8).uppercased())
            }
            modelContext.insert(profile)
        }
        profile.studioName = studioName; profile.address = address; profile.city = city; profile.state = state
        profile.zipCode = zipCode; profile.phone = phone; profile.email = email; profile.website = website
        profile.about = about; profile.businessCategory = businessCategory
        profile.mondayHours = mondayHours; profile.tuesdayHours = tuesdayHours; profile.wednesdayHours = wednesdayHours
        profile.thursdayHours = thursdayHours; profile.fridayHours = fridayHours
        profile.saturdayHours = saturdayHours; profile.sundayHours = sundayHours
        try? modelContext.save()
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { saved = false } }
    }
}

// MARK: - PROFILE FIELD

struct ProfileField: View {
    let icon: String; let placeholder: String; @Binding var text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(.teal).frame(width: 18)
            TextField(placeholder, text: $text).autocorrectionDisabled()
        }
    }
}

// MARK: - HOURS ROW

struct HoursRow: View {
    let day: String; @Binding var hours: String
    private let presets = ["Closed", "9:00 AM – 5:00 PM", "9:00 AM – 6:00 PM", "9:00 AM – 8:00 PM", "10:00 AM – 4:00 PM", "10:00 AM – 6:00 PM", "By Appointment"]
    
    var body: some View {
        HStack {
            Text(day).font(.subheadline).frame(width: 90, alignment: .leading)
                .foregroundColor(hours == "Closed" ? .secondary : .primary)
            Spacer()
            Menu {
                ForEach(presets, id: \.self) { preset in Button(preset) { hours = preset } }
                Divider()
                Button("Custom...") { hours = "" }
            } label: {
                HStack(spacing: 4) {
                    Text(hours.isEmpty ? "Set hours" : hours).font(.subheadline)
                        .foregroundColor(hours == "Closed" ? .secondary : .teal)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 10)).foregroundColor(.teal)
                }
            }
            if hours.isEmpty {
                TextField("e.g. 10 AM – 2 PM", text: $hours).font(.subheadline)
                    .multilineTextAlignment(.trailing).frame(maxWidth: 140)
            }
        }
    }
}
