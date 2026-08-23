import SwiftUI
import SwiftData

struct RescheduleSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Querying all to check against the specific employee
    @Query var allAppointments: [Appointment]
    
    @Bindable var appointment: Appointment
    @State private var newDate: Date
    @State private var isWarningActive = false // Live tracking of burnout risk
    
    init(appointment: Appointment) {
        self.appointment = appointment
        _newDate = State(initialValue: appointment.startTime)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 1. Context Header
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .foregroundColor(.teal)
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text(appointment.customerName)
                                .font(.headline)
                            Text("Current: \(appointment.startTime, style: .time)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // 2. The Picker
                Section("New Schedule") {
                    DatePicker("New Start Time", selection: $newDate)
                        .datePickerStyle(.graphical)
                        .tint(.teal)
                }
                
                // 3. Real-time Burnout Check
                Section {
                    HStack(alignment: .top, spacing: 15) {
                        Image(systemName: isWarningActive ? "exclamationmark.triangle.fill" : "leaf.fill")
                            .foregroundColor(isWarningActive ? .orange : .teal)
                            .font(.title3)
                            .symbolEffect(.bounce, value: isWarningActive)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isWarningActive ? "Burnout Risk Detected" : "Balanced Schedule")
                                .font(.subheadline.bold())
                                .foregroundColor(isWarningActive ? .orange : .teal)
                            
                            Text(isWarningActive ? 
                                 "This creates a gap of less than 15 minutes. Consider adding a buffer." : 
                                    "This slot provides ample time for a mindful transition between sessions.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(isWarningActive ? Color.orange.opacity(0.1) : Color.teal.opacity(0.1))
            }
            .navigationTitle("Reschedule")
            .navigationBarTitleDisplayMode(.inline)
            // MARK: - Logic Triggers
            .onChange(of: newDate) { _, _ in
                validateSchedule()
            }
            .onAppear {
                validateSchedule()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Change") {
                        updateAppointment()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    // MARK: - Helper Logic
    
    private func validateSchedule() {
        let conflict = allAppointments.contains { appt in
            // Must be the same employee, but NOT the same appointment record
            guard appt.id != appointment.id && appt.employeeName == appointment.employeeName else { return false }
            
            let gap = abs(appt.startTime.timeIntervalSince(newDate))
            return gap < 900 // Less than 15 minutes
        }
        
        // Haptic feedback if it newly becomes stressful
        if conflict && !isWarningActive {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        }
        
        isWarningActive = conflict
    }
    
    private func updateAppointment() {
        withAnimation(.spring()) {
            appointment.startTime = newDate
            // Assuming 1-hour session; adjust if your model uses a duration variable
            appointment.endTime = newDate.addingTimeInterval(3600) 
            
            // Explicitly saving the context
            try? modelContext.save()
            dismiss()
        }
    }
}
