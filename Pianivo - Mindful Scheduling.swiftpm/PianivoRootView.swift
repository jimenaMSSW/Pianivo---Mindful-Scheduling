import SwiftUI

struct PianivoRootView: View {
    let role: String
    @Binding var selectedRole: String?
    
    // Tracks which tab is currently active
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // --- ROLE SPECIFIC MAIN TAB ---
            Group {
                switch role.lowercased() {
                case "owner":
                    OwnerDashboard()
                        .tabItem {
                            Label("Management", systemImage: "crown.fill")
                        }
                        .tag(0)
                    
                case "employee", "staff":
                    EmployeeDashboard()
                        .tabItem {
                            Label("My Flow", systemImage: "timer.circle.fill")
                        }
                        .tag(0)
                    
                case "client":
                    ClientPlaceholderView()
                        .tabItem {
                            Label("Book Session", systemImage: "calendar.badge.plus")
                        }
                        .tag(0)
                default:
                    EmptyView()
                }
            }
            
            // --- SHARED TAB: INSIGHTS ---
            // Everyone gets to see the mindfulness logic, 
            // as this is the "core" of your app's mission.
            MindfulInsightsView(selectedRole: $selectedRole)
                .tabItem {
                    Label("Insights", systemImage: "leaf.fill")
                }
                .tag(1)
            
            // --- SHARED TAB: SETTINGS/EXIT ---
            // Provides a clean way to go back to the role selection
            ExitView(selectedRole: $selectedRole)
                .tabItem {
                    Label("System", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(.teal)
    }
}

// MARK: - Helper Views

struct ExitView: View {
    @Binding var selectedRole: String?
    
    var body: some View {
        NavigationStack {
            List {
                Section("Account Session") {
                    Button(role: .destructive) {
                        withAnimation(.spring()) {
                            selectedRole = nil
                        }
                    } label: {
                        Label("Switch Persona / Logout", systemImage: "arrow.left.circle")
                    }
                }
            }
            .navigationTitle("System")
        }
    }
}

struct EmployeeDashboard: View {
    var body: some View {
        ContentUnavailableView(
            "Staff Dashboard",
            systemImage: "person.badge.clock",
            description: Text("View your assigned piano sessions and daily break schedule.")
        )
    }
}

struct ClientPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Client Portal",
            systemImage: "music.note.house",
            description: Text("Booking and lesson history features coming soon.")
        )
    }
}
