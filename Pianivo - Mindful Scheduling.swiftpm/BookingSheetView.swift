import SwiftUI
import SwiftData

struct BookingSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Fetch all services to allow the user to choose what they are booking
    @Query(sort: \Service.name) private var availableServices: [Service]
    @Query private var existingAppointments: [Appointment]
    
    // MARK: - Form State
    @State private var studentName = ""
    @State private var phoneNumber = ""
    @State private var selectedDate: Date
    @State private var selectedStaff: String
    @State private var selectedService: Service? // New state
    
    private let instructors = ["Staff A", "Staff B", "Staff C"]
    
    init(initialDate: Date = Date(), initialStaff: String = "Staff A") {
        _selectedDate = State(initialValue: initialDate)
        _selectedStaff = State(initialValue: initialStaff)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Student Information") {
                    LabeledContent {
                        TextField("Full Name", text: $studentName)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Label("Student", systemImage: "person.fill")
                            .foregroundColor(.teal)
                    }
                    
                    LabeledContent {
                        TextField("Phone", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Label("Contact", systemImage: "phone.fill")
                            .foregroundColor(.teal)
                    }
                }
                
                Section("Session Details") {
                    Picker("Instructor", selection: $selectedStaff) {
                        ForEach(instructors, id: \.self) { Text($0).tag($0) }
                    }
                    
                    Picker("Service", selection: $selectedService) {
                        Text("Select Service").tag(nil as Service?)
                        ForEach(availableServices) { service in
                            Text(service.name).tag(service as Service?)
                        }
                    }
                    
                    DatePicker("Start Time", selection: $selectedDate)
                        .tint(.teal)
                }
                
                // Real-time Mindfulness Insight
                Section {
                    let conflict = checkForConflict()
                    
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: conflict ? "exclamationmark.triangle.fill" : "leaf.fill")
                            .foregroundColor(conflict ? .orange : .teal)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conflict ? "Burnout Risk" : "Mindful Space")
                                .font(.subheadline.bold())
                                .foregroundColor(conflict ? .orange : .teal)
                            
                            Text(conflict 
                                 ? "This instructor has another session within 15 minutes. Consider a gap for recovery." 
                                 : "This time allows a healthy decompression period between sessions.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(checkForConflict() ? Color.orange.opacity(0.1) : Color.teal.opacity(0.1))
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Book") { saveAppointment() }
                        .fontWeight(.bold)
                        .disabled(studentName.isEmpty || selectedService == nil)
                }
            }
        }
    }
    
    // MARK: - Logic
    
    private func checkForConflict() -> Bool {
        existingAppointments.contains { appt in
            // Match same instructor
            guard appt.employeeName == selectedStaff else { return false }
            
            // Check for a gap of less than 15 minutes
            let diff = abs(appt.startTime.timeIntervalSince(selectedDate))
            return diff < 900
        }
    }
    
    private func saveAppointment() {
        let isStressful = checkForConflict()
        
        // Use service duration if available, else default to 1 hour
        let duration = selectedService?.duration ?? 3600
        let price = selectedService?.price ?? 0.0
        
        let newAppt = Appointment(
            customerName: studentName,
            employeeName: selectedStaff,
            startTime: selectedDate,
            endTime: selectedDate.addingTimeInterval(duration),
            status: .pending, // FIXED: Using the Enum case instead of String
            isHighStress: isStressful,
            phoneNumber: phoneNumber,
            price: price,
            service: selectedService
        )
        
        modelContext.insert(newAppt)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save: \(error.localizedDescription)")
        }
    }
}
