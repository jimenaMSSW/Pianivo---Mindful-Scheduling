import SwiftUI
import SwiftData

// Returns first letter of word 1 + first letter of word 2 (falls back to first 2 chars)
private func bizInitials(_ name: String) -> String {
    let words = name.split(separator: " ").map { String($0) }
    if words.count >= 2,
       let a = words[0].first, let b = words[1].first {
        return "\(a)\(b)".uppercased()
    }
    return String(name.prefix(2)).uppercased()
}

// MARK: - CLIENT ROOT VIEW
// Single NavigationStack with a side panel for all navigation.
// No bottom tab bar — everything lives in the hamburger panel.

struct ClientTabView: View {
    let clientName: String
    var onLogout: (() -> Void)? = nil
    
    @State private var activeView: ClientSection = .home
    @State private var isShowingSidePanel = false
    
    enum ClientSection { case home, discover, schedule, insights }
    
    var body: some View {
        ZStack {
            // ── Active content ───────────────────────────────────────
            NavigationStack {
                Group {
                    switch activeView {
                    case .home:      ClientDashboardView(clientName: clientName)
                    case .discover:  ClientDiscoverView(clientName: clientName)
                    case .schedule:  ClientScheduleView(clientName: clientName)
                    case .insights:  ClientInsightsView(clientName: clientName)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isShowingSidePanel.toggle()
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                                .fontWeight(.bold)
                                .foregroundColor(.teal)
                        }
                    }
                }
            }
            
            // ── Sidebar overlay ──────────────────────────────────────
            if isShowingSidePanel {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.spring()) { isShowingSidePanel = false } }
                    .zIndex(1)
                
                HStack(spacing: 0) {
                    clientSidePanel
                        .frame(width: 270)
                        .transition(.move(edge: .leading))
                    Spacer()
                }
                .zIndex(2)
            }
        }
    }
    
    // MARK: - Side Panel
    private var clientSidePanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // ── Profile header ────────────────────────────────────────
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.teal, Color(hex: "#26A69A") ?? .teal],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 52, height: 52)
                    Text(clientName.prefix(1).uppercased())
                        .font(.title2.bold()).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(clientName).font(.headline)
                    Text("Client Account").font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.top, 60)
            
            Divider()
            
            // ── Navigation ────────────────────────────────────────────
            VStack(spacing: 4) {
                Text("NAVIGATE").font(.caption.bold()).foregroundColor(.secondary).tracking(1.2)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 5)
                    .padding(.bottom, 4)
                
                panelNavItem(label: "Home",      icon: "house.fill",       section: .home)
                panelNavItem(label: "Discover",  icon: "magnifyingglass",  section: .discover)
                panelNavItem(label: "Schedule",  icon: "calendar",         section: .schedule)
                panelNavItem(label: "Insights",  icon: "chart.bar.fill",   section: .insights)
            }
            
            Divider()
            
            // ── Account ───────────────────────────────────────────────
            VStack(spacing: 4) {
                Text("ACCOUNT").font(.caption.bold()).foregroundColor(.secondary).tracking(1.2)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 5)
                    .padding(.bottom, 4)
                
                // Book new appointment quick-action
                Button {
                    withAnimation(.spring()) { activeView = .discover; isShowingSidePanel = false }
                } label: {
                    HStack(spacing: 15) {
                        Image(systemName: "plus.circle.fill").foregroundColor(.teal).frame(width: 24)
                        Text("Book Appointment").font(.subheadline.bold()).foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 12).padding(.horizontal, 10)
                    .background(Color.teal.opacity(0.08))
                    .cornerRadius(10)
                }
            }
            
            Spacer()
            
            // ── Sign Out ──────────────────────────────────────────────
            Button(role: .destructive) {
                withAnimation(.spring()) { isShowingSidePanel = false }
                onLogout?()
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                }
                .font(.subheadline.bold())
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.bottom, 30)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .vertical)
    }
    
    private func panelNavItem(label: String, icon: String, section: ClientSection) -> some View {
        let isActive = activeView == section
        return Button {
            withAnimation(.spring()) { activeView = section; isShowingSidePanel = false }
        } label: {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .foregroundColor(isActive ? .teal : .secondary)
                    .frame(width: 24)
                Text(label)
                    .font(.subheadline.bold())
                    .foregroundColor(isActive ? .primary : .secondary)
                Spacer()
                if isActive { Circle().fill(Color.teal).frame(width: 6, height: 6) }
            }
            .padding(.vertical, 12).padding(.horizontal, 10)
            .background(isActive ? Color.teal.opacity(0.1) : Color.clear)
            .cornerRadius(10)
        }
    }
}

// MARK: - HOME DASHBOARD

struct ClientDashboardView: View {
    let clientName: String
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Appointment.startTime, order: .forward) private var allAppointments: [Appointment]
    @Query private var allBusinesses: [BusinessProfile]
    
    @State private var rescheduleAppt: Appointment? = nil
    @State private var showCancelConfirm = false
    @State private var cancelAppt: Appointment? = nil
    
    var myAppointments: [Appointment]  { allAppointments.filter { $0.customerName == clientName } }
    var nextAppointment: Appointment?  { myAppointments.first(where: { $0.startTime > Date() }) }
    var upcomingAll: [Appointment]     { myAppointments.filter { $0.startTime > Date() } }
    var pastCount: Int                 { myAppointments.filter { $0.startTime <= Date() }.count }
    var totalSpent: Double             { myAppointments.filter { $0.status == .completed || $0.status == .confirmed }.reduce(0) { $0 + $1.price } }

    // ── Day Load ────────────────────────────────────────────────────────
    var todayLoad: DayLoad {
        calculateDayLoad(from: myAppointments.filter { Calendar.current.isDateInToday($0.startTime) })
    }
    var todaySuggestions: [BalanceSuggestion] {
        BalanceSuggestionEngine.suggestions(for: myAppointments, on: Date())
    }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    
                    // ── Welcome card ─────────────────────────────────
                    welcomeCard
                    
                    // ── Summary stats ────────────────────────────────
                    HStack(spacing: 12) {
                        SummaryBox(title: "Upcoming",  value: "\(upcomingAll.count)",
                                   icon: "calendar.badge.clock", color: .teal)
                        SummaryBox(title: "Completed", value: "\(pastCount)",
                                   icon: "checkmark.seal.fill",  color: .green)
                        SummaryBox(title: "Spent",     value: totalSpent.formatted(.currency(code: "USD")),
                                   icon: "dollarsign.circle.fill", color: .indigo)
                    }
                    .padding(.horizontal)
                    
                    // ── Next appointment ─────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("NEXT APPOINTMENT", icon: "calendar")
                        if let appt = nextAppointment {
                            nextAppointmentCard(appt)
                        } else {
                            emptyAppointmentCard
                        }
                    }
                    .padding(.horizontal)
                    
                    // ── Explore businesses ───────────────────────────
                    if !allBusinesses.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                sectionHeader("BUSINESSES", icon: "building.2.fill")
                                Spacer()
                                NavigationLink(destination: ClientDiscoverView(clientName: clientName)) {
                                    Text("See All").font(.caption.bold()).foregroundColor(.teal)
                                }
                            }
                            .padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(allBusinesses.prefix(8)) { biz in
                                        NavigationLink(destination: BusinessDetailView(business: biz, clientName: clientName)) {
                                            ClientBusinessChip(business: biz)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // ── Other upcoming ───────────────────────────────
                    if upcomingAll.count > 1 {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionHeader("ALL UPCOMING", icon: "list.bullet.clipboard")
                                .padding(.horizontal)
                            ForEach(upcomingAll.dropFirst()) { appt in
                                AppointmentCard(appt: appt, showEmployee: true)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.top, 16).padding(.bottom, 30)
            }
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $rescheduleAppt) { appt in
            RescheduleSheetView(appointment: appt)
        }
        .confirmationDialog("Cancel Appointment", isPresented: $showCancelConfirm, titleVisibility: .visible) {
            Button("Cancel Appointment", role: .destructive) {
                if let appt = cancelAppt {
                    appt.status = .cancelled
                    try? modelContext.save()
                }
            }
            Button("Keep It", role: .cancel) {}
        } message: {
            Text("Are you sure you want to cancel this appointment? This cannot be undone.")
        }
    }
    
    // MARK: Welcome Card
    private var welcomeCard: some View {
        let load = todayLoad
        let spacing = DayLoadSpacing.forLoad(load)
        return VStack(alignment: .leading, spacing: spacing.itemSpacing) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("PIANIVO")
                            .font(.caption2.bold()).tracking(1)
                            .foregroundColor(load.color)
                        DayLoadBadge(load: load)
                    }
                    Text("Welcome back,").font(.subheadline).foregroundColor(.secondary)
                    Text(clientName).font(.title2.bold())
                }
                Spacer()
                RhythmOrb(load: load)
            }
            Divider()
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundColor(load.color).font(.caption)
                Text(timeOfDayGreeting).font(.caption).foregroundColor(.secondary)
            }
            // Suggestions only shown when there's something meaningful to say
            if !todaySuggestions.isEmpty {
                Divider()
                BalanceSuggestionsPanel(suggestions: todaySuggestions)
                    .padding(.horizontal, -4)  // Align with card edge
            }
        }
        .padding(spacing.cardPadding)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
        .padding(.horizontal)
        .animation(load.insertionAnimation, value: load)
    }
    
    private var timeOfDayGreeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 0..<12: return "Good morning — ready to book your next appointment?"
        case 12..<17: return "Good afternoon — your schedule is looking good."
        default:     return "Good evening — here's a look at your upcoming bookings."
        }
    }
    
    // MARK: Next Appointment Card
    private func nextAppointmentCard(_ appt: Appointment) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                HStack(alignment: .top) {
                    detailCol(label: "Service",  value: appt.service?.name ?? "Appointment")
                    Spacer()
                    detailCol(label: "Provider", value: appt.employeeName)
                }
                Divider()
                HStack(alignment: .top) {
                    detailCol(label: "Date & Time",
                              value: appt.startTime.formatted(date: .abbreviated, time: .shortened))
                    Spacer()
                    let mins = max(0, Int(appt.endTime.timeIntervalSince(appt.startTime) / 60))
                    detailCol(label: "Duration & Price",
                              value: "\(mins) min  •  \(appt.price.formatted(.currency(code: "USD")))")
                }
                HStack(spacing: 8) {
                    statusChip(appt.statusRaw)
                    if appt.isHighStress {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.shield.fill").font(.caption2)
                            Text("Busy Period").font(.caption.bold())
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1)).clipShape(Capsule())
                    }
                    Spacer()
                    Capsule().fill(appt.service?.themeColor ?? .teal).frame(width: 28, height: 6)
                }
            }
            .padding(18)
            Divider()
            HStack(spacing: 10) {
                Button(action: { rescheduleAppt = appt }) {
                    Label("Reschedule", systemImage: "arrow.clockwise")
                        .font(.subheadline.bold()).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Color.teal).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Button(action: {
                    cancelAppt = appt
                    showCancelConfirm = true
                }) {
                    Label("Cancel", systemImage: "xmark")
                        .font(.subheadline.bold()).foregroundColor(.red)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Color.red.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.teal.opacity(0.12), lineWidth: 1))
    }
    
    private var emptyAppointmentCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 38)).foregroundColor(.teal.opacity(0.4))
            Text("No upcoming appointments.")
                .font(.headline)
            Text("Use Discover to find a business and book your next appointment.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
            NavigationLink(destination: ClientDiscoverView(clientName: clientName)) {
                Text("Browse Businesses")
                    .font(.subheadline.bold()).foregroundColor(.white)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Color.teal).clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity).padding(30)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
    
    // MARK: Helpers
    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.bold()).foregroundColor(.secondary).tracking(1)
    }
    private func detailCol(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value).font(.subheadline.bold()).lineLimit(2)
        }
    }
    private func statusChip(_ raw: String) -> some View {
        let status = AppointmentStatus(rawValue: raw) ?? .pending
        let color: Color = status == .confirmed ? .teal : status == .completed ? .green : status == .cancelled ? .gray : .orange
        return Text(raw).font(.caption.bold()).foregroundColor(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.1)).clipShape(Capsule())
    }
}

// MARK: - BUSINESS CHIP (horizontal scroll)

struct ClientBusinessChip: View {
    let business: BusinessProfile
    private let palette: [Color] = [.teal, .indigo, .blue, .purple, .orange, .cyan, .mint]
    private var chipColor: Color { palette[abs(business.studioName.hashValue) % palette.count] }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(chipColor.opacity(0.15))
                    .frame(width: 64, height: 64)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(chipColor.opacity(0.3), lineWidth: 1))
                Text(bizInitials(business.studioName))
                    .font(.headline.bold()).foregroundColor(chipColor)
            }
            Text(business.studioName)
                .font(.caption.bold()).multilineTextAlignment(.center)
                .lineLimit(2).frame(width: 72).foregroundColor(.primary)
            if !business.city.isEmpty {
                Text(business.city).font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }
}

// MARK: - DISCOVER VIEW

struct ClientDiscoverView: View {
    let clientName: String
    @Query private var allBusinesses: [BusinessProfile]
    @Query(sort: \Service.name) private var allServices: [Service]
    @Query private var allReviews: [Review]
    
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    
    private let categories = ["All", "Wellness", "Music", "Beauty", "Fitness", "Other"]
    private let palette: [Color] = [.teal, .indigo, .blue, .purple, .orange, .cyan, .mint]
    private func chipColor(for name: String) -> Color { palette[abs(name.hashValue) % palette.count] }
    
    var filteredBusinesses: [BusinessProfile] {
        allBusinesses.filter { biz in
            (selectedCategory == "All" || biz.businessCategory == selectedCategory) &&
            (searchText.isEmpty ||
             biz.studioName.localizedCaseInsensitiveContains(searchText) ||
             biz.city.localizedCaseInsensitiveContains(searchText) ||
             biz.businessCategory.localizedCaseInsensitiveContains(searchText))
        }
    }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Search businesses, cities, categories...", text: $searchText)
                        .textFieldStyle(.plain).autocorrectionDisabled()
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal).padding(.vertical, 10)
                
                // Category chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { cat in
                            Button { withAnimation { selectedCategory = cat } } label: {
                                Text(cat)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(selectedCategory == cat ? .white : .teal)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(selectedCategory == cat ? Color.teal : Color.teal.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal).padding(.bottom, 10)
                }
                
                ScrollView {
                    if filteredBusinesses.isEmpty {
                        ContentUnavailableView(
                            "No Businesses Found",
                            systemImage: "building.2.crop.circle",
                            description: Text("Try adjusting your search or category.")
                        )
                        .padding(.top, 60)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(filteredBusinesses) { biz in
                                let bizReviews = allReviews.filter { $0.businessCode == biz.businessCode }
                                NavigationLink(destination: BusinessDetailView(business: biz, clientName: clientName)) {
                                    ClientBusinessCard(
                                        business: biz,
                                        serviceCount: allServices.filter { $0.businessCode == biz.businessCode }.count,
                                        accentColor: chipColor(for: biz.studioName),
                                        reviews: bizReviews
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal).padding(.bottom, 30)
                    }
                }
            }
        }
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - BUSINESS CARD (grid)

struct ClientBusinessCard: View {
    let business: BusinessProfile
    let serviceCount: Int
    let accentColor: Color
    let reviews: [Review]
    
    private var avgRating: Double {
        reviews.isEmpty ? 0 : Double(reviews.map(\.stars).reduce(0, +)) / Double(reviews.count)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(accentColor.opacity(0.12)).frame(height: 76)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(0.2), lineWidth: 1))
                VStack(spacing: 3) {
                    Text(bizInitials(business.studioName))
                        .font(.title2.bold()).foregroundColor(accentColor)
                    if !business.businessCategory.isEmpty {
                        Text(business.businessCategory)
                            .font(.caption2.bold()).foregroundColor(accentColor.opacity(0.8))
                    }
                }
            }
            Text(business.studioName).font(.subheadline.bold()).lineLimit(1).foregroundColor(.primary)
            if !business.city.isEmpty {
                Label(business.city, systemImage: "location.fill")
                    .font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            if serviceCount > 0 {
                Text("\(serviceCount) service\(serviceCount == 1 ? "" : "s")")
                    .font(.caption.bold()).foregroundColor(accentColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(accentColor.opacity(0.1)).clipShape(Capsule())
            }
            // Real rating
            if reviews.isEmpty {
                Text("No reviews yet").font(.caption2).foregroundColor(.secondary)
            } else {
                HStack(spacing: 3) {
                    StarRatingView(rating: avgRating, size: 9)
                    Text(String(format: "%.1f", avgRating))
                        .font(.caption2.bold()).foregroundColor(.primary)
                    Text("(\(reviews.count))")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }
}

// MARK: - BUSINESS DETAIL VIEW

struct BusinessDetailView: View {
    let business: BusinessProfile
    let clientName: String
    
    @Query(sort: \Service.name) private var allServices: [Service]
    @Query(sort: \Employee.name) private var allEmployees: [Employee]
    @Query(sort: \Review.createdAt, order: .reverse) private var allReviews: [Review]
    
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var bookingService: Service? = nil
    @State private var isShowingReviewSheet = false
    
    private var services: [Service]   { allServices.filter  { $0.businessCode == business.businessCode } }
    private var employees: [Employee] { allEmployees.filter { $0.businessCode == business.businessCode } }
    private var reviews: [Review]     { allReviews.filter   { $0.businessCode == business.businessCode } }
    private var avgRating: Double {
        reviews.isEmpty ? 0 : Double(reviews.map(\.stars).reduce(0, +)) / Double(reviews.count)
    }
    private var categories: [String] {
        ["All"] + Set(services.map { $0.category }).filter { !$0.isEmpty }.sorted()
    }
    private var filteredServices: [Service] {
        services.filter {
            (selectedCategory == "All" || $0.category == selectedCategory) &&
            (searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText))
        }
    }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    businessInfoCard.padding(.horizontal)
                    hoursAboutCard.padding(.horizontal)
                    
                    // ── Services ──────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Label("SERVICES", systemImage: "tag.fill")
                            .font(.caption.bold()).foregroundColor(.secondary).tracking(1)
                            .padding(.horizontal)
                        
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                            TextField("Search services...", text: $searchText)
                                .textFieldStyle(.plain).autocorrectionDisabled()
                        }
                        .padding(10).background(Color(.secondarySystemBackground))
                        .cornerRadius(12).padding(.horizontal)
                        
                        if categories.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(categories, id: \.self) { cat in
                                        Button { withAnimation { selectedCategory = cat } } label: {
                                            Text(cat)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(selectedCategory == cat ? .white : .teal)
                                                .padding(.horizontal, 16).padding(.vertical, 8)
                                                .background(selectedCategory == cat ? Color.teal : Color.teal.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        if filteredServices.isEmpty {
                            ContentUnavailableView("No Services", systemImage: "tag").padding(.top, 20)
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                                ForEach(filteredServices) { svc in
                                    ClientServiceCard(service: svc) { bookingService = svc }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // ── Reviews ───────────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("REVIEWS", systemImage: "star.fill")
                                .font(.caption.bold()).foregroundColor(.secondary).tracking(1)
                            Spacer()
                            Button { isShowingReviewSheet = true } label: {
                                Label("Write a Review", systemImage: "square.and.pencil")
                                    .font(.caption.bold()).foregroundColor(.teal)
                            }
                        }
                        .padding(.horizontal)
                        
                        if reviews.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "star").font(.system(size: 32)).foregroundColor(.teal.opacity(0.3))
                                Text("No reviews yet").font(.subheadline.bold())
                                Text("Be the first to leave a review for \(business.studioName).")
                                    .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                                Button { isShowingReviewSheet = true } label: {
                                    Text("Leave a Review")
                                        .font(.subheadline.bold()).foregroundColor(.white)
                                        .padding(.horizontal, 20).padding(.vertical, 10)
                                        .background(Color.teal).clipShape(Capsule())
                                }
                            }
                            .frame(maxWidth: .infinity).padding(24)
                            .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
                            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                            .padding(.horizontal)
                        } else {
                            // Rating summary
                            HStack(spacing: 14) {
                                VStack(spacing: 4) {
                                    Text(String(format: "%.1f", avgRating))
                                        .font(.system(size: 40, weight: .bold))
                                    StarRatingView(rating: avgRating, size: 14)
                                    Text("\(reviews.count) review\(reviews.count == 1 ? "" : "s")")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                .frame(width: 90)
                                Divider()
                                VStack(spacing: 5) {
                                    ForEach([5,4,3,2,1], id: \.self) { star in
                                        let count = reviews.filter { $0.stars == star }.count
                                        let fraction = reviews.isEmpty ? 0.0 : Double(count) / Double(reviews.count)
                                        HStack(spacing: 6) {
                                            Text("\(star)").font(.caption2).foregroundColor(.secondary).frame(width: 10)
                                            Image(systemName: "star.fill").font(.system(size: 8)).foregroundColor(.yellow)
                                            GeometryReader { geo in
                                                ZStack(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 3).fill(Color(.systemGray5)).frame(height: 6)
                                                    RoundedRectangle(cornerRadius: 3).fill(Color.teal)
                                                        .frame(width: max(0, geo.size.width * CGFloat(fraction)), height: 6)
                                                }
                                            }
                                            .frame(height: 6)
                                            Text("\(count)").font(.caption2).foregroundColor(.secondary).frame(width: 18, alignment: .trailing)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
                            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                            .padding(.horizontal)
                            
                            ForEach(reviews) { review in
                                ReviewCard(review: review).padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 30)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle(business.studioName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $bookingService) { svc in
            HostedBookingView(
                title: "Book \(svc.name)",
                url: APIConfig.bookingURL(serviceName: svc.name, price: svc.price)
            )
        }
        .sheet(isPresented: $isShowingReviewSheet) {
            LeaveReviewSheet(businessCode: business.businessCode, reviewerName: clientName)
        }
    }
    
    private var businessInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Color.teal.opacity(0.12)).frame(width: 56, height: 56)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.teal.opacity(0.2), lineWidth: 1))
                    Text(bizInitials(business.studioName)).font(.headline.bold()).foregroundColor(.teal)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(business.studioName).font(.headline)
                    if !business.businessCategory.isEmpty {
                        Text(business.businessCategory).font(.caption).foregroundColor(.teal)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.teal.opacity(0.1)).clipShape(Capsule())
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if reviews.isEmpty {
                        Text("No reviews yet").font(.caption2).foregroundColor(.secondary)
                    } else {
                        StarRatingView(rating: avgRating, size: 11)
                        Text("\(String(format: "%.1f", avgRating)) · \(reviews.count) review\(reviews.count == 1 ? "" : "s")")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                if !business.address.isEmpty {
                    Label("\(business.address)\(business.city.isEmpty ? "" : ", \(business.city)")", systemImage: "location.fill")
                        .font(.caption).foregroundColor(.secondary)
                }
                if !business.phone.isEmpty {
                    Label(business.phone, systemImage: "phone.fill").font(.caption).foregroundColor(.teal)
                }
                if !business.email.isEmpty {
                    Label(business.email, systemImage: "envelope.fill").font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
    
    private var hoursAboutCard: some View {
        let today = Calendar.current.component(.weekday, from: Date())
        let todayHours: String = {
            switch today {
            case 1: return business.sundayHours;    case 2: return business.mondayHours
            case 3: return business.tuesdayHours;   case 4: return business.wednesdayHours
            case 5: return business.thursdayHours;  case 6: return business.fridayHours
            case 7: return business.saturdayHours;  default: return "—"
            }
        }()
        let isOpen = !todayHours.lowercased().contains("closed")
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: isOpen ? "clock.fill" : "clock.badge.xmark")
                    .foregroundColor(isOpen ? .teal : .red).font(.subheadline)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isOpen ? "Open Today" : "Closed Today")
                        .font(.subheadline.bold()).foregroundColor(isOpen ? .teal : .red)
                    Text(todayHours).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if !employees.isEmpty {
                    Label("\(employees.count) staff", systemImage: "person.2.fill")
                        .font(.caption.bold()).foregroundColor(.teal)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.teal.opacity(0.1)).clipShape(Capsule())
                }
            }
            if !business.about.isEmpty {
                Divider()
                Text(business.about).font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - SERVICE CARD

struct ClientServiceCard: View {
    let service: Service
    let onBook: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Capsule().fill(service.themeColor).frame(width: 3, height: 14)
                if !service.category.isEmpty {
                    Text(service.category).font(.caption.bold()).foregroundColor(service.themeColor)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(service.themeColor.opacity(0.1)).clipShape(Capsule())
                }
            }
            Text(service.name).font(.headline).lineLimit(2)
            if !service.serviceDescription.isEmpty {
                Text(service.serviceDescription).font(.caption).foregroundColor(.secondary).lineLimit(2)
            }
            Label("\(service.durationMinutes) min", systemImage: "clock")
                .font(.caption).foregroundColor(.secondary)
            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle.fill").foregroundColor(.teal).font(.subheadline)
                Text(service.price.formatted(.currency(code: "USD"))).font(.subheadline.bold())
            }
            Button(action: onBook) {
                Text("Book Now").font(.subheadline.bold()).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Color.teal).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground))
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(service.themeColor.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - BOOKING SHEET

struct ClientBookingSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let clientName: String
    let business: BusinessProfile
    let service: Service
    let employees: [Employee]
    
    // Contact info fields
    @State private var contactName: String = ""
    @State private var contactPhone: String = ""
    @State private var contactEmail: String = ""
    
    @State private var selectedEmployee: Employee? = nil
    @State private var appointmentDate: Date = {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day, .hour], from: Date())
        comps.hour = (comps.hour ?? 0) + 1; comps.minute = 0
        return cal.date(from: comps) ?? Date()
    }()
    @State private var isSaved = false
    @State private var showConfirmation = false
    @State private var showValidationError = false
    
    // Pre-fill name from logged-in clientName
    private var isFormValid: Bool {
        !contactName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !contactPhone.trimmingCharacters(in: .whitespaces).isEmpty &&
        contactEmail.contains("@")
    }
    
    var body: some View {
        NavigationStack {
            if showConfirmation {
                confirmationView
            } else {
                Form {
                    // ── Business & service banner ─────────────────────
                    Section {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.teal.opacity(0.12)).frame(width: 48, height: 48)
                                Text(bizInitials(business.studioName))
                                    .font(.caption.bold()).foregroundColor(.teal)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(business.studioName).font(.headline)
                                HStack(spacing: 6) {
                                    Capsule().fill(service.themeColor).frame(width: 8, height: 8)
                                    Text(service.name).font(.subheadline).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(service.price.formatted(.currency(code: "USD")))
                                .font(.subheadline.bold()).foregroundColor(.teal)
                        }
                        .padding(.vertical, 4)
                    } header: { Text("Booking For") }
                    
                    // ── Contact information ───────────────────────────
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "person.fill")
                                .foregroundColor(.teal).frame(width: 20)
                            TextField("Full Name", text: $contactName)
                                .autocorrectionDisabled()
                                .textContentType(.name)
                        }
                        HStack(spacing: 12) {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.teal).frame(width: 20)
                            TextField("Phone Number", text: $contactPhone)
                                .keyboardType(.phonePad)
                                .textContentType(.telephoneNumber)
                        }
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.teal).frame(width: 20)
                            TextField("Email Address", text: $contactEmail)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .textContentType(.emailAddress)
                        }
                        
                        if showValidationError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                                Text("Please fill in all fields with a valid email.")
                                    .font(.caption).foregroundColor(.red)
                            }
                            .padding(.vertical, 4)
                        }
                    } header: { Text("Your Contact Details") }
                    footer: { Text("Your details are shared with \(business.studioName) to confirm your booking.") }
                    
                    // ── Staff picker ──────────────────────────────────
                    Section(header: Text("Choose Staff")) {
                        if employees.isEmpty {
                            Text("No staff listed yet — someone will be assigned.")
                                .foregroundColor(.secondary).font(.subheadline)
                        } else {
                            Picker("Provider", selection: $selectedEmployee) {
                                Text("Any available").tag(nil as Employee?)
                                ForEach(employees) { emp in
                                    Label(emp.name, systemImage: "person.circle.fill").tag(emp as Employee?)
                                }
                            }
                            .pickerStyle(.inline)
                        }
                    }
                    
                    // ── Date & time ───────────────────────────────────
                    Section(header: Text("Date & Time")) {
                        DatePicker("Appointment", selection: $appointmentDate, in: Date()...,
                                   displayedComponents: [.date, .hourAndMinute])
                        .tint(.teal)
                    }
                    
                    // ── Summary ───────────────────────────────────────
                    Section(header: Text("Summary")) {
                        LabeledContent("Duration") {
                            Text("\(service.durationMinutes) min").foregroundColor(.secondary)
                        }
                        LabeledContent("Price") {
                            Text(service.price.formatted(.currency(code: "USD")))
                                .foregroundColor(.teal).bold()
                        }
                        LabeledContent("End Time") {
                            let end = appointmentDate.addingTimeInterval(TimeInterval(service.durationMinutes * 60))
                            Text(end.formatted(date: .omitted, time: .shortened)).foregroundColor(.secondary)
                        }
                    }
                }
                .navigationTitle("Book Appointment")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear { contactName = clientName }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Confirm") {
                            if isFormValid {
                                saveBooking()
                            } else {
                                withAnimation { showValidationError = true }
                            }
                        }
                        .font(.headline).foregroundColor(.teal)
                        .disabled(isSaved)
                    }
                }
            }
        }
    }
    
    // MARK: Confirmation screen
    private var confirmationView: some View {
        VStack(spacing: 28) {
            Spacer()
            
            // Checkmark circle
            ZStack {
                Circle().fill(Color.teal.opacity(0.12)).frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56)).foregroundColor(.teal)
            }
            
            VStack(spacing: 8) {
                Text("You're Booked!").font(.title2.bold())
                Text("Your appointment at \(business.studioName) has been confirmed.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
            }
            
            // Booking summary card
            VStack(alignment: .leading, spacing: 14) {
                bookingConfirmRow(icon: "tag.fill",         label: "Service",  value: service.name)
                Divider()
                bookingConfirmRow(icon: "building.2.fill",  label: "Business", value: business.studioName)
                Divider()
                bookingConfirmRow(icon: "person.fill",      label: "Name",     value: contactName)
                Divider()
                bookingConfirmRow(icon: "phone.fill",       label: "Phone",    value: contactPhone)
                Divider()
                bookingConfirmRow(icon: "envelope.fill",    label: "Email",    value: contactEmail)
                Divider()
                bookingConfirmRow(icon: "calendar",         label: "Date",
                                  value: appointmentDate.formatted(date: .long, time: .shortened))
                Divider()
                bookingConfirmRow(icon: "dollarsign.circle.fill", label: "Price",
                                  value: service.price.formatted(.currency(code: "USD")))
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
            .padding(.horizontal)
            
            Spacer()
            
            Button("Done") { dismiss() }
                .font(.headline).foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.teal)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
                .padding(.bottom, 30)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Confirmed")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func bookingConfirmRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(.teal).frame(width: 20)
            Text(label).font(.caption).foregroundColor(.secondary).frame(width: 60, alignment: .leading)
            Text(value).font(.subheadline.bold()).lineLimit(1)
            Spacer()
        }
    }
    
    // MARK: Save
    private func saveBooking() {
        let endTime = appointmentDate.addingTimeInterval(TimeInterval(service.durationMinutes * 60))
        let providerName = selectedEmployee?.name ?? (employees.first?.name ?? "TBD")
        let appt = Appointment(
            customerName: contactName,
            employeeName: providerName,
            startTime: appointmentDate,
            endTime: endTime,
            price: service.price,
            status: .confirmed,
            businessCode: business.businessCode
        )
        appt.service = service
        modelContext.insert(appt)
        try? modelContext.save()
        isSaved = true
        withAnimation { showConfirmation = true }
    }
}

// MARK: - SCHEDULE VIEW

struct ClientScheduleView: View {
    let clientName: String
    @Query(sort: \Appointment.startTime) private var all: [Appointment]
    @Query private var allBusinesses: [BusinessProfile]
    
    var filtered: [Appointment] { all.filter { $0.customerName == clientName } }
    var upcoming: [Appointment] { filtered.filter { $0.startTime > Date() } }
    var past: [Appointment]     { filtered.filter { $0.startTime <= Date() }.reversed() }
    
    func businessName(for appt: Appointment) -> String {
        allBusinesses.first(where: { $0.businessCode == appt.businessCode })?.studioName ?? ""
    }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            if filtered.isEmpty {
                ContentUnavailableView(
                    "No Appointments Yet",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Head to Discover to find a business and book your first appointment.")
                )
            } else {
                List {
                    if !upcoming.isEmpty {
                        Section {
                            ForEach(upcoming) { appt in scheduleRow(appt, isPast: false) }
                        } header: {
                            Label("UPCOMING", systemImage: "calendar.badge.clock")
                                .font(.caption.bold()).foregroundColor(.teal)
                        }
                    }
                    if !past.isEmpty {
                        Section {
                            ForEach(past) { appt in scheduleRow(appt, isPast: true) }
                        } header: {
                            Label("PAST", systemImage: "clock.arrow.circlepath")
                                .font(.caption.bold()).foregroundColor(.secondary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("My Schedule")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func scheduleRow(_ appt: Appointment, isPast: Bool) -> some View {
        HStack(spacing: 14) {
            Capsule()
                .fill(isPast ? Color.secondary.opacity(0.3) : (appt.service?.themeColor ?? .teal))
                .frame(width: 4).padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(appt.service?.name ?? "Appointment").font(.headline)
                    .foregroundColor(isPast ? .secondary : .primary)
                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.caption2)
                    Text(appt.startTime.formatted(date: .abbreviated, time: .shortened))
                }
                .font(.caption).foregroundColor(.secondary)
                Label(appt.employeeName, systemImage: "person.circle")
                    .font(.caption2).foregroundColor(.teal).padding(.top, 2)
                let biz = businessName(for: appt)
                if !biz.isEmpty {
                    Label(biz, systemImage: "building.2").font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                let status = AppointmentStatus(rawValue: appt.statusRaw) ?? .pending
                let color: Color = status == .confirmed ? .teal : status == .completed ? .green : status == .cancelled ? .gray : .orange
                Text(appt.statusRaw).font(.system(size: 10, weight: .bold)).foregroundColor(color)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(color.opacity(0.1)).clipShape(Capsule())
                Text(appt.price.formatted(.currency(code: "USD"))).font(.caption.bold()).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - INSIGHTS VIEW

struct ClientInsightsView: View {
    let clientName: String
    @Query(sort: \Appointment.startTime) private var all: [Appointment]
    
    var myAppts: [Appointment]  { all.filter { $0.customerName == clientName } }
    var completed: [Appointment] { myAppts.filter { $0.status == .completed } }
    var totalSpent: Double       { myAppts.filter { $0.status == .completed || $0.status == .confirmed }.reduce(0) { $0 + $1.price } }
    var uniqueBusinesses: Int    { Set(myAppts.map { $0.businessCode }).filter { !$0.isEmpty }.count }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 12) {
                        SummaryBox(title: "Bookings",   value: "\(myAppts.count)",   icon: "calendar.badge.clock",  color: .teal)
                        SummaryBox(title: "Completed",  value: "\(completed.count)", icon: "checkmark.seal.fill",   color: .green)
                    }
                    .padding(.horizontal)
                    HStack(spacing: 12) {
                        SummaryBox(title: "Total Spent", value: totalSpent.formatted(.currency(code: "USD")), icon: "dollarsign.circle.fill", color: .indigo)
                        SummaryBox(title: "Businesses",  value: "\(uniqueBusinesses)", icon: "building.2.fill",       color: .purple)
                    }
                    .padding(.horizontal)
                    
                    // ── 7-Day Rhythm View ───────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.subheadline.bold())
                                .foregroundColor(.secondary)
                            Text("RHYTHM OF YOUR WEEK")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .tracking(1.0)
                        }
                        .padding(.horizontal, 2)

                        let next7 = (0..<7).compactMap {
                            Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: Date()))
                        }
                        VStack(spacing: 10) {
                            ForEach(next7, id: \.self) { day in
                                let dayAppts = myAppts.filter {
                                    Calendar.current.isDate($0.startTime, inSameDayAs: day)
                                    && $0.status != .cancelled
                                }
                                let load = calculateDayLoad(from: dayAppts)
                                let isToday = Calendar.current.isDateInToday(day)
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(day.formatted(.dateTime.weekday(.abbreviated)))
                                            .font(.caption.bold())
                                            .foregroundColor(isToday ? load.color : .secondary)
                                        Text(day.formatted(.dateTime.day()))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(width: 28)

                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(.systemGray5))
                                                .frame(height: 8)
                                            if !dayAppts.isEmpty {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(load.color)
                                                    .frame(
                                                        width: min(geo.size.width, geo.size.width * CGFloat(dayAppts.count) / 7),
                                                        height: 8
                                                    )
                                                    .animation(load.insertionAnimation, value: dayAppts.count)
                                            }
                                        }
                                    }
                                    .frame(height: 8)

                                    HStack(spacing: 4) {
                                        DayLoadBadge(load: load)
                                        Text(dayAppts.isEmpty ? "Free" : "\(dayAppts.count)")
                                            .font(.caption2.bold())
                                            .foregroundColor(dayAppts.isEmpty ? .secondary : load.color)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemBackground)))
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
                    .padding(.horizontal)

                    // ── Today's balance suggestions ──────────────────────────────
                    let suggestions = BalanceSuggestionEngine.suggestions(for: myAppts, on: Date())
                    if !suggestions.isEmpty {
                        BalanceSuggestionsPanel(suggestions: suggestions)
                            .padding(.horizontal)
                    }
                }
                .padding(.top, 20)
            }
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - STAR RATING VIEW (shared helper)

struct StarRatingView: View {
    let rating: Double
    let size: CGFloat
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                let filled = Double(star) <= rating
                let halfFilled = !filled && Double(star) - 0.5 <= rating
                Image(systemName: filled ? "star.fill" : halfFilled ? "star.leadinghalf.filled" : "star")
                    .font(.system(size: size))
                    .foregroundColor(.yellow)
            }
        }
    }
}

// MARK: - REVIEW CARD

struct ReviewCard: View {
    let review: Review
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.teal.opacity(0.12)).frame(width: 36, height: 36)
                    Text(review.reviewerName.prefix(1).uppercased())
                        .font(.subheadline.bold()).foregroundColor(.teal)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.reviewerName).font(.subheadline.bold())
                    Text(review.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                StarRatingView(rating: Double(review.stars), size: 11)
            }
            if !review.comment.isEmpty {
                Text(review.comment)
                    .font(.subheadline).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }
}

// MARK: - LEAVE REVIEW SHEET

struct LeaveReviewSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let businessCode: String
    let reviewerName: String
    
    @State private var selectedStars: Int = 5
    @State private var comment: String = ""
    @State private var isSaved = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Your Rating")) {
                    VStack(spacing: 16) {
                        // Tap-to-rate stars
                        HStack(spacing: 10) {
                            ForEach(1...5, id: \.self) { star in
                                Button { withAnimation(.spring(response: 0.2)) { selectedStars = star } } label: {
                                    Image(systemName: star <= selectedStars ? "star.fill" : "star")
                                        .font(.system(size: 34))
                                        .foregroundColor(star <= selectedStars ? .yellow : Color(.systemGray4))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        
                        Text(ratingLabel)
                            .font(.subheadline.bold())
                            .foregroundColor(.teal)
                    }
                }
                
                Section(header: Text("Your Comment (optional)")) {
                    TextField("Share your experience...", text: $comment, axis: .vertical)
                        .lineLimit(4...8)
                }
                
                Section(header: Text("Posting as")) {
                    Label(reviewerName, systemImage: "person.fill")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Leave a Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { saveReview() }
                        .font(.headline).foregroundColor(.teal)
                        .disabled(isSaved)
                }
            }
        }
    }
    
    private var ratingLabel: String {
        switch selectedStars {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Very Good"
        case 5: return "Excellent"
        default: return ""
        }
    }
    
    private func saveReview() {
        let review = Review(businessCode: businessCode, reviewerName: reviewerName,
                            stars: selectedStars, comment: comment)
        modelContext.insert(review)
        try? modelContext.save()
        isSaved = true
        dismiss()
    }
}
