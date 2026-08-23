import SwiftUI
import SwiftData

struct ClientDashboardView: View {
    // We pass this in from the login or parent view
    let currentStudentName: String 
    
    // FIX: Use a Predicate to ensure the student only sees THEIR data
    @Query private var appointments: [Appointment]
    
    // We initialize the query with a filter
    init(studentName: String) {
        self.currentStudentName = studentName
        
        // Filter: Only appointments where customerName matches
        let predicate = #Predicate<Appointment> { appt in
            appt.customerName == studentName
        }
        
        _appointments = Query(filter: predicate, sort: \.startTime)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // 🌿 Welcome Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your Mindful Space")
                            .font(.caption.bold())
                            .foregroundColor(.teal)
                        
                        Text("Hi, \(currentStudentName)!")
                            .font(.title2.bold())
                        
                        Text("Ready for your next session?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.teal.opacity(0.12))
                    .cornerRadius(18)
                    
                    // 📅 Upcoming Appointments
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Upcoming Sessions")
                            .font(.headline)
                        
                        if appointments.isEmpty {
                            ContentUnavailableView(
                                "No Sessions Yet",
                                systemImage: "calendar.badge.plus",
                                description: Text("Book your first session to begin.")
                            )
                        } else {
                            // Only show sessions that haven't ended yet
                            ForEach(appointments.filter { $0.endTime > .now }) { appt in
                                AppointmentCard(appt: appt, showEmployee: true)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Pianivo")
            .background(Color(uiColor: .systemGroupedBackground)) // Subtle grey background
        }
    }
}
