import SwiftUI
import SwiftData
import FirebaseCore

// MARK: - APP

@main
struct PianivoApp: App {
    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Appointment.self,
            Service.self,
            Employee.self,
            OwnerClientMessage.self,
            EmployeeClientMessage.self,
            BusinessProfile.self,
            Review.self
        ])

        // Tier 1: persistent storage
        let persistent = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        if let container = try? ModelContainer(
            for: schema,
            configurations: [persistent]
        ) {
            return container
        }

        // Tier 2: remove a corrupted local store and retry
        let storeURL = persistent.url
        try? FileManager.default.removeItem(at: storeURL)
        try? FileManager.default.removeItem(
            at: storeURL.appendingPathExtension("shm")
        )
        try? FileManager.default.removeItem(
            at: storeURL.appendingPathExtension("wal")
        )

        if let container = try? ModelContainer(
            for: schema,
            configurations: [persistent]
        ) {
            return container
        }

        // Tier 3: in-memory fallback for Swift Playgrounds
        let memory = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        return (try? ModelContainer(
            for: schema,
            configurations: [memory]
        )) ?? (try! ModelContainer(for: schema))
    }()

    init() {
        configureFirebase()
    }

    var body: some Scene {
        WindowGroup {
            MainEntryView()
                .onAppear {
                    DemoDataSeeder.seedIfNeeded(
                        in: Self.sharedModelContainer
                    )
                }
        }
        .modelContainer(Self.sharedModelContainer)
    }

    private func configureFirebase() {
        // Prevent duplicate initialization during previews or relaunches.
        guard FirebaseApp.app() == nil else {
            return
        }

        guard let plistURL = Bundle.module.url(
            forResource: "GoogleService-Info",
            withExtension: "plist"
        ) else {
            fatalError(
                "GoogleService-Info.plist was not found in the Resources folder."
            )
        }

        guard let options = FirebaseOptions(
            contentsOfFile: plistURL.path
        ) else {
            fatalError(
                "GoogleService-Info.plist exists but Firebase could not read it."
            )
        }

        FirebaseApp.configure(options: options)
    }
}

// MARK: - GLOBAL ENUMS

enum AppointmentStatus: String, Codable, CaseIterable {
    case confirmed = "Confirmed"
    case completed = "Completed"
    case cancelled = "Cancelled"
    case pending = "Pending"
}

enum RevenuePeriod: String, CaseIterable, Identifiable {
    case day, week, month
    var id: String { self.rawValue }
}

// MARK: - MODELS

@Model
final class User {
    var id: UUID = UUID()
    var name: String
    var role: String
    var email: String
    var passwordHash: String
    var businessCode: String
    
    init(name: String, role: String, email: String, passwordHash: String, businessCode: String = "") {
        self.name = name
        self.role = role
        self.email = email
        self.passwordHash = passwordHash
        self.businessCode = businessCode
    }
}

@Model
final class Service: Identifiable {
    var id: UUID = UUID()
    var name: String
    var price: Double
    var colorHex: String = "#008080"
    /// Links this service to a specific business (matches BusinessProfile.businessCode & User.businessCode)
    var businessCode: String = ""
    /// Optional duration in minutes
    var durationMinutes: Int = 60
    /// Optional description
    var serviceDescription: String = ""
    /// Category for filtering (e.g. "Hair", "Massage", "Facial")
    var category: String = ""
    
    var themeColor: Color {
        Color(hex: colorHex) ?? .teal
    }
    
    init(name: String, price: Double, colorHex: String = "#008080", businessCode: String = "", durationMinutes: Int = 60, serviceDescription: String = "", category: String = "") {
        self.name = name
        self.price = price
        self.colorHex = colorHex
        self.businessCode = businessCode
        self.durationMinutes = durationMinutes
        self.serviceDescription = serviceDescription
        self.category = category
    }
}

@Model
final class Employee: Identifiable {
    var id: UUID = UUID()
    var name: String
    var joinDate: Date = Date()
    /// Links this employee to a specific business (matches BusinessProfile.businessCode)
    var businessCode: String = ""
    
    init(name: String, businessCode: String = "") {
        self.name = name
        self.businessCode = businessCode
    }
}

@Model
final class Appointment {
    var customerName: String
    var employeeName: String
    var startTime: Date
    var endTime: Date
    var price: Double
    var statusRaw: String
    var isHighStress: Bool = false
    /// The business code this appointment belongs to
    var businessCode: String = ""
    
    @Relationship(deleteRule: .nullify)
    var service: Service?
    
    var status: AppointmentStatus {
        get { AppointmentStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
    
    init(customerName: String, employeeName: String, startTime: Date, endTime: Date, price: Double, status: AppointmentStatus = .pending, businessCode: String = "") {
        self.customerName = customerName
        self.employeeName = employeeName
        self.startTime = startTime
        self.endTime = endTime
        self.price = price
        self.statusRaw = status.rawValue
        self.businessCode = businessCode
    }
}

@Model
final class OwnerClientMessage {
    var content: String
    var timestamp: Date = Date()
    var isFromOwner: Bool
    var clientName: String
    
    init(content: String, isFromOwner: Bool, clientName: String) {
        self.content = content
        self.isFromOwner = isFromOwner
        self.clientName = clientName
    }
}

@Model
final class EmployeeClientMessage {
    var content: String
    var timestamp: Date = Date()
    var isFromEmployee: Bool
    var employeeName: String
    var clientName: String
    
    init(content: String, isFromEmployee: Bool, employeeName: String, clientName: String) {
        self.content = content
        self.isFromEmployee = isFromEmployee
        self.employeeName = employeeName
        self.clientName = clientName
    }
}

@Model
final class BusinessProfile {
    var id: UUID = UUID()
    /// Unique code used to link employees and services to this business
    var businessCode: String = ""
    var studioName: String
    var address: String
    var city: String
    var state: String
    var zipCode: String
    var phone: String
    var email: String
    var website: String
    var mondayHours: String
    var tuesdayHours: String
    var wednesdayHours: String
    var thursdayHours: String
    var fridayHours: String
    var saturdayHours: String
    var sundayHours: String
    var about: String
    /// Category/type of business for discovery (e.g. "Wellness", "Music", "Beauty")
    var businessCategory: String = ""
    
    init(
        businessCode: String = "",
        studioName: String = "",
        address: String = "",
        city: String = "",
        state: String = "",
        zipCode: String = "",
        phone: String = "",
        email: String = "",
        website: String = "",
        mondayHours: String = "9:00 AM – 6:00 PM",
        tuesdayHours: String = "9:00 AM – 6:00 PM",
        wednesdayHours: String = "9:00 AM – 6:00 PM",
        thursdayHours: String = "9:00 AM – 6:00 PM",
        fridayHours: String = "9:00 AM – 6:00 PM",
        saturdayHours: String = "10:00 AM – 4:00 PM",
        sundayHours: String = "Closed",
        about: String = "",
        businessCategory: String = ""
    ) {
        self.businessCode = businessCode
        self.studioName = studioName
        self.address = address
        self.city = city
        self.state = state
        self.zipCode = zipCode
        self.phone = phone
        self.email = email
        self.website = website
        self.mondayHours = mondayHours
        self.tuesdayHours = tuesdayHours
        self.wednesdayHours = wednesdayHours
        self.thursdayHours = thursdayHours
        self.fridayHours = fridayHours
        self.saturdayHours = saturdayHours
        self.sundayHours = sundayHours
        self.about = about
        self.businessCategory = businessCategory
    }
}


// MARK: - REVIEW MODEL

@Model
final class Review: Identifiable {
    var id: UUID = UUID()
    /// The business this review is for
    var businessCode: String = ""
    /// The client who left the review
    var reviewerName: String
    /// 1–5 stars
    var stars: Int
    /// Optional written comment
    var comment: String
    var createdAt: Date = Date()
    
    init(businessCode: String, reviewerName: String, stars: Int, comment: String = "") {
        self.businessCode = businessCode
        self.reviewerName = reviewerName
        self.stars = max(1, min(5, stars))
        self.comment = comment
    }
}


// MARK: - AUTH HELPERS
// NOTE: Demo only — not cryptographically secure.
// A real app would use CryptoKit or bcrypt via a backend
func simpleHash(_ input: String) -> String {
    var hash = 5381
    for char in input.unicodeScalars {
        hash = ((hash << 5) &+ hash) &+ Int(char.value)
    }
    return String(hash)
}

func makeInviteCode(for userId: UUID) -> String {
    String(userId.uuidString.prefix(8).uppercased())
}

/// Generates a deep-link invite URL that employees can tap to auto-fill their signup
func makeInviteDeepLink(businessCode: String, businessName: String) -> String {
    let encodedName = businessName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? businessName
    return "pianivo://invite?code=\(businessCode)&studio=\(encodedName)"
}

// MARK: - MAIN ENTRY VIEW

enum ActiveSheet: Identifiable {
    case signIn, createAccount
    var id: Int { hashValue }
}

struct MainEntryView: View {
    @State private var selectedRole: String? = nil
    @State private var userName: String = ""
    @State private var loggedInUserId: UUID? = nil
    @State private var activeSheet: ActiveSheet? = nil
    
    var body: some View {
        Group {
            if let role = selectedRole {
                PianivoRootView(role: role, userName: userName, loggedInUserId: loggedInUserId, selectedRole: $selectedRole)
            } else {
                landingView
            }
        }
    }
    
    private var landingView: some View {
        ZStack {
            LinearGradient(colors: [Color.teal.opacity(0.15), Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 8) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.teal)
                    Text("Pianivo")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                    Text("Mindful scheduling for businesses")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 14) {
                    Button {
                        activeSheet = .signIn
                    } label: {
                        Text("Sign In")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.teal)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                    
                    Button {
                        activeSheet = .createAccount
                    } label: {
                        Text("Create Account")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.teal.opacity(0.1))
                            .foregroundColor(.teal)
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal)
                
                // Demo Quick Access
                VStack(spacing: 10) {
                    Text("Quick Demo Access").font(.caption).foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        QuickRoleButton(title: "Owner", icon: "crown.fill", role: "owner", name: "Studio Owner", selection: $selectedRole, userName: $userName)
                        QuickRoleButton(title: "Staff", icon: "person.fill", role: "staff", name: "Demo Staff", selection: $selectedRole, userName: $userName)
                        QuickRoleButton(title: "Client", icon: "heart.fill", role: "client", name: "Demo Client", selection: $selectedRole, userName: $userName)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
        }
        .sheet(item: $activeSheet) { sheet in
            if sheet == .signIn {
                SignInView(selectedRole: $selectedRole, userName: $userName, loggedInUserId: $loggedInUserId)
            } else {
                CreateAccountView(selectedRole: $selectedRole, userName: $userName, loggedInUserId: $loggedInUserId)
            }
        }
    }
}

// MARK: - SIGN IN VIEW

struct SignInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [User]
    
    @Binding var selectedRole: String?
    @Binding var userName: String
    @Binding var loggedInUserId: UUID?
    
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Welcome Back")
                    .font(.largeTitle.bold())
                    .padding(.top, 20)
                
                VStack(spacing: 14) {
                    AuthField(icon: "envelope", placeholder: "Email", text: $email, isSecure: false)
                    AuthField(icon: "lock", placeholder: "Password", text: $password, isSecure: true)
                }
                .padding(.horizontal)
                
                if let error = errorMessage {
                    Text(error).foregroundColor(.red).font(.caption)
                }
                
                Button {
                    signIn()
                } label: {
                    Text("Sign In")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.teal)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func signIn() {
        let hash = simpleHash(password)
        if let user = users.first(where: { $0.email.lowercased() == email.lowercased() && $0.passwordHash == hash }) {
            userName = user.name
            loggedInUserId = user.id
            selectedRole = user.role
            dismiss()
        } else {
            errorMessage = "Invalid email or password."
        }
    }
}

// MARK: - CREATE ACCOUNT VIEW

struct CreateAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [User]
    
    @Binding var selectedRole: String?
    @Binding var userName: String
    @Binding var loggedInUserId: UUID?
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var inviteCode = ""
    @State private var selectedAccountType = "client"
    @State private var errorMessage: String?
    
    let accountTypes = [
        ("owner", "Studio Owner", "crown.fill", Color.teal),
        ("staff", "Employee / Staff", "person.fill", Color.blue),
        ("client", "Client", "heart.fill", Color.pink)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Create Account")
                        .font(.largeTitle.bold())
                        .padding(.top, 20)
                    
                    // Account type selector
                    VStack(spacing: 10) {
                        SectionLabel("Account Type")
                        ForEach(accountTypes, id: \.0) { type in
                            AccountTypeCard(
                                title: type.1,
                                description: type.0 == "owner" ? "Manage your studio, staff, and bookings" :
                                    type.0 == "staff" ? "View your schedule and manage appointments" :
                                    "Browse businesses and book appointments",
                                icon: type.2,
                                color: type.3,
                                isSelected: selectedAccountType == type.0,
                                action: { selectedAccountType = type.0 }
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 14) {
                        AuthField(icon: "person", placeholder: "Full Name", text: $name, isSecure: false)
                        AuthField(icon: "envelope", placeholder: "Email", text: $email, isSecure: false)
                        AuthField(icon: "lock", placeholder: "Password", text: $password, isSecure: true)
                        
                        if selectedAccountType == "staff" {
                            AuthField(icon: "number", placeholder: "Studio Invite Code", text: $inviteCode, isSecure: false)
                        }
                    }
                    .padding(.horizontal)
                    
                    if let error = errorMessage {
                        Text(error).foregroundColor(.red).font(.caption)
                    }
                    
                    Button {
                        createAccount()
                    } label: {
                        Text("Create Account")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.teal)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func createAccount() {
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        guard !users.contains(where: { $0.email.lowercased() == email.lowercased() }) else {
            errorMessage = "An account with this email already exists."
            return
        }
        
        let hash = simpleHash(password)
        let businessCode: String
        
        if selectedAccountType == "owner" {
            // Generate a new unique business code for the owner
            businessCode = String(UUID().uuidString.prefix(8).uppercased())
        } else if selectedAccountType == "staff" {
            // Validate invite code
            guard !inviteCode.isEmpty else {
                errorMessage = "Please enter your studio invite code."
                return
            }
            businessCode = inviteCode.uppercased().trimmingCharacters(in: .whitespaces)
        } else {
            businessCode = ""
        }
        
        let newUser = User(name: name, role: selectedAccountType, email: email, passwordHash: hash, businessCode: businessCode)
        modelContext.insert(newUser)
        
        // If staff, also create an Employee record linked to the business
        if selectedAccountType == "staff" {
            let employee = Employee(name: name, businessCode: businessCode)
            modelContext.insert(employee)
        }
        
        try? modelContext.save()
        
        userName = name
        loggedInUserId = newUser.id
        selectedRole = selectedAccountType
        dismiss()
    }
}

// MARK: - ROOT & ROLE VIEWS

struct PianivoRootView: View {
    let role: String
    let userName: String
    let loggedInUserId: UUID?
    @Binding var selectedRole: String?
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    
    var loggedInUser: User? {
        guard let id = loggedInUserId else { return nil }
        return users.first(where: { $0.id == id })
    }
    
    var body: some View {
        Group {
            if role == "owner" {
                OwnerDashboard(onLogout: { selectedRole = nil })
            } else if role == "staff" {
                let businessCode = loggedInUser?.businessCode ?? ""
                EmployeeDashboard(employeeName: userName, businessCode: businessCode, onLogout: { selectedRole = nil })
            } else {
                ClientTabView(clientName: userName, onLogout: { selectedRole = nil })
            }
        }
    }
}

struct QuickRoleButton: View {
    let title: String
    let icon: String
    let role: String
    let name: String
    @Binding var selection: String?
    @Binding var userName: String
    
    var body: some View {
        Button {
            userName = name
            selection = role
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title2)
                Text(title).font(.caption.bold())
            }
            .frame(maxWidth: .infinity).padding(.vertical, 18)
            .background(Color.teal.opacity(0.1)).cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - UTILITIES

extension Color {
    init?(hex: String) {
        let hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

// MARK: - SHARED UI

struct AuthField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(.teal).frame(width: 20)
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .keyboardType(placeholder.lowercased().contains("email") ? .emailAddress : .default)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.caption.bold()).foregroundColor(.secondary).tracking(1.2)
    }
}

struct AccountTypeCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title2)
                    .foregroundColor(isSelected ? .white : color)
                    .frame(width: 48, height: 48)
                    .background(isSelected ? color : color.opacity(0.1))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).foregroundColor(.primary)
                    Text(description).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? color : .secondary).font(.title3)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? color : Color.clear, lineWidth: 2))
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}


// MARK: - DEMO DATA SEEDER

struct DemoDataSeeder {
    
    /// Runs once on first launch. Guarded by UserDefaults flag "demo_seeded_v1".
    static func seedIfNeeded(in container: ModelContainer) {
        guard !UserDefaults.standard.bool(forKey: "demo_seeded_v1") else { return }
        let ctx = ModelContext(container)
        seed(ctx)
        try? ctx.save()
        UserDefaults.standard.set(true, forKey: "demo_seeded_v1")
    }
    
    private static func seed(_ ctx: ModelContext) {
        
        // ── Shared password hash ("demo1234") ─────────────────────────────────
        let pw = simpleHash("demo1234")
        
        // ══════════════════════════════════════════════════════════════════════
        // BUSINESS 1 — Zenith Wellness Spa
        // ══════════════════════════════════════════════════════════════════════
        let bc1 = "ZENITH01"
        
        let owner1 = User(name: "Maya Chen", role: "owner", email: "maya@zenithspa.com", passwordHash: pw, businessCode: bc1)
        ctx.insert(owner1)
        
        let biz1 = BusinessProfile(
            businessCode: bc1,
            studioName: "Zenith Wellness",
            address: "142 Serenity Lane",
            city: "San Francisco",
            state: "CA",
            zipCode: "94105",
            phone: "(415) 555-0192",
            email: "hello@zenithwellness.com",
            website: "zenithwellness.com",
            mondayHours: "9:00 AM – 7:00 PM",
            tuesdayHours: "9:00 AM – 7:00 PM",
            wednesdayHours: "9:00 AM – 7:00 PM",
            thursdayHours: "9:00 AM – 8:00 PM",
            fridayHours: "9:00 AM – 8:00 PM",
            saturdayHours: "10:00 AM – 6:00 PM",
            sundayHours: "11:00 AM – 5:00 PM",
            about: "A sanctuary for the modern professional. We blend evidence-based wellness with a mindful approach to help you feel your best.",
            businessCategory: "Wellness"
        )
        ctx.insert(biz1)
        
        // Services
        let s1a = Service(name: "Deep Tissue Massage", price: 120, colorHex: "#008080", businessCode: bc1, durationMinutes: 60, serviceDescription: "Targets deep muscle layers to release chronic tension and knots.", category: "Massage")
        let s1b = Service(name: "Swedish Relaxation", price: 95, colorHex: "#26A69A", businessCode: bc1, durationMinutes: 60, serviceDescription: "Classic full-body massage for ultimate relaxation and stress relief.", category: "Massage")
        let s1c = Service(name: "Hot Stone Therapy", price: 145, colorHex: "#5C6BC0", businessCode: bc1, durationMinutes: 90, serviceDescription: "Heated basalt stones melt away tension and improve circulation.", category: "Massage")
        let s1d = Service(name: "Facial Rejuvenation", price: 110, colorHex: "#EC407A", businessCode: bc1, durationMinutes: 60, serviceDescription: "Customised facial targeting hydration, brightness, and anti-ageing.", category: "Facial")
        let s1e = Service(name: "Aromatherapy Session", price: 85, colorHex: "#66BB6A", businessCode: bc1, durationMinutes: 45, serviceDescription: "Essential oil blends chosen for your mood and wellness goals.", category: "Wellness")
        [s1a, s1b, s1c, s1d, s1e].forEach { ctx.insert($0) }
        
        // Staff
        let e1a = Employee(name: "Jordan Rivera", businessCode: bc1)
        let e1b = Employee(name: "Priya Nair", businessCode: bc1)
        [e1a, e1b].forEach { ctx.insert($0) }
        
        let staff1a = User(name: "Jordan Rivera", role: "staff", email: "jordan@zenithspa.com", passwordHash: pw, businessCode: bc1)
        let staff1b = User(name: "Priya Nair",    role: "staff", email: "priya@zenithspa.com",  passwordHash: pw, businessCode: bc1)
        [staff1a, staff1b].forEach { ctx.insert($0) }
        
        // Appointments — relative to now so calendar always looks populated
        let now = Date()
        let cal = Calendar.current
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: cal.startOfDay(for: now))!.addingTimeInterval(10 * 3600) }
        func daysFromNow(_ n: Int, hour: Int = 10) -> Date { cal.date(byAdding: .day, value: n, to: cal.startOfDay(for: now))!.addingTimeInterval(Double(hour) * 3600) }
        
        let appts1: [(String, Employee, Service, Date, AppointmentStatus)] = [
            ("Olivia Park",    e1a, s1a, daysFromNow(1, hour: 10),  .confirmed),
            ("Marcus Webb",    e1b, s1b, daysFromNow(1, hour: 14),  .confirmed),
            ("Sara Kim",       e1a, s1c, daysFromNow(2, hour: 11),  .confirmed),
            ("Lena Torres",    e1b, s1d, daysFromNow(3, hour: 9),   .confirmed),
            ("James Liu",      e1a, s1e, daysFromNow(4, hour: 15),  .pending),
            ("Olivia Park",    e1b, s1b, daysAgo(1),                .completed),
            ("Marcus Webb",    e1a, s1a, daysAgo(3),                .completed),
            ("Rachel Adams",   e1b, s1c, daysAgo(5),                .completed),
            ("Tom Nguyen",     e1a, s1d, daysAgo(7),                .cancelled),
        ]
        var a1store: [Appointment] = []
        for (client, emp, svc, date, status) in appts1 {
            let a = Appointment(customerName: client, employeeName: emp.name,
                                startTime: date, endTime: date.addingTimeInterval(Double(svc.durationMinutes * 60)),
                                price: svc.price, status: status, businessCode: bc1)
            a.service = svc
            ctx.insert(a)
            a1store.append(a)
        }
        
        // Reviews
        let reviews1: [(String, Int, String)] = [
            ("Olivia Park",  5, "Absolutely incredible experience. Jordan is so skilled — my back pain is completely gone after one session. Will be back every month!"),
            ("Marcus Webb",  5, "The Swedish massage was exactly what I needed. The space is so calming and Priya made me feel completely at ease. Highly recommend."),
            ("Rachel Adams", 4, "Hot stone therapy was amazing. Gave 4 stars only because I had to wait 10 mins past my appointment time. The treatment itself was 5 stars."),
            ("Sara Kim",     5, "Best facial I've ever had. My skin looked incredible for a week after. The whole team is so professional and welcoming."),
            ("James Liu",    5, "Such a peaceful space. The aromatherapy session helped with my anxiety more than I expected. Booking again next week."),
        ]
        for (name, stars, comment) in reviews1 {
            ctx.insert(Review(businessCode: bc1, reviewerName: name, stars: stars, comment: comment))
        }
        
        // Messages
        ctx.insert(OwnerClientMessage(content: "Hi Olivia! Just confirming your Deep Tissue appointment tomorrow at 10am with Jordan. See you then! 🌿", isFromOwner: true, clientName: "Olivia Park"))
        ctx.insert(OwnerClientMessage(content: "Thank you! I'll be there. Can I request extra focus on my shoulders?", isFromOwner: false, clientName: "Olivia Park"))
        ctx.insert(OwnerClientMessage(content: "Absolutely, I'll let Jordan know. See you tomorrow!", isFromOwner: true, clientName: "Olivia Park"))
        
        ctx.insert(EmployeeClientMessage(content: "Hi Marcus, looking forward to your session tomorrow afternoon!", isFromEmployee: true, employeeName: "Priya Nair", clientName: "Marcus Webb"))
        ctx.insert(EmployeeClientMessage(content: "Thanks Priya! Quick question — should I avoid eating before?", isFromEmployee: false, employeeName: "Priya Nair", clientName: "Marcus Webb"))
        ctx.insert(EmployeeClientMessage(content: "Just avoid a heavy meal at least an hour before and you'll be fine. See you at 2pm!", isFromEmployee: true, employeeName: "Priya Nair", clientName: "Marcus Webb"))
        
        // ══════════════════════════════════════════════════════════════════════
        // BUSINESS 2 — Elevate Fitness Studio
        // ══════════════════════════════════════════════════════════════════════
        let bc2 = "ELEVATE2"
        
        let owner2 = User(name: "Alex Morgan", role: "owner", email: "alex@elevatefitness.com", passwordHash: pw, businessCode: bc2)
        ctx.insert(owner2)
        
        let biz2 = BusinessProfile(
            businessCode: bc2,
            studioName: "Elevate Fitness",
            address: "88 Movement Ave",
            city: "Austin",
            state: "TX",
            zipCode: "78701",
            phone: "(512) 555-0247",
            email: "book@elevatefitness.com",
            website: "elevatefitness.com",
            mondayHours: "6:00 AM – 9:00 PM",
            tuesdayHours: "6:00 AM – 9:00 PM",
            wednesdayHours: "6:00 AM – 9:00 PM",
            thursdayHours: "6:00 AM – 9:00 PM",
            fridayHours: "6:00 AM – 8:00 PM",
            saturdayHours: "7:00 AM – 6:00 PM",
            sundayHours: "8:00 AM – 4:00 PM",
            about: "Results-driven personal training and group fitness. Whether you're a beginner or an athlete, we meet you where you are and push you further.",
            businessCategory: "Fitness"
        )
        ctx.insert(biz2)
        
        let s2a = Service(name: "1-on-1 Personal Training", price: 90,  colorHex: "#F44336", businessCode: bc2, durationMinutes: 60, serviceDescription: "Fully customised workout with your dedicated personal trainer.", category: "Training")
        let s2b = Service(name: "HIIT Class",               price: 35,  colorHex: "#FF7043", businessCode: bc2, durationMinutes: 45, serviceDescription: "High-intensity interval training. Burn calories and build endurance.", category: "Group")
        let s2c = Service(name: "Yoga Flow",                price: 30,  colorHex: "#AB47BC", businessCode: bc2, durationMinutes: 60, serviceDescription: "Vinyasa-style yoga connecting breath and movement.", category: "Group")
        let s2d = Service(name: "Nutrition Coaching",       price: 75,  colorHex: "#26A69A", businessCode: bc2, durationMinutes: 60, serviceDescription: "One-on-one session to build a sustainable eating plan for your goals.", category: "Coaching")
        let s2e = Service(name: "Recovery & Stretch",       price: 55,  colorHex: "#42A5F5", businessCode: bc2, durationMinutes: 45, serviceDescription: "Guided stretching and foam rolling to accelerate recovery.", category: "Recovery")
        [s2a, s2b, s2c, s2d, s2e].forEach { ctx.insert($0) }
        
        let e2a = Employee(name: "Chris Park", businessCode: bc2)
        let e2b = Employee(name: "Dana Wells", businessCode: bc2)
        [e2a, e2b].forEach { ctx.insert($0) }
        ctx.insert(User(name: "Chris Park", role: "staff", email: "chris@elevatefitness.com", passwordHash: pw, businessCode: bc2))
        ctx.insert(User(name: "Dana Wells", role: "staff", email: "dana@elevatefitness.com",  passwordHash: pw, businessCode: bc2))
        
        let appts2: [(String, Employee, Service, Date, AppointmentStatus)] = [
            ("Ryan Scott",    e2a, s2a, daysFromNow(1, hour: 7),   .confirmed),
            ("Nina Patel",    e2b, s2b, daysFromNow(1, hour: 9),   .confirmed),
            ("Leo Chang",     e2a, s2c, daysFromNow(2, hour: 8),   .confirmed),
            ("Amy Foster",    e2b, s2d, daysFromNow(2, hour: 12),  .pending),
            ("Ryan Scott",    e2a, s2e, daysAgo(2),                .completed),
            ("Nina Patel",    e2b, s2a, daysAgo(4),                .completed),
            ("Leo Chang",     e2a, s2b, daysAgo(6),                .completed),
        ]
        for (client, emp, svc, date, status) in appts2 {
            let a = Appointment(customerName: client, employeeName: emp.name,
                                startTime: date, endTime: date.addingTimeInterval(Double(svc.durationMinutes * 60)),
                                price: svc.price, status: status, businessCode: bc2)
            a.service = svc
            ctx.insert(a)
        }
        
        let reviews2: [(String, Int, String)] = [
            ("Ryan Scott",  5, "Chris completely transformed my fitness. Down 15 lbs in 2 months with real muscle gain. The programming is genuinely excellent."),
            ("Nina Patel",  4, "HIIT classes are intense but so rewarding. Dana pushes you just the right amount. Great community vibe too."),
            ("Leo Chang",   5, "The yoga flow class is a perfect counterbalance to my office life. I leave feeling completely reset every time."),
        ]
        for (name, stars, comment) in reviews2 {
            ctx.insert(Review(businessCode: bc2, reviewerName: name, stars: stars, comment: comment))
        }
        
        // ══════════════════════════════════════════════════════════════════════
        // BUSINESS 3 — Radiance Beauty Bar
        // ══════════════════════════════════════════════════════════════════════
        let bc3 = "RADIANC3"
        
        let owner3 = User(name: "Sofia Reyes", role: "owner", email: "sofia@radiancebeauty.com", passwordHash: pw, businessCode: bc3)
        ctx.insert(owner3)
        
        let biz3 = BusinessProfile(
            businessCode: bc3,
            studioName: "Radiance Beauty",
            address: "310 Glow Street",
            city: "Miami",
            state: "FL",
            zipCode: "33101",
            phone: "(305) 555-0318",
            email: "appointments@radiancebeauty.com",
            website: "radiancebeauty.com",
            mondayHours: "Closed",
            tuesdayHours: "10:00 AM – 7:00 PM",
            wednesdayHours: "10:00 AM – 7:00 PM",
            thursdayHours: "10:00 AM – 8:00 PM",
            fridayHours: "9:00 AM – 8:00 PM",
            saturdayHours: "9:00 AM – 7:00 PM",
            sundayHours: "11:00 AM – 5:00 PM",
            about: "Miami's favourite boutique beauty bar. We specialise in precision haircuts, expert colour, lash extensions, and luxury nail treatments.",
            businessCategory: "Beauty"
        )
        ctx.insert(biz3)
        
        let s3a = Service(name: "Signature Haircut",      price: 75,  colorHex: "#EC407A", businessCode: bc3, durationMinutes: 60, serviceDescription: "Precision cut tailored to your face shape and lifestyle.", category: "Hair")
        let s3b = Service(name: "Full Colour & Highlights",price: 180, colorHex: "#FFA726", businessCode: bc3, durationMinutes: 120, serviceDescription: "Full colour with highlights for dimension and vibrancy.", category: "Hair")
        let s3c = Service(name: "Lash Extensions",        price: 140, colorHex: "#AB47BC", businessCode: bc3, durationMinutes: 90, serviceDescription: "Classic or volume lash sets for a natural to glam finish.", category: "Lashes")
        let s3d = Service(name: "Luxury Manicure",        price: 55,  colorHex: "#66BB6A", businessCode: bc3, durationMinutes: 45, serviceDescription: "Shaping, cuticle care, massage, and your choice of polish.", category: "Nails")
        let s3e = Service(name: "Luxury Pedicure",        price: 65,  colorHex: "#42A5F5", businessCode: bc3, durationMinutes: 60, serviceDescription: "Full foot treatment with exfoliation, massage, and polish.", category: "Nails")
        [s3a, s3b, s3c, s3d, s3e].forEach { ctx.insert($0) }
        
        let e3a = Employee(name: "Bianca Lowe",  businessCode: bc3)
        let e3b = Employee(name: "Marco Silva",  businessCode: bc3)
        [e3a, e3b].forEach { ctx.insert($0) }
        ctx.insert(User(name: "Bianca Lowe",  role: "staff", email: "bianca@radiancebeauty.com", passwordHash: pw, businessCode: bc3))
        ctx.insert(User(name: "Marco Silva",  role: "staff", email: "marco@radiancebeauty.com",  passwordHash: pw, businessCode: bc3))
        
        let appts3: [(String, Employee, Service, Date, AppointmentStatus)] = [
            ("Claire Dunn",   e3a, s3a, daysFromNow(1, hour: 11),  .confirmed),
            ("Yuki Tanaka",   e3b, s3b, daysFromNow(1, hour: 13),  .confirmed),
            ("Claire Dunn",   e3a, s3c, daysFromNow(3, hour: 10),  .confirmed),
            ("Ava Brooks",    e3b, s3d, daysFromNow(4, hour: 14),  .pending),
            ("Yuki Tanaka",   e3a, s3e, daysAgo(2),                .completed),
            ("Ava Brooks",    e3b, s3a, daysAgo(4),                .completed),
            ("Claire Dunn",   e3a, s3b, daysAgo(8),                .completed),
        ]
        for (client, emp, svc, date, status) in appts3 {
            let a = Appointment(customerName: client, employeeName: emp.name,
                                startTime: date, endTime: date.addingTimeInterval(Double(svc.durationMinutes * 60)),
                                price: svc.price, status: status, businessCode: bc3)
            a.service = svc
            ctx.insert(a)
        }
        
        let reviews3: [(String, Int, String)] = [
            ("Claire Dunn",  5, "Bianca is an absolute artist. She understood exactly what I wanted and the cut is perfect. I won't go anywhere else now."),
            ("Yuki Tanaka",  5, "The colour and highlights are stunning — so much natural dimension. Marco really knows his craft. Already booked my next appointment."),
            ("Ava Brooks",   4, "Lovely manicure, great attention to detail. The salon itself is beautiful. Will definitely be back for the pedicure next time."),
        ]
        for (name, stars, comment) in reviews3 {
            ctx.insert(Review(businessCode: bc3, reviewerName: name, stars: stars, comment: comment))
        }
        
        // ══════════════════════════════════════════════════════════════════════
        // DEMO CLIENT ACCOUNT — signs in as "Demo Client"
        // Appointments pre-linked so the client dashboard looks populated
        // ══════════════════════════════════════════════════════════════════════
        let clientUser = User(name: "Demo Client", role: "client", email: "client@pianivo.com", passwordHash: pw, businessCode: "")
        ctx.insert(clientUser)
        
        // Give the demo client their own appointments across two businesses
        let clientAppts: [(String, Service, Employee, Date, AppointmentStatus, String)] = [
            ("Demo Client", s1a, e1a, daysFromNow(2, hour: 10), .confirmed, bc1),
            ("Demo Client", s2a, e2a, daysFromNow(5, hour: 8),  .confirmed, bc2),
            ("Demo Client", s3c, e3a, daysFromNow(7, hour: 11), .confirmed, bc3),
            ("Demo Client", s1b, e1b, daysAgo(3),               .completed, bc1),
            ("Demo Client", s2b, e2b, daysAgo(10),              .completed, bc2),
        ]
        for (client, svc, emp, date, status, bc) in clientAppts {
            let a = Appointment(customerName: client, employeeName: emp.name,
                                startTime: date, endTime: date.addingTimeInterval(Double(svc.durationMinutes * 60)),
                                price: svc.price, status: status, businessCode: bc)
            a.service = svc
            ctx.insert(a)
        }
    }
}
