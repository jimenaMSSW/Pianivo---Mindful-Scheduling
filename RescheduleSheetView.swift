import SwiftUI
import SwiftData

struct RescheduleSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var appointment: Appointment
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Update Schedule") {
                    DatePicker("Start Time", selection: $appointment.startTime)
                    DatePicker("End Time", selection: $appointment.endTime)
                }

                let paymentLines = AppointmentPaymentSummary.paymentLines(for: appointment)
                if !paymentLines.isEmpty {
                    Section("Payment") {
                        ForEach(Array(paymentLines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.subheadline)
                        }
                        Text("Payment and deposit stay attached when this appointment is rescheduled.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
                    Button("Done") {
                        AppointmentReminderScheduler.scheduleTomorrowReminder(for: appointment)
                        addAppNotification(
                            in: modelContext,
                            audience: "client",
                            recipientName: appointment.customerName,
                            businessCode: appointment.businessCode,
                            title: "Appointment Rescheduled",
                            message: "\(appointment.service?.name ?? "Appointment") was moved to \(appointment.startTime.formatted(date: .abbreviated, time: .shortened)). Payment/deposit remains attached."
                        )
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
