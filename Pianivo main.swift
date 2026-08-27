import SwiftUI
import SwiftData
import StoreKit
import UIKit
import FirebaseCore
import FirebaseAuth

import FirebaseFirestore

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
    case day, week, month, year
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
#if DEBUG
func simpleHash(_ input: String) -> String {
    var hash = 5381
    for char in input.unicodeScalars {
        hash = ((hash << 5) &+ hash) &+ Int(char.value)
    }
    return String(hash)
}
#endif

func makeInviteCode(for userId: UUID) -> String {
    String(userId.uuidString.prefix(8).uppercased())
}

/// Generates a deep-link invite URL that employees can tap to auto-fill their signup
func makeInviteDeepLink(inviteToken: String, businessName: String) -> String {
    let encodedName = businessName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? businessName
    return "pianivo://invite?token=\(inviteToken)&studio=\(encodedName)"
}

// MARK: - FIREBASE AUTH

struct FirebaseUserProfile {
    let uid: String
    let name: String
    let email: String
    let role: String
    let businessCode: String

    init(uid: String, name: String, email: String, role: String, businessCode: String) {
        self.uid = uid
        self.name = name
        self.email = email
        self.role = role
        self.businessCode = businessCode
    }

    init?(uid: String, data: [String: Any]) {
        guard
            let name = data["name"] as? String,
            let email = data["email"] as? String,
            let role = data["role"] as? String
        else {
            return nil
        }

        self.uid = uid
        self.name = name
        self.email = email
        self.role = role
        self.businessCode = data["businessCode"] as? String ?? ""
    }
}

enum BackendAPIError: LocalizedError {
    case invalidResponse
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .serverMessage(let message):
            return message
        }
    }
}

enum OwnerSubscriptionProduct {
    static let monthly = "com.pianivo.mindfulscheduling.owner.monthly"
    static let allIDs = [monthly]
}

enum OwnerIAPSubscriptionError: LocalizedError {
    case productUnavailable
    case purchasePending
    case purchaseCancelled
    case unverifiedPurchase

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "The owner subscription is not available yet. Make sure the product ID is created in App Store Connect."
        case .purchasePending:
            return "The subscription is pending approval from Apple. You can finish account creation after it is approved."
        case .purchaseCancelled:
            return "The subscription was cancelled."
        case .unverifiedPurchase:
            return "Apple could not verify this subscription. Please try again."
        }
    }
}

enum AccountDeletionError: LocalizedError {
    case missingAuthenticatedUser
    case missingEmail

    var errorDescription: String? {
        switch self {
        case .missingAuthenticatedUser:
            return "No signed-in Pianivo account was found."
        case .missingEmail:
            return "This account is missing an email address."
        }
    }
}

@MainActor
final class OwnerIAPSubscriptionService: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var hasActiveOwnerSubscription = false

    private var transactionUpdatesTask: Task<Void, Never>?

    var ownerProduct: Product? {
        products.first { $0.id == OwnerSubscriptionProduct.monthly }
    }

    var displayPrice: String {
        ownerProduct?.displayPrice ?? "App Store subscription required"
    }

    init() {
        transactionUpdatesTask = listenForTransactionUpdates()
        Task {
            await refreshEntitlements()
            await loadProducts()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: OwnerSubscriptionProduct.allIDs)
        } catch {
            products = []
        }
    }

    func purchaseOwnerSubscription() async throws {
        if ownerProduct == nil {
            await loadProducts()
        }

        guard let product = ownerProduct else {
            throw OwnerIAPSubscriptionError.productUnavailable
        }

        let result = try await product.purchase()
        switch result {
        case .success(.verified(let transaction)):
            try await handleVerified(transaction)
        case .success(.unverified):
            throw OwnerIAPSubscriptionError.unverifiedPurchase
        case .pending:
            throw OwnerIAPSubscriptionError.purchasePending
        case .userCancelled:
            throw OwnerIAPSubscriptionError.purchaseCancelled
        @unknown default:
            throw OwnerIAPSubscriptionError.productUnavailable
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var activeSubscriptionFound = false

        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            guard transaction.productID == OwnerSubscriptionProduct.monthly else {
                continue
            }
            guard transaction.revocationDate == nil else {
                continue
            }
            if let expirationDate = transaction.expirationDate, expirationDate < Date() {
                continue
            }

            activeSubscriptionFound = true
        }

        hasActiveOwnerSubscription = activeSubscriptionFound
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard let self else {
                    return
                }

                if case .verified(let transaction) = result {
                    try? await self.handleVerified(transaction)
                }
            }
        }
    }

    private func handleVerified(_ transaction: StoreKit.Transaction) async throws {
        if transaction.productID == OwnerSubscriptionProduct.monthly,
           transaction.revocationDate == nil,
           transaction.expirationDate.map({ $0 >= Date() }) ?? true {
            hasActiveOwnerSubscription = true
        }

        await transaction.finish()
        await refreshEntitlements()
    }
}

struct StaffInviteService {
    static func createInvite(email: String, businessCode: String, studioName: String) async throws -> String {
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let data: [String: Any] = [
            "email": email.lowercased(),
            "businessCode": businessCode,
            "studioName": studioName,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp(),
            "expiresAt": Timestamp(date: Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date())
        ]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Firestore.firestore()
                .collection("staffInvites")
                .document(token)
                .setData(data) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
        }

        return token
    }

    static func validateInvite(token: String, email: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let inviteRef = Firestore.firestore().collection("staffInvites").document(token)
            Firestore.firestore().runTransaction({ transaction, errorPointer in
                do {
                    let snapshot = try transaction.getDocument(inviteRef)
                    guard let data = snapshot.data() else {
                        errorPointer?.pointee = NSError(domain: "PianivoInvite", code: 404, userInfo: [NSLocalizedDescriptionKey: "This employee invite was not found."])
                        return nil
                    }
                    guard (data["status"] as? String) == "pending" else {
                        errorPointer?.pointee = NSError(domain: "PianivoInvite", code: 409, userInfo: [NSLocalizedDescriptionKey: "This employee invite has already been used."])
                        return nil
                    }
                    guard (data["email"] as? String)?.lowercased() == email.lowercased() else {
                        errorPointer?.pointee = NSError(domain: "PianivoInvite", code: 403, userInfo: [NSLocalizedDescriptionKey: "This invite was sent to a different email address."])
                        return nil
                    }
                    guard let businessCode = data["businessCode"] as? String, !businessCode.isEmpty else {
                        errorPointer?.pointee = NSError(domain: "PianivoInvite", code: 422, userInfo: [NSLocalizedDescriptionKey: "This invite is missing its business link."])
                        return nil
                    }

                    transaction.updateData([
                        "status": "accepted",
                        "acceptedAt": FieldValue.serverTimestamp()
                    ], forDocument: inviteRef)
                    return businessCode as NSString
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let businessCode = result as? String {
                    continuation.resume(returning: businessCode)
                } else {
                    continuation.resume(throwing: BackendAPIError.invalidResponse)
                }
            }
        }
    }
}

enum FirebaseAuthFlowError: LocalizedError {
    case missingUserProfile

    var errorDescription: String? {
        switch self {
        case .missingUserProfile:
            return "This account is missing its Pianivo profile. Please contact support."
        }
    }
}

struct FirebaseAccountService {
    static func signIn(email: String, password: String) async throws -> FirebaseUserProfile {
        let authResult = try await signInWithFirebase(email: email, password: password)
        return try await fetchProfile(uid: authResult.user.uid)
    }

    static func createAccount(
        name: String,
        email: String,
        password: String,
        role: String,
        businessCode: String
    ) async throws -> FirebaseUserProfile {
        let authResult = try await createFirebaseUser(email: email, password: password)
        let profile = FirebaseUserProfile(
            uid: authResult.user.uid,
            name: name,
            email: email,
            role: role,
            businessCode: businessCode
        )

        try await saveProfile(profile)
        return profile
    }

    static func createStaffAccount(
        name: String,
        email: String,
        password: String,
        inviteToken: String
    ) async throws -> FirebaseUserProfile {
        let authResult = try await createFirebaseUser(email: email, password: password)

        do {
            let businessCode = try await StaffInviteService.validateInvite(token: inviteToken, email: email)
            let profile = FirebaseUserProfile(
                uid: authResult.user.uid,
                name: name,
                email: email,
                role: "staff",
                businessCode: businessCode
            )
            try await saveProfile(profile)
            return profile
        } catch {
            try? await authResult.user.delete()
            throw error
        }
    }

    static func signOut() {
        try? Auth.auth().signOut()
    }

    static func deleteCurrentAccount(password: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw AccountDeletionError.missingAuthenticatedUser
        }
        guard let email = user.email else {
            throw AccountDeletionError.missingEmail
        }

        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            user.reauthenticate(with: credential) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        try await deleteProfile(uid: user.uid)
        try await user.delete()
    }

    static func markOwnerSubscriptionProvider(uid: String, productID: String) async throws {
        let data: [String: Any] = [
            "subscriptionProvider": "apple",
            "ownerSubscriptionProductID": productID,
            "subscriptionUpdatedAt": FieldValue.serverTimestamp()
        ]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Firestore.firestore()
                .collection("users")
                .document(uid)
                .setData(data, merge: true) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
        }
    }

    private static func signInWithFirebase(email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult, Error>) in
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: FirebaseAuthFlowError.missingUserProfile)
                }
            }
        }
    }

    private static func createFirebaseUser(email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult, Error>) in
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: FirebaseAuthFlowError.missingUserProfile)
                }
            }
        }
    }

    private static func saveProfile(_ profile: FirebaseUserProfile) async throws {
        let data: [String: Any] = [
            "name": profile.name,
            "email": profile.email,
            "role": profile.role,
            "businessCode": profile.businessCode,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Firestore.firestore()
                .collection("users")
                .document(profile.uid)
                .setData(data, merge: true) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
        }
    }

    private static func deleteProfile(uid: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Firestore.firestore()
                .collection("users")
                .document(uid)
                .delete { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
        }
    }

    private static func fetchProfile(uid: String) async throws -> FirebaseUserProfile {
        try await withCheckedThrowingContinuation { continuation in
            Firestore.firestore()
                .collection("users")
                .document(uid)
                .getDocument { snapshot, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard
                        let data = snapshot?.data(),
                        let profile = FirebaseUserProfile(uid: uid, data: data)
                    else {
                        continuation.resume(throwing: FirebaseAuthFlowError.missingUserProfile)
                        return
                    }

                    continuation.resume(returning: profile)
                }
        }
    }
}

@discardableResult
func upsertLocalUserMirror(
    profile: FirebaseUserProfile,
    in modelContext: ModelContext,
    existingUsers: [User]
) -> User {
    if let existing = existingUsers.first(where: { $0.email.lowercased() == profile.email.lowercased() }) {
        existing.name = profile.name
        existing.role = profile.role
        existing.businessCode = profile.businessCode
        try? modelContext.save()
        return existing
    }

    let localUser = User(
        name: profile.name,
        role: profile.role,
        email: profile.email,
        passwordHash: "",
        businessCode: profile.businessCode
    )
    modelContext.insert(localUser)
    try? modelContext.save()
    return localUser
}

enum PianivoAccountRole {
    case client
    case employee
    case owner
}

func cleanUpLocalAccountData(
    role: PianivoAccountRole,
    userName: String,
    userId: UUID?,
    businessCode: String,
    in modelContext: ModelContext,
    users: [User],
    employees: [Employee],
    appointments: [Appointment],
    ownerClientMessages: [OwnerClientMessage],
    employeeClientMessages: [EmployeeClientMessage],
    reviews: [Review]
) {
    if let userId, let user = users.first(where: { $0.id == userId }) {
        modelContext.delete(user)
    } else {
        users
            .filter { $0.name == userName && roleMatches($0.role, role: role) }
            .forEach { modelContext.delete($0) }
    }

    switch role {
    case .client:
        appointments
            .filter { $0.customerName == userName }
            .forEach { modelContext.delete($0) }
        ownerClientMessages
            .filter { $0.clientName == userName }
            .forEach { modelContext.delete($0) }
        employeeClientMessages
            .filter { $0.clientName == userName }
            .forEach { modelContext.delete($0) }
        reviews
            .filter { $0.reviewerName == userName }
            .forEach { modelContext.delete($0) }
    case .employee:
        employees
            .filter { $0.name == userName && (businessCode.isEmpty || $0.businessCode == businessCode) }
            .forEach { modelContext.delete($0) }
        appointments
            .filter { $0.employeeName == userName && (businessCode.isEmpty || $0.businessCode == businessCode) }
            .forEach { $0.employeeName = "Former Employee" }
        employeeClientMessages
            .filter { $0.employeeName == userName }
            .forEach { modelContext.delete($0) }
    case .owner:
        break
    }

    try? modelContext.save()
}

private func roleMatches(_ userRole: String, role: PianivoAccountRole) -> Bool {
    switch role {
    case .client:
        return userRole == "client"
    case .employee:
        return userRole == "staff"
    case .owner:
        return userRole == "owner"
    }
}

// MARK: - SETTINGS & ACCOUNT MANAGEMENT

struct AccountSettingsView: View {
    let role: PianivoAccountRole
    let displayName: String
    let onAccountDeleted: () -> Void

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AccountManagementView(
                        role: role,
                        displayName: displayName,
                        onAccountDeleted: onAccountDeleted
                    )
                } label: {
                    Label("Account Management", systemImage: "person.crop.circle.badge.gearshape")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AccountManagementView: View {
    let role: PianivoAccountRole
    let displayName: String
    let onAccountDeleted: () -> Void

    @State private var password = ""
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false
    @State private var showError = false
    @State private var errorMessage = "We couldn't complete your account deletion. Please try again."
    @State private var showManageSubscriptions = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundColor(.teal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
                            .font(.subheadline.bold())
                        Text(roleTitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section {
                SecureField("Current Password", text: $password)
                    .textContentType(.password)
            } footer: {
                Text("Enter your current password before permanently deleting this account.")
            }

            if role == .owner {
                Section {
                    Button {
                        showManageSubscriptions = true
                    } label: {
                        Label("Manage Subscription", systemImage: "creditcard")
                    }
                } footer: {
                    Text("Deleting your Pianivo account does not automatically cancel your App Store subscription.")
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label(isDeleting ? "Deleting Account..." : "Delete Account", systemImage: "trash")
                }
                .disabled(isDeleting || password.isEmpty)
            }
        }
        .navigationTitle("Account Management")
        .navigationBarTitleDisplayMode(.inline)
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        .alert("Delete Account?", isPresented: $showDeleteConfirmation) {
            if role == .owner {
                Button("Manage Subscription") {
                    showManageSubscriptions = true
                }
            }
            Button("Delete Account", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteWarning)
        }
        .alert("Unable to Delete Account", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var roleTitle: String {
        switch role {
        case .client:
            return "Client Account"
        case .employee:
            return "Employee Account"
        case .owner:
            return "Owner Account"
        }
    }

    private var deleteWarning: String {
        switch role {
        case .client:
            return "This will permanently delete your Pianivo account and associated personal data. This action cannot be undone."
        case .employee:
            return "This will permanently delete your Pianivo account and associated personal data. You will no longer have access to the business account associated with your employee profile. This action cannot be undone."
        case .owner:
            return """
            This will permanently delete your Pianivo account and associated personal data.

            Deleting your Pianivo account does not automatically cancel your App Store subscription. If you have an active subscription, Apple may continue billing you until the subscription is canceled.

            You can manage or cancel your subscription through your Apple ID subscription settings.

            This action cannot be undone.
            """
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        do {
            try await FirebaseAccountService.deleteCurrentAccount(password: password)
            onAccountDeleted()
        } catch {
            print("Account deletion failed: \(error.localizedDescription)")
            errorMessage = "We couldn't complete your account deletion. Please try again."
            showError = true
        }
        isDeleting = false
    }
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
    @State private var pendingInviteToken = ""
    
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
            
            ScrollView {
                VStack(spacing: 32) {
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
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 80)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            if sheet == .signIn {
                SignInView(selectedRole: $selectedRole, userName: $userName, loggedInUserId: $loggedInUserId)
            } else {
                CreateAccountView(
                    selectedRole: $selectedRole,
                    userName: $userName,
                    loggedInUserId: $loggedInUserId,
                    prefilledInviteToken: pendingInviteToken
                )
            }
        }
        .onOpenURL { url in
            guard url.scheme == "pianivo", url.host == "invite" else {
                return
            }
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            pendingInviteToken = components?.queryItems?.first(where: { $0.name == "token" })?.value ?? ""
            activeSheet = .createAccount
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
    @State private var isSigningIn = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
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
                        Task { await signIn() }
                    } label: {
                        Text(isSigningIn ? "Signing In..." : "Sign In")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.teal)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal)
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 32)
            }
            .disabled(isSigningIn)
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func signIn() async {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }

        isSigningIn = true
        errorMessage = nil

        do {
            let profile = try await FirebaseAccountService.signIn(email: cleanEmail, password: password)
            let localUser = upsertLocalUserMirror(profile: profile, in: modelContext, existingUsers: users)
            userName = localUser.name
            loggedInUserId = localUser.id
            selectedRole = localUser.role
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSigningIn = false
    }
}

// MARK: - CREATE ACCOUNT VIEW

struct CreateAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [User]
    @StateObject private var ownerSubscriptionService = OwnerIAPSubscriptionService()
    
    @Binding var selectedRole: String?
    @Binding var userName: String
    @Binding var loggedInUserId: UUID?
    let prefilledInviteToken: String
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var inviteToken = ""
    @State private var selectedAccountType = "client"
    @State private var errorMessage: String?
    @State private var isCreatingAccount = false
    @State private var isRestoringPurchase = false
    
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
                            AuthField(icon: "link", placeholder: "Employee Invite Token", text: $inviteToken, isSecure: false)
                        }

                        if selectedAccountType == "owner" {
                            VStack(spacing: 8) {
                                Text(ownerSubscriptionService.hasActiveOwnerSubscription ? "Owner subscription active." : "Owner access requires an Apple subscription: \(ownerSubscriptionService.displayPrice)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)

                                Button {
                                    Task { await restoreOwnerPurchase() }
                                } label: {
                                    Text(isRestoringPurchase ? "Restoring..." : "Restore Purchases")
                                        .font(.caption.bold())
                                }
                                .disabled(isRestoringPurchase)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    if let error = errorMessage {
                        Text(error).foregroundColor(.red).font(.caption)
                    }
                    
                    Button {
                        Task { await createAccount() }
                    } label: {
                        Text(primaryButtonTitle)
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
            .disabled(isCreatingAccount)
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if !prefilledInviteToken.isEmpty {
                    inviteToken = prefilledInviteToken
                    selectedAccountType = "staff"
                }
            }
        }
    }

    private var primaryButtonTitle: String {
        if isCreatingAccount {
            return selectedAccountType == "owner" ? "Checking Apple Subscription..." : "Creating Account..."
        }
        if selectedAccountType == "owner" {
            return ownerSubscriptionService.hasActiveOwnerSubscription ? "Create Owner Account" : "Subscribe with Apple"
        }
        return "Create Account"
    }
    
    private func createAccount() async {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !cleanName.isEmpty, !cleanEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }

        guard !users.contains(where: { $0.email.lowercased() == cleanEmail }) else {
            errorMessage = "An account with this email already exists."
            return
        }

        var businessCode: String
        let staffInviteToken: String
        
        if selectedAccountType == "owner" {
            staffInviteToken = ""
            businessCode = String(UUID().uuidString.prefix(8).uppercased())
            if !ownerSubscriptionService.hasActiveOwnerSubscription {
                isCreatingAccount = true
                errorMessage = nil
                do {
                    try await ownerSubscriptionService.purchaseOwnerSubscription()
                    guard ownerSubscriptionService.hasActiveOwnerSubscription else {
                        errorMessage = "Apple has not confirmed an active subscription yet. Please try again."
                        isCreatingAccount = false
                        return
                    }
                } catch OwnerIAPSubscriptionError.purchaseCancelled {
                    isCreatingAccount = false
                    return
                } catch {
                    errorMessage = error.localizedDescription
                    isCreatingAccount = false
                    return
                }
            }
        } else if selectedAccountType == "staff" {
            let cleanInviteToken = inviteToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanInviteToken.isEmpty else {
                errorMessage = "Please open your employee invite link or enter the invite token from your email."
                return
            }
            staffInviteToken = cleanInviteToken
            businessCode = ""
        } else {
            staffInviteToken = ""
            businessCode = ""
        }

        isCreatingAccount = true
        errorMessage = nil

        do {
            let profile: FirebaseUserProfile
            if selectedAccountType == "staff" {
                profile = try await FirebaseAccountService.createStaffAccount(
                    name: cleanName,
                    email: cleanEmail,
                    password: password,
                    inviteToken: staffInviteToken
                )
                businessCode = profile.businessCode
            } else {
                profile = try await FirebaseAccountService.createAccount(
                    name: cleanName,
                    email: cleanEmail,
                    password: password,
                    role: selectedAccountType,
                    businessCode: businessCode
                )

                if selectedAccountType == "owner" {
                    try await FirebaseAccountService.markOwnerSubscriptionProvider(
                        uid: profile.uid,
                        productID: OwnerSubscriptionProduct.monthly
                    )
                }
            }
            let newUser = upsertLocalUserMirror(profile: profile, in: modelContext, existingUsers: users)

            // If staff, also create an Employee record linked to the business
            if selectedAccountType == "staff" {
                let employee = Employee(name: cleanName, businessCode: businessCode)
                modelContext.insert(employee)
                try? modelContext.save()
            }

            userName = newUser.name
            loggedInUserId = newUser.id
            selectedRole = newUser.role
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isCreatingAccount = false
    }

    private func restoreOwnerPurchase() async {
        isRestoringPurchase = true
        errorMessage = nil

        do {
            try await ownerSubscriptionService.restorePurchases()
            errorMessage = ownerSubscriptionService.hasActiveOwnerSubscription ? nil : "No active owner subscription was found for this Apple ID."
        } catch {
            errorMessage = error.localizedDescription
        }

        isRestoringPurchase = false
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
    @Query private var employees: [Employee]
    @Query private var appointments: [Appointment]
    @Query private var ownerClientMessages: [OwnerClientMessage]
    @Query private var employeeClientMessages: [EmployeeClientMessage]
    @Query private var reviews: [Review]
    
    var loggedInUser: User? {
        guard let id = loggedInUserId else { return nil }
        return users.first(where: { $0.id == id })
    }
    
    var body: some View {
        Group {
            if role == "owner" {
                OwnerDashboard(onLogout: {
                    FirebaseAccountService.signOut()
                    selectedRole = nil
                }, onAccountDeleted: {
                    handleAccountDeleted(role: .owner, businessCode: loggedInUser?.businessCode ?? "")
                })
            } else if role == "staff" {
                let businessCode = loggedInUser?.businessCode ?? ""
                EmployeeDashboard(employeeName: userName, businessCode: businessCode, onLogout: {
                    FirebaseAccountService.signOut()
                    selectedRole = nil
                }, onAccountDeleted: {
                    handleAccountDeleted(role: .employee, businessCode: businessCode)
                })
            } else {
                ClientTabView(clientName: userName, onLogout: {
                    FirebaseAccountService.signOut()
                    selectedRole = nil
                }, onAccountDeleted: {
                    handleAccountDeleted(role: .client, businessCode: "")
                })
            }
        }
    }

    private func handleAccountDeleted(role: PianivoAccountRole, businessCode: String) {
        cleanUpLocalAccountData(
            role: role,
            userName: userName,
            userId: loggedInUserId,
            businessCode: businessCode,
            in: modelContext,
            users: users,
            employees: employees,
            appointments: appointments,
            ownerClientMessages: ownerClientMessages,
            employeeClientMessages: employeeClientMessages,
            reviews: reviews
        )
        FirebaseAccountService.signOut()
        selectedRole = nil
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


#if DEBUG
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
#endif
