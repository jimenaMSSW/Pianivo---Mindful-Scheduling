import Foundation
import SwiftData

@Model
final class User {
    // Ensures no two users have the same name
    @Attribute(.unique) var username: String
    
    // In a real app, we'd use a hash, but for a SwiftData demo, 
    // we'll keep it simple while acknowledging security.
    var passwordHash: String
    
    // Using a String-backed property for SwiftData compatibility 
    // with an enum wrapper for safety.
    var roleValue: String 
    
    init(username: String, passwordHash: String, role: UserRole = .client) {
        self.username = username
        self.passwordHash = passwordHash
        self.roleValue = role.rawValue
    }
    
    // Helper property to work with the Enum in your Views
    var role: UserRole {
        get { UserRole(rawValue: roleValue) ?? .client }
        set { roleValue = newValue.rawValue }
    }
}

// MARK: - User Role Enum
enum UserRole: String, Codable, CaseIterable {
    case owner = "owner"
    case employee = "employee"
    case client = "client"
    
    var displayName: String {
        self.rawValue.capitalized
    }
    
    var iconName: String {
        switch self {
        case .owner: return "crown.fill"
        case .employee: return "person.badge.clock.fill"
        case .client: return "person.fill"
        }
    }
}
