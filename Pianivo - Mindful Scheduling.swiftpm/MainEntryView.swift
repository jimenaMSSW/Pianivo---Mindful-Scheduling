import SwiftUI
import SwiftData

struct MainEntryView: View {
    @Environment(\.modelContext) private var modelContext
    
    // The core state that drives the entire app navigation
    @State private var selectedRole: String? = nil 
    @State private var isShowingAuth = false
    @State private var isLogin = true 
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            if let role = selectedRole {
                // Use the PianivoRootView we created to handle the actual TabView loading
                PianivoRootView(role: role, selectedRole: $selectedRole)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else {
                welcomeScreen
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        // High-quality animation for a premium feel
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: selectedRole)
    }
    
    private var welcomeScreen: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // 🌿 Branding Section
            VStack(spacing: 16) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.teal)
                    .shadow(color: .teal.opacity(0.3), radius: 10)
                
                Text("Pianivo")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                
                Text("Mindful scheduling. Burnout prevention.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            //  Judge Quick Access (Critical for Swift Student Challenge)
            VStack(spacing: 15) {
                Text("QUICK ACCESS FOR JUDGES")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .tracking(1.2)
                
                HStack(spacing: 15) {
                    QuickRoleButton(title: "Owner", icon: "crown.fill", role: "owner", selection: $selectedRole)
                    QuickRoleButton(title: "Staff", icon: "person.2.fill", role: "staff", selection: $selectedRole)
                    QuickRoleButton(title: "Client", icon: "person.fill", role: "client", selection: $selectedRole)
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 28).fill(Color.teal.opacity(0.08)))
            
            // Standard Auth (Simulated for demo)
            VStack(spacing: 18) {
                Button(action: { isLogin = true; isShowingAuth = true }) {
                    Text("Login to Account")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.teal)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                
                Button("Create New Account") {
                    isLogin = false
                    isShowingAuth = true
                }
                .font(.subheadline.bold())
                .foregroundColor(.teal)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .sheet(isPresented: $isShowingAuth) {
            if isLogin {
                SimpleLoginSheet(selectedRole: $selectedRole)
            } else {
                SignupTypeView(selectedRole: $selectedRole)
            }
        }
    }
}

// MARK: - MISSING COMPONENTS FIX

struct QuickRoleButton: View {
    let title: String
    let icon: String
    let role: String
    @Binding var selection: String?
    
    var body: some View {
        Button {
            withAnimation(.spring()) {
                selection = role
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 5)
        }
        .buttonStyle(.plain)
    }
}

struct SimpleLoginSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedRole: String?
    @State private var user = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Enter Credentials") {
                    TextField("Username", text: $user)
                    SecureField("Password", text: .constant("••••••"))
                }
                
                Button("Login") {
                    selectedRole = "owner" // Mock login
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.teal)
                .bold()
            }
            .navigationTitle("Login")
            .toolbar {
                Button("Cancel") { dismiss() }
            }
        }
        .presentationDetents([.medium])
    }
}

struct SignupTypeView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedRole: String?
    
    var body: some View {
        NavigationStack {
            List {
                Button("I am a Studio Owner") { selectedRole = "owner"; dismiss() }
                Button("I am a Teacher/Staff") { selectedRole = "staff"; dismiss() }
                Button("I am a Student/Client") { selectedRole = "client"; dismiss() }
            }
            .navigationTitle("Join Pianivo")
            .toolbar {
                Button("Close") { dismiss() }
            }
        }
    }
}
