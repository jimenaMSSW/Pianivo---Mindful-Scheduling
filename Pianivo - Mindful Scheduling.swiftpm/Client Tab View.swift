import SwiftUI
import SwiftData

struct ClientTabView: View {
    @Binding var selectedRole: String?
    @State private var currentStudentName = "Alex" 
    
    var body: some View {
        TabView {
            // Tab 1: Live Dashboard
            ClientDashboardView(studentName: currentStudentName)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            // Tab 2: The Booking System
            BookingSheetView() 
                .tabItem {
                    Label("Book", systemImage: "plus.circle.fill")
                }
            
            // Tab 3: Live Insights
            ClientInsightsView(studentName: currentStudentName)
                .tabItem {
                    Label("Insights", systemImage: "leaf.fill")
                }
        }
        .tint(.teal)
    }
}
