import SwiftUI
import SwiftData

// MARK: - EMPLOYEE DASHBOARD

struct EmployeeDashboard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Appointment.startTime, order: .forward) private var allAppointments: [Appointment]
    @Query private var profiles: [BusinessProfile]
    
    let employeeName: String
    var businessCode: String = ""
    var onLogout: (() -> Void)?
    var onAccountDeleted: (() -> Void)?
    
    @State private var calendarScope: RevenuePeriod = .day
    @State private var selectedDate = Date()
    @State private var isShowingSidePanel = false
    @State private var isShowingAddAppointment = false
    @State private var isShowingMessages = false
    @State private var isShowingSupport = false
    @State private var isShowingSettings = false
    @State private var selectedApptForEdit: Appointment? = nil
    @State private var viewMode: DashboardViewMode = .calendar
    
    enum DashboardViewMode { case list, calendar }
    
    private let hours = Array(0...23)
    private let hourHeight: CGFloat = 60
    
    private var myAppointments: [Appointment] {
        allAppointments.filter { $0.employeeName == employeeName }
    }
    private var todayEarnings: Double {
        myAppointments
            .filter { Calendar.current.isDateInToday($0.startTime) && $0.statusRaw == "Completed" }
            .reduce(0) { $0 + $1.price }
    }

    private var businessSupportEmail: String? {
        let matchedProfile = profiles.first { $0.businessCode == businessCode }
        if let email = matchedProfile?.email.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            return email
        }
        return nil
    }

    // ── Day Load & Rhythm ─────────────────────────────────────────────────
    private var selectedDayAppointments: [Appointment] {
        myAppointments.filter { Calendar.current.isDate($0.startTime, inSameDayAs: selectedDate) }
    }
    private var selectedDayLoad: DayLoad {
        calculateDayLoad(from: selectedDayAppointments)
    }
    private var balanceSuggestions: [BalanceSuggestion] {
        BalanceSuggestionEngine.suggestions(for: myAppointments, on: selectedDate)
    }
    private var earningsForSelectedDay: Double {
        selectedDayAppointments
            .filter { $0.statusRaw == "Completed" }
            .reduce(0) { $0 + $1.price }
    }
    private let sound = SoundFeedbackManager.shared
    
    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    if viewMode == .calendar {
                        ScrollView {
                            VStack(spacing: 0) {
                                wellnessHeader
                                Picker("Scope", selection: $calendarScope) {
                                    ForEach([RevenuePeriod.day, .week, .month]) { s in Text(s.rawValue.capitalized).tag(s) }
                                }
                                .pickerStyle(.segmented).padding()
                                switch calendarScope {
                                case .day:   visualDayGrid
                                case .week:  weekGridView
                                case .month: monthGridView
                                case .year:  monthGridView
                                }
                            }
                        }
                    } else {
                        EmployeeAppointmentListView(appointments: myAppointments, employeeName: employeeName)
                    }
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("My Schedule")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { withAnimation { isShowingSidePanel.toggle() } } label: {
                            Image(systemName: "line.3.horizontal")
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Picker("View", selection: $viewMode) {
                            Image(systemName: "calendar").tag(DashboardViewMode.calendar)
                            Image(systemName: "list.bullet").tag(DashboardViewMode.list)
                        }
                        .pickerStyle(.segmented).frame(width: 90)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { isShowingAddAppointment = true } label: {
                            Text("Add").font(.subheadline.bold()).foregroundColor(.teal)
                        }
                    }
                }
            }
            
            if isShowingSidePanel {
                Color.black.opacity(0.3).ignoresSafeArea()
                    .onTapGesture { withAnimation { isShowingSidePanel = false } }
                HStack {
                    employeeSidePanel.frame(width: 280).transition(.move(edge: .leading))
                    Spacer()
                }
                .zIndex(2)
            }
        }
        .sheet(isPresented: $isShowingAddAppointment) {
            EmployeeAddAppointmentSheet(fixedEmployeeName: employeeName, businessCode: businessCode, existingAppointments: myAppointments)
        }
        .sheet(item: $selectedApptForEdit) { appt in RescheduleSheetView(appointment: appt) }
        .sheet(isPresented: $isShowingMessages) {
            EmployeeInboxView(employeeName: employeeName, allClientNames: Array(Set(myAppointments.map { $0.customerName })))
        }
        .sheet(isPresented: $isShowingSupport) {
            SupportReportSheet(
                accountName: employeeName,
                accountType: "Employee",
                businessSupportEmail: businessSupportEmail
            )
        }
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                AccountSettingsView(role: .employee, displayName: employeeName) {
                    isShowingSettings = false
                    onAccountDeleted?()
                }
            }
        }
    }
    
    // MARK: - Header
    private var wellnessHeader: some View {
        RhythmHeaderView(
            load: selectedDayLoad,
            date: selectedDate,
            earnings: Calendar.current.isDateInToday(selectedDate) ? todayEarnings : earningsForSelectedDay,
            suggestions: balanceSuggestions
        )
        .padding(.horizontal)
    }
    
    // MARK: - Day Grid
    private var visualDayGrid: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { changeDate(by: -1) }) { Image(systemName: "chevron.left") }
                Spacer()
                Text(selectedDate.formatted(date: .abbreviated, time: .omitted)).font(.headline)
                Spacer()
                Button(action: { changeDate(by: 1) }) { Image(systemName: "chevron.right") }
            }.padding(.bottom)
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(hours, id: \.self) { h in
                        HStack {
                            Text(formatHour(h)).font(.system(size: 10)).foregroundColor(.secondary).frame(width: 50)
                            Rectangle().fill(Color.gray.opacity(0.15)).frame(height: 1)
                        }.frame(height: hourHeight)
                    }
                }
                let dayAppts = myAppointments.filter { Calendar.current.isDate($0.startTime, inSameDayAs: selectedDate) }
                GeometryReader { geo in
                    let blockWidth = max(1, geo.size.width - 60)
                    let load = selectedDayLoad
                    ForEach(dayAppts) { appt in
                        let c = Calendar.current.dateComponents([.hour, .minute], from: appt.startTime)
                        let rawDur = appt.endTime.timeIntervalSince(appt.startTime) / 3600.0
                        let dur = rawDur.isFinite && rawDur > 0 ? rawDur : 1.0
                        let y = CGFloat(c.hour ?? 0) * hourHeight + CGFloat(c.minute ?? 0) / 60 * hourHeight
                        DashboardAppointmentBlock(appt: appt, isMini: false, dayLoad: load)
                            .frame(width: blockWidth, height: max(45, CGFloat(dur) * hourHeight))
                            .onTapGesture { selectedApptForEdit = appt }
                            .offset(x: 60, y: y)
                    }
                }
            }
            .frame(height: hourHeight * 24)
        }
        .padding().background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemBackground))).padding(.horizontal)
    }
    
    // MARK: - Week Grid
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
                    ForEach(hours, id: \.self) { h in Text(formatHour(h)).font(.system(size: 8)).frame(height: 50).foregroundColor(.secondary) }
                }.frame(width: 45)
                ForEach(weekDates, id: \.self) { date in
                    ZStack(alignment: .topLeading) {
                        VStack(spacing: 0) { ForEach(hours, id: \.self) { _ in Rectangle().stroke(Color.gray.opacity(0.1), lineWidth: 0.5).frame(height: 50) } }
                        let da = myAppointments.filter { Calendar.current.isDate($0.startTime, inSameDayAs: date) }
                        GeometryReader { geo in
                            let wLoad = calculateDayLoad(from: da)
                            ForEach(da) { appt in
                                let h = Calendar.current.component(.hour, from: appt.startTime)
                                let m = Calendar.current.component(.minute, from: appt.startTime)
                                DashboardAppointmentBlock(appt: appt, isMini: true, dayLoad: wLoad)
                                    .frame(width: geo.size.width, height: 45)
                                    .onTapGesture { selectedApptForEdit = appt }
                                    .offset(y: CGFloat(h) * 50 + CGFloat(m) / 60 * 50)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity).clipped()
                }
            }
        }
        .padding().background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemBackground))).padding(.horizontal)
    }
    
    // MARK: - Month Grid
    private var monthGridView: some View {
        let days = getMonthDates()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 15) {
            ForEach(["M","T","W","T","F","S","S"], id: \.self) { Text($0).font(.caption.bold()).foregroundColor(.secondary) }
            ForEach(days, id: \.self) { date in
                let dayAppts = myAppointments.filter { Calendar.current.isDate($0.startTime, inSameDayAs: date) }
                let load = calculateDayLoad(from: dayAppts)
                let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                VStack(spacing: 2) {
                    Text(date.formatted(.dateTime.day())).font(.system(.subheadline, design: .rounded).bold())
                        .frame(width: 30, height: 30)
                        .background(isSelected ? load.color.opacity(0.22) : Color.clear)
                        .foregroundColor(isSelected ? load.color : .primary)
                        .clipShape(Circle())
                    if !dayAppts.isEmpty {
                        Circle().fill(load.color).frame(width: 5, height: 5)
                    }
                }
                .onTapGesture { selectedDate = date; calendarScope = .day }
            }
        }
        .padding().background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemBackground))).padding(.horizontal)
    }
    
    // MARK: - Side Panel
    private var employeeSidePanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                
                // ── Profile Header ────────────────────────────────────
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [Color.teal, Color.teal.opacity(0.7)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 170)
                    VStack(alignment: .leading, spacing: 6) {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.25)).frame(width: 52, height: 52)
                            Text(employeeName.prefix(1).uppercased())
                                .font(.title2.bold()).foregroundColor(.white)
                        }
                        Text(employeeName).font(.headline).foregroundColor(.white)
                        Text("Staff Member").font(.caption).foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 20).padding(.bottom, 18)
                }
                
                // ── Today's Stats ─────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("TODAY").font(.caption2.bold()).foregroundColor(.secondary).tracking(1.2)
                        .padding(.horizontal, 20).padding(.top, 16)
                    
                    HStack(spacing: 10) {
                        employeeStatMini(
                            label: "Sessions",
                            value: "\(myAppointments.filter { Calendar.current.isDateInToday($0.startTime) }.count)",
                            icon: "calendar.circle.fill",
                            color: .teal
                        )
                        employeeStatMini(
                            label: "Earnings",
                            value: todayEarnings.formatted(.currency(code: "USD")),
                            icon: "dollarsign.circle.fill",
                            color: .green
                        )
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.bottom, 8)
                
                Divider().padding(.vertical, 4)
                
                // ── Navigation Items ──────────────────────────────────
                Group {
                    Text("NAVIGATION").font(.caption2.bold()).foregroundColor(.secondary).tracking(1.2)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                    
                    // Calendar
                    sidePanelNavButton(
                        label: "My Schedule",
                        icon: "calendar",
                        color: .teal
                    ) {
                        viewMode = .calendar
                        withAnimation { isShowingSidePanel = false }
                    }
                    
                    // List
                    sidePanelNavButton(
                        label: "Appointment List",
                        icon: "list.bullet.clipboard",
                        color: .indigo
                    ) {
                        viewMode = .list
                        withAnimation { isShowingSidePanel = false }
                    }
                    
                    // Messages
                    sidePanelNavButton(
                        label: "Messages",
                        icon: "envelope.fill",
                        color: .blue,
                        badge: myAppointments.count > 0 ? "\(myAppointments.count)" : nil
                    ) {
                        isShowingMessages = true
                        withAnimation { isShowingSidePanel = false }
                    }
                    
                    // Add Appointment
                    sidePanelNavButton(
                        label: "New Appointment",
                        icon: "plus.circle.fill",
                        color: .orange
                    ) {
                        isShowingAddAppointment = true
                        withAnimation { isShowingSidePanel = false }
                    }

                    sidePanelNavButton(
                        label: "Settings",
                        icon: "gearshape.fill",
                        color: .teal
                    ) {
                        isShowingSettings = true
                        withAnimation { isShowingSidePanel = false }
                    }

                    sidePanelNavButton(
                        label: "Support & Errors",
                        icon: "questionmark.bubble.fill",
                        color: .teal
                    ) {
                        isShowingSupport = true
                        withAnimation { isShowingSidePanel = false }
                    }
                }
                
                Divider().padding(.vertical, 4)
                
                // ── Upcoming Next Session ─────────────────────────────
                if let next = myAppointments.first(where: { $0.startTime > Date() }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NEXT SESSION").font(.caption2.bold()).foregroundColor(.secondary).tracking(1.2)
                            .padding(.horizontal, 20).padding(.top, 10)
                        
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.teal).frame(width: 3)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(next.customerName).font(.subheadline.bold()).lineLimit(1)
                                Text(next.startTime.formatted(date: .omitted, time: .shortened))
                                    .font(.caption).foregroundColor(.secondary)
                                if let svc = next.service {
                                    Text(svc.name).font(.caption2).foregroundColor(.teal).lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.teal.opacity(0.06))
                        .cornerRadius(14)
                        .padding(.horizontal, 14)
                    }
                    .padding(.bottom, 8)
                    
                    Divider().padding(.vertical, 4)
                }
                
                // ── Quick Actions ─────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("QUICK ACTIONS").font(.caption2.bold()).foregroundColor(.secondary).tracking(1.2)
                        .padding(.horizontal, 20).padding(.top, 10)
                    
                    HStack(spacing: 10) {
                        quickActionButton(label: "Jump to Today", icon: "clock.arrow.circlepath", color: .purple) {
                            selectedDate = Date()
                            calendarScope = .day
                            withAnimation { isShowingSidePanel = false }
                        }
                        quickActionButton(label: "This Week", icon: "calendar.badge.clock", color: .teal) {
                            selectedDate = Date()
                            calendarScope = .week
                            withAnimation { isShowingSidePanel = false }
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.bottom, 12)
                
                Divider().padding(.vertical, 4)
                
                // ── Performance Summary ───────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("THIS WEEK").font(.caption2.bold()).foregroundColor(.secondary).tracking(1.2)
                        .padding(.horizontal, 20).padding(.top, 10)
                    
                    let weekDates = getWeekDates()
                    let weekAppts = myAppointments.filter { appt in
                        weekDates.contains { Calendar.current.isDate($0, inSameDayAs: appt.startTime) }
                    }
                    let weekEarnings = weekAppts.filter { $0.statusRaw == "Completed" }.reduce(0.0) { $0 + $1.price }
                    
                    HStack(spacing: 10) {
                        employeeStatMini(label: "Sessions", value: "\(weekAppts.count)", icon: "person.2.fill", color: .indigo)
                        employeeStatMini(label: "Revenue", value: weekEarnings.formatted(.currency(code: "USD")), icon: "chart.line.uptrend.xyaxis", color: .green)
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.bottom, 20)
                
                Divider().padding(.vertical, 4)
                
                // ── Sign Out ──────────────────────────────────────────
                Button(role: .destructive) {
                    withAnimation { isShowingSidePanel = false }
                    onLogout?()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red).frame(width: 22)
                        Text("Sign Out").font(.subheadline.bold()).foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.horizontal, 20).padding(.vertical, 16).contentShape(Rectangle())
                }
                .padding(.bottom, 30)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .vertical)
    }
    
    // MARK: - Side Panel Helpers
    
    private func sidePanelNavButton(label: String, icon: String, color: Color, badge: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 32, height: 32)
                    Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundColor(color)
                }
                Text(label).font(.subheadline).foregroundColor(.primary)
                Spacer()
                if let badge = badge {
                    Text(badge).font(.caption2.bold()).foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.teal).clipShape(Capsule())
                }
                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary)
            }
            .padding(.horizontal, 20).padding(.vertical, 11).contentShape(Rectangle())
        }
    }
    
    private func employeeStatMini(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption2).foregroundColor(color)
                Text(label).font(.caption2).foregroundColor(.secondary)
            }
            Text(value).font(.system(.subheadline, design: .rounded).bold())
                .foregroundColor(.primary).minimumScaleFactor(0.6).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func quickActionButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title3).foregroundColor(color)
                Text(label).font(.caption2.bold()).foregroundColor(.primary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
    
    private func changeDate(by n: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: n, to: selectedDate) { selectedDate = d }
    }
    private func formatHour(_ h: Int) -> String {
        let f = DateFormatter(); f.dateFormat = "h a"
        return f.string(from: Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: Date()) ?? Date())
    }
    private func getWeekDates() -> [Date] {
        let c = Calendar.current
        return (0...6).compactMap { c.date(byAdding: .day, value: $0, to: c.date(from: c.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!) }
    }
    private func getMonthDates() -> [Date] {
        let c = Calendar.current
        let s = c.date(from: c.dateComponents([.year, .month], from: selectedDate))!
        return c.range(of: .day, in: .month, for: s)!.compactMap { c.date(byAdding: .day, value: $0 - 1, to: s) }
    }
}

// MARK: - APPOINTMENT LIST VIEW (Employee — my appointments only)

struct EmployeeAppointmentListView: View {
    let appointments: [Appointment]
    let employeeName: String
    
    var body: some View {
        List {
            if appointments.isEmpty {
                ContentUnavailableView("No Sessions", systemImage: "calendar.badge.exclamationmark")
            } else {
                ForEach(appointments) { appt in
                    AppointmentActionCard(appt: appt, actorName: employeeName, isOwner: false)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - APPOINTMENT ACTION CARD
// Shared by both Employee and Owner list views.
// isOwner: shows employee name chip; actorName used for chat thread.

struct AppointmentActionCard: View {
    @Bindable var appt: Appointment
    let actorName: String   // employeeName for employee; ownerName for owner
    var isOwner: Bool = false
    @Environment(\.modelContext) private var modelContext
    
    @State private var showConfirmAlert  = false
    @State private var showRejectAlert   = false
    @State private var showCompleteAlert = false
    @State private var showReschedule    = false
    @State private var showChat          = false
    
    // Status-driven visuals
    private var accent: Color {
        switch appt.status {
        case .confirmed: return .teal
        case .completed: return .green
        case .cancelled: return .gray
        case .pending:   return .orange
        }
    }
    private var bg: Color {
        switch appt.status {
        case .confirmed: return Color.teal.opacity(0.05)
        case .completed: return Color.green.opacity(0.05)
        case .cancelled: return Color(.secondarySystemBackground)
        case .pending:   return Color.orange.opacity(0.05)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Info section ────────────────────────────────────────
            HStack(alignment: .top, spacing: 12) {
                // Left colour strip — animates on status change
                RoundedRectangle(cornerRadius: 3)
                    .fill(accent)
                    .frame(width: 4)
                    .animation(.easeInOut(duration: 0.3), value: appt.status)
                
                VStack(alignment: .leading, spacing: 7) {
                    // Name + badge row
                    HStack(alignment: .center) {
                        Text(appt.customerName)
                            .font(.headline)
                            .strikethrough(appt.status == .cancelled, color: .secondary)
                            .foregroundColor(appt.status == .cancelled ? .secondary : .primary)
                            .lineLimit(1)
                        Spacer()
                        statusBadge
                    }
                    
                    // Time + service
                    HStack(spacing: 5) {
                        Image(systemName: "clock").font(.caption2).foregroundColor(.secondary)
                        Text(appt.startTime.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundColor(.secondary)
                        if let svc = appt.service {
                            Text("·").foregroundColor(.secondary)
                            Text(svc.name).font(.caption).foregroundColor(.secondary).lineLimit(1)
                        }
                    }
                    
                    // Employee chip (owner view only) + price
                    HStack(spacing: 8) {
                        if isOwner {
                            HStack(spacing: 4) {
                                Image(systemName: "person.circle.fill").font(.caption2)
                                Text(appt.employeeName).font(.caption.bold())
                            }
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color(.tertiarySystemBackground))
                            .foregroundColor(.secondary)
                            .clipShape(Capsule())
                        }
                        
                        Text(appt.price.formatted(.currency(code: "USD")))
                            .font(.caption.bold())
                            .foregroundColor(accent)
                    }
                }
                .padding(.vertical, 14)
            }
            .padding(.horizontal, 14)
            
            // ── Action bar (hidden once cancelled or completed) ──────
            if appt.status != .cancelled && appt.status != .completed {
                Rectangle()
                    .fill(accent.opacity(0.15))
                    .frame(height: 1)
                    .padding(.horizontal, 0)
                
                HStack(spacing: 0) {
                    // ✅ Confirm
                    if appt.status == .pending {
                        cardAction(label: "Confirm", icon: "checkmark.circle.fill", color: .teal) {
                            showConfirmAlert = true
                        }
                        actionDivider
                    }
                    
                    // ❌ Reject (always shown when not complete/cancelled)
                    cardAction(label: "Reject", icon: "xmark.circle.fill", color: .red) {
                        showRejectAlert = true
                    }
                    actionDivider
                    
                    // 💬 Message
                    cardAction(label: "Message", icon: "bubble.left.fill", color: .blue) {
                        showChat = true
                    }
                    actionDivider
                    
                    // 📅 Reschedule
                    cardAction(label: "Reschedule", icon: "calendar.badge.clock", color: .orange) {
                        showReschedule = true
                    }
                    actionDivider
                    
                    // ✔ Complete
                    cardAction(label: "Complete", icon: "checkmark.seal.fill", color: .green) {
                        showCompleteAlert = true
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(bg)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.2), lineWidth: 1))
        )
        .animation(.easeInOut(duration: 0.3), value: appt.status)
        
        // MARK: Sheets
        .sheet(isPresented: $showReschedule) {
            RescheduleSheetView(appointment: appt)
        }
        .sheet(isPresented: $showChat) {
            NavigationStack {
                EmployeeChatView(employeeName: actorName, clientName: appt.customerName)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) { Button("Done") { showChat = false } }
                    }
            }
        }
        
        // MARK: Confirmation Alerts
        .alert("Confirm Appointment?", isPresented: $showConfirmAlert) {
            Button("Confirm") {
                withAnimation { appt.status = .confirmed }
                try? modelContext.save()
                SoundFeedbackManager.shared.playAddTaskSound()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Mark \(appt.customerName)'s session as confirmed?")
        }

        .alert("Reject Appointment?", isPresented: $showRejectAlert) {
            Button("Reject", role: .destructive) {
                withAnimation { appt.status = .cancelled }
                try? modelContext.save()
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("This will cancel \(appt.customerName)'s session. This action cannot be undone.")
        }

        .alert("Mark as Complete?", isPresented: $showCompleteAlert) {
            Button("Mark Complete") {
                withAnimation { appt.status = .completed }
                try? modelContext.save()
                SoundFeedbackManager.shared.playCompleteTaskSound()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Mark \(appt.customerName)'s session as completed?")
        }
    }
    
    private var statusBadge: some View {
        Text(appt.status.rawValue.uppercased())
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(accent.opacity(0.14))
            .foregroundColor(accent)
            .clipShape(Capsule())
    }
    
    private var actionDivider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(width: 0.5, height: 30)
    }
    
    private func cardAction(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ADD APPOINTMENT SHEET

struct EmployeeAddAppointmentSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    let fixedEmployeeName: String
    let businessCode: String
    let existingAppointments: [Appointment]
    
    @Query(sort: \Service.name) private var allServices: [Service]
    @State private var customerName = ""
    @State private var selectedService: Service?
    @State private var date = Date()
    @State private var durationIndex = 1
    let durations = [30, 60, 90, 120]
    
    private var businessServices: [Service] {
        businessCode.isEmpty ? allServices : allServices.filter { $0.businessCode == businessCode }
    }
    private var hasConflict: Bool {
        let end = date.addingTimeInterval(TimeInterval(durations[durationIndex] * 60))
        return existingAppointments.contains { date < $0.endTime && end > $0.startTime }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Client Details") { TextField("Customer Name", text: $customerName) }
                Section("Service Selection") {
                    if businessServices.isEmpty {
                        Label("No services added by your studio owner yet.", systemImage: "exclamationmark.circle")
                            .foregroundColor(.orange).font(.caption)
                    } else {
                        Picker("Service Type", selection: $selectedService) {
                            Text("Select Service").tag(nil as Service?)
                            ForEach(businessServices) { s in
                                Text("\(s.name) – \(s.price.formatted(.currency(code: "USD")))").tag(s as Service?)
                            }
                        }
                    }
                    Picker("Duration", selection: $durationIndex) {
                        ForEach(0..<durations.count, id: \.self) { i in Text("\(durations[i]) min").tag(i) }
                    }.pickerStyle(.segmented)
                }
                Section("Schedule") {
                    DatePicker("Start Time", selection: $date)
                    if hasConflict {
                        Label("Time Conflict Detected", systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange).font(.caption)
                    }
                }
                if let s = selectedService {
                    Section("Summary") {
                        HStack { Text("Service"); Spacer(); Text(s.name).foregroundColor(.secondary) }
                        HStack { Text("Price"); Spacer(); Text(s.price.formatted(.currency(code: "USD"))).foregroundColor(.teal) }
                        HStack { Text("Duration"); Spacer(); Text("\(durations[durationIndex]) min").foregroundColor(.secondary) }
                    }
                }
            }
            .navigationTitle("New Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let s = selectedService else { return }
                        let end = date.addingTimeInterval(TimeInterval(durations[durationIndex] * 60))
                        let a = Appointment(customerName: customerName, employeeName: fixedEmployeeName,
                                            startTime: date, endTime: end, price: s.price, status: .confirmed, businessCode: businessCode)
                        a.service = s; modelContext.insert(a); try? modelContext.save()
                        SoundFeedbackManager.shared.playAddTaskSound()
                        dismiss()
                    }
                    .bold().disabled(customerName.isEmpty || selectedService == nil || hasConflict)
                }
            }
        }
    }
}

// MARK: - APPOINTMENT BLOCK (calendar grid — status-aware colours)

struct DashboardAppointmentBlock: View {
    let appt: Appointment
    var isMini: Bool = false
    var dayLoad: DayLoad = .calm

    private var color: Color {
        switch appt.status {
        case .confirmed: return dayLoad.color
        case .completed: return .green
        case .cancelled: return .gray
        case .pending:   return .orange
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: isMini ? 6 : 10)
                .fill(color.opacity(appt.status == .cancelled ? 0.07 : 0.18))
                .overlay(RoundedRectangle(cornerRadius: isMini ? 6 : 10).stroke(color, lineWidth: 1.5))
            if isMini {
                Text(appt.customerName).font(.system(size: 9, weight: .semibold)).foregroundColor(color)
                    .padding(3).lineLimit(1).strikethrough(appt.status == .cancelled)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(appt.customerName).font(.system(size: 13, weight: .bold)).foregroundColor(color)
                        .lineLimit(1).strikethrough(appt.status == .cancelled)
                    Text(appt.service?.name ?? "Appointment").font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                }.padding(8)
            }
        }
        .animation(dayLoad.insertionAnimation, value: appt.status)
    }
}

// MARK: - EMPLOYEE INBOX VIEW

struct EmployeeInboxView: View {
    let employeeName: String
    let allClientNames: [String]
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \EmployeeClientMessage.timestamp) private var allMessages: [EmployeeClientMessage]
    @State private var openClientName: String? = nil
    
    private var contactNames: [String] {
        let fromMsgs = allMessages.filter { $0.employeeName == employeeName }.map { $0.clientName }
        return Array(Set(fromMsgs + allClientNames)).sorted()
    }
    private func latest(for name: String) -> EmployeeClientMessage? {
        allMessages.filter { $0.employeeName == employeeName && $0.clientName == name }.last
    }
    private func unread(for name: String) -> Int {
        allMessages.filter { $0.employeeName == employeeName && $0.clientName == name && !$0.isFromEmployee }.count
    }
    
    var body: some View {
        NavigationStack {
            List {
                if contactNames.isEmpty {
                    ContentUnavailableView("No Clients Yet", systemImage: "bubble.left.and.bubble.right",
                                           description: Text("Your clients will appear here once appointments are booked."))
                } else {
                    ForEach(contactNames, id: \.self) { name in
                        Button { openClientName = name } label: {
                            ClientThreadRow(clientName: name, latestMessage: latest(for: name), unreadCount: unread(for: name))
                        }.buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Messages").navigationBarTitleDisplayMode(.large)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .navigationDestination(item: $openClientName) { name in
                EmployeeChatView(employeeName: employeeName, clientName: name)
            }
        }
    }
}

// MARK: - CLIENT THREAD ROW

struct ClientThreadRow: View {
    let clientName: String
    let latestMessage: EmployeeClientMessage?
    let unreadCount: Int
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.teal.opacity(0.15)).frame(width: 48, height: 48)
                Text(clientName.prefix(1).uppercased()).font(.headline.bold()).foregroundColor(.teal)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(clientName).font(.headline)
                    Spacer()
                    if let m = latestMessage { Text(m.timestamp, style: .relative).font(.caption).foregroundColor(.secondary) }
                }
                HStack {
                    if let m = latestMessage {
                        Text((m.isFromEmployee ? "You: " : "") + m.content).font(.subheadline).foregroundColor(.secondary).lineLimit(1)
                    } else {
                        Text("Tap to start a conversation").font(.subheadline).foregroundColor(.secondary).italic()
                    }
                    Spacer()
                    if unreadCount > 0 {
                        Text("\(unreadCount)").font(.caption2.bold()).foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2).background(Color.teal).clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - EMPLOYEE CHAT VIEW

struct EmployeeChatView: View {
    let employeeName: String
    let clientName: String
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EmployeeClientMessage.timestamp) private var allMessages: [EmployeeClientMessage]
    @State private var newMessage = ""
    
    private var thread: [EmployeeClientMessage] {
        allMessages.filter { $0.employeeName == employeeName && $0.clientName == clientName }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if thread.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 40)).foregroundColor(.teal.opacity(0.4))
                                Text("Start the conversation with \(clientName)").font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                            }.padding(.top, 60)
                        } else {
                            ForEach(thread) { msg in chatBubble(msg).id(msg.id) }
                        }
                    }.padding()
                }
                .onAppear { if let l = thread.last { proxy.scrollTo(l.id, anchor: .bottom) } }
                .onChange(of: thread.count) { _, _ in
                    if let l = thread.last { withAnimation { proxy.scrollTo(l.id, anchor: .bottom) } }
                }
            }
            Divider()
            HStack(spacing: 12) {
                TextField("Message \(clientName)...", text: $newMessage, axis: .vertical)
                    .lineLimit(1...4).padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground)).cornerRadius(22)
                Button {
                    let t = newMessage.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { return }
                    modelContext.insert(EmployeeClientMessage(content: t, isFromEmployee: true, employeeName: employeeName, clientName: clientName))
                    try? modelContext.save(); newMessage = ""
                } label: {
                    Image(systemName: "paperplane.fill").font(.title3)
                        .foregroundColor(newMessage.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .teal)
                }
                .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16).padding(.vertical, 10).background(Color(.systemBackground))
        }
        .navigationTitle(clientName).navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
    
    private func chatBubble(_ msg: EmployeeClientMessage) -> some View {
        HStack {
            if msg.isFromEmployee { Spacer(minLength: 50) }
            VStack(alignment: msg.isFromEmployee ? .trailing : .leading, spacing: 4) {
                Text(msg.content)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(msg.isFromEmployee ? Color.teal : Color(.systemBackground))
                    .foregroundColor(msg.isFromEmployee ? .white : .primary).cornerRadius(18)
                Text(msg.timestamp, style: .time).font(.caption2).foregroundColor(.secondary).padding(.horizontal, 4)
            }
            if !msg.isFromEmployee { Spacer(minLength: 50) }
        }
    }
}
