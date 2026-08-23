import SwiftUI
import SwiftData

struct AppointmentListView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Sort by time forward so the next appointment is at the top
    @Query(sort: \Appointment.startTime, order: .forward) private var allAppointments: [Appointment]
    
    let userRole: String
    let currentUserName: String
    
    // Computed property for filtered data
    private var filteredAppointments: [Appointment] {
        let role = userRole.lowercased()
        if role == "owner" {
            return allAppointments
        } else {
            // Filters based on the staff name
            return allAppointments.filter { $0.employeeName == currentUserName }
        }
    }
    
    var body: some View {
        Group {
            if filteredAppointments.isEmpty {
                ContentUnavailableView(
                    "No Sessions",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("There are no appointments scheduled at this time.")
                )
            } else {
                List {
                    ForEach(filteredAppointments) { appt in
                        AppointmentCard(appt: appt, showEmployee: userRole.lowercased() == "owner")
                            .listRowSeparator(.hidden) 
                            .listRowBackground(Color.clear)
                        // Adding a transition for smoother deletes
                            .transition(.move(edge: .leading))
                    }
                    .onDelete(perform: deleteAppointments)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(userRole.lowercased() == "owner" ? "All Schedules" : "My Sessions")
    }
    
    private func deleteAppointments(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let appointmentToDelete = filteredAppointments[index]
                modelContext.delete(appointmentToDelete)
            }
            // Optional: Explicit save for immediate persistence
            try? modelContext.save()
        }
    }
}

// MARK: - Improved Appointment Card
struct AppointmentCard: View {
    let appt: Appointment
    var showEmployee: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading) {
                    Text(appt.customerName)
                        .font(.headline)
                    
                    if showEmployee {
                        Label(appt.employeeName, systemImage: "person.badge.clock")
                            .font(.caption)
                            .foregroundColor(.teal)
                    }
                }
                
                Spacer()
                
                // FIXED: Status Badge using the displayTitle helper from our Enum
                Text(appt.status.displayTitle)
                    .font(.system(size: 10, weight: .black))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(appt.isPaid ? Color.teal.opacity(0.15) : Color.orange.opacity(0.15))
                    .foregroundColor(appt.isPaid ? .teal : .orange)
                    .clipShape(Capsule())
            }
            
            Divider()
            
            HStack {
                Label(appt.startTime.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                Spacer()
                Label(appt.startTime.formatted(date: .omitted, time: .shortened), systemImage: "clock")
            }
            .font(.footnote)
            .foregroundColor(.secondary)
            
            // Proactive Stress Check Insight
            if appt.isHighStress {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Tight transition – Mindful break suggested")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.orange)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .secondarySystemGroupedBackground)))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(appt.isHighStress ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .padding(.horizontal, 4)
    }
}
