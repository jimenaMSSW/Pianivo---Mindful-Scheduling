import SwiftUI
import SwiftData

struct RescheduleSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var appointment: Appointment
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Update Schedule") {
                    DatePicker("Start Time", selection: $appointment.startTime)
                    DatePicker("End Time", selection: $appointment.endTime)
                }
                
                Section("Status") {
                    // FIX: Bind to $appointment.statusRaw (stored property) instead of
                    // $appointment.status (computed property), which @Bindable cannot handle.
                    Picker("Appointment Status", selection: $appointment.statusRaw) {
                        ForEach(AppointmentStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Reschedule Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
