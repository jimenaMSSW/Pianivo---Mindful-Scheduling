import SwiftUI
import SwiftData

struct BookingSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Service.name) private var services: [Service]
    @Query(sort: \Employee.name) private var employees: [Employee]
    
    @State private var customerName: String = ""
    @State private var selectedService: Service?
    @State private var selectedEmployee: Employee?
    @State private var appointmentDate: Date = Date()
    
    var initialClientName: String? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Client Information")) {
                    TextField("Customer Name", text: $customerName)
                        .onAppear {
                            if let name = initialClientName, customerName.isEmpty {
                                customerName = name
                            }
                        }
                }
                
                Section(header: Text("Service & Provider")) {
                    Picker("Select Service", selection: $selectedService) {
                        Text("Choose a service").tag(nil as Service?)
                        ForEach(services) { service in
                            Text("\(service.name) (\(service.price.formatted(.currency(code: "USD"))))")
                                .tag(service as Service?)
                        }
                    }
                    
                    Picker("Select Staff", selection: $selectedEmployee) {
                        Text("Any available provider").tag(nil as Employee?)
                        ForEach(employees) { emp in
                            Text(emp.name).tag(emp as Employee?)
                        }
                    }
                }
                
                Section(header: Text("Date & Time")) {
                    DatePicker("Appointment Time",
                               selection: $appointmentDate,
                               in: Date()...,
                               displayedComponents: [.date, .hourAndMinute])
                    .tint(.teal)
                }
            }
            .navigationTitle("Book Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Book") {
                        saveAppointment()
                    }
                    .bold()
                    .disabled(customerName.isEmpty || selectedService == nil || selectedEmployee == nil)
                }
            }
        }
    }
    
    private func saveAppointment() {
        guard let service = selectedService, let employee = selectedEmployee else { return }
        
        // Default duration: 1 hour (3600 seconds)
        let endTime = appointmentDate.addingTimeInterval(TimeInterval((service.durationMinutes > 0 ? service.durationMinutes : 60) * 60))
        
        // FIX: Changed "Confirmed" (String) to .confirmed (Enum)
        let newAppointment = Appointment(
            customerName: customerName,
            employeeName: employee.name,
            startTime: appointmentDate,
            endTime: endTime,
            price: service.price,
            status: .confirmed
        )
        
        // Link the service object to the appointment
        newAppointment.service = service
        
        modelContext.insert(newAppointment)
        
        do {
            try modelContext.save()
            SoundFeedbackManager.shared.playAddTaskSound()
            dismiss()
        } catch {
            print("Failed to save appointment: \(error.localizedDescription)")
        }
    }
}
