import SwiftUI
import SwiftData

struct OwnerDashboard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Appointment.startTime, order: .forward) var appointments: [Appointment]
    @Query(sort: \Service.name) var services: [Service]
    
    @AppStorage("businessName") private var bName = "Pianivo Studio"
    @AppStorage("businessAddress") private var bAddress = "123 Music Lane, Miami, FL"
    
    @State private var selectedView = "Calendar"
    @State private var newCustName = ""
    @State private var selectedEmployee = "Staff A"
    @State private var selectedService: Service?
    @State private var newStartTime = Date()
    
    let staffMembers = ["Staff A", "Staff B", "Staff C"]
    
    var collectedRevenue: Double {
        appointments.filter { $0.isPaid }.reduce(0) { $0 + $1.price }
    }
    
    var pendingRevenue: Double {
        appointments.filter { !$0.isPaid }.reduce(0) { $0 + $1.price }
    }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    businessHeader
                    revenueTrio
                    
                    Picker("View Mode", selection: $selectedView) {
                        Text("Calendar").tag("Calendar")
                        Text("List").tag("List")
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if selectedView == "Calendar" {
                        bookingSection
                        datePickerSection
                    } else {
                        appointmentListSection
                    }
                    
                    Text("Business ID: \(bName.filter { !$0.isWhitespace }.uppercased())-2026")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.bottom)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Management")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Subviews
    
    private var businessHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading) {
                    Text(bName).font(.headline)
                    Text(bAddress).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "crown.fill").foregroundColor(.teal).font(.title3)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
        .padding(.horizontal)
    }
    
    private var revenueTrio: some View {
        HStack(spacing: 12) {
            revenueCard(title: "Collected", amount: collectedRevenue, color: .teal)
            revenueCard(title: "Pending", amount: pendingRevenue, color: .orange)
        }
        .padding(.horizontal)
    }
    
    private func revenueCard(title: String, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2.bold()).foregroundColor(.secondary)
            Text("$\(amount, specifier: "%.0f")").font(.title2.bold()).foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
    }
    
    private var bookingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Book").font(.headline)
            
            TextField("Customer Name", text: $newCustName)
                .textFieldStyle(.plain)
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
            
            HStack {
                Menu {
                    Picker("Service", selection: $selectedService) {
                        Text("None").tag(nil as Service?)
                        ForEach(services) { service in
                            Text(service.name).tag(service as Service?)
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedService?.name ?? "Select Service")
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.caption)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
                }
                
                Menu {
                    Picker("Staff", selection: $selectedEmployee) {
                        ForEach(staffMembers, id: \.self) { Text($0).tag($0) }
                    }
                } label: {
                    HStack {
                        Text(selectedEmployee)
                        Spacer()
                        Image(systemName: "person.badge.plus").font(.caption)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
            
            Button(action: addAppointment) {
                Text("Confirm Booking")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(newCustName.isEmpty ? Color.gray.opacity(0.3) : Color.teal)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(newCustName.isEmpty)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
        .padding(.horizontal)
    }
    
    private var datePickerSection: some View {
        VStack {
            DatePicker("Date", selection: $newStartTime, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
                .tint(.teal)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
        .padding(.horizontal)
    }
    
    private var appointmentListSection: some View {
        VStack(spacing: 12) {
            if appointments.isEmpty {
                ContentUnavailableView("No Sessions", systemImage: "calendar.badge.exclamationmark")
                    .padding(.top, 40)
            } else {
                ForEach(appointments) { appt in
                    AppointmentRow(appointment: appt)
                        .swipeActions(edge: .leading) {
                            Button {
                                appt.isPaid.toggle()
                                hapticFeedback(.medium)
                            } label: {
                                Label(appt.isPaid ? "Unpaid" : "Paid", systemImage: "dollarsign.circle")
                            }
                            .tint(.teal)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelContext.delete(appt)
                                hapticFeedback(.rigid)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Logic Fixes
    
    private func addAppointment() {
        let price = selectedService?.price ?? 50.0
        let duration = selectedService?.duration ?? 3600
        
        // Updated to match your refined Appointment model
        let newAppt = Appointment(
            customerName: newCustName,
            employeeName: selectedEmployee,
            startTime: newStartTime,
            endTime: newStartTime.addingTimeInterval(duration),
            status: .confirmed,
            price: price,
            service: selectedService
        )
        
        withAnimation(.spring()) {
            modelContext.insert(newAppt)
            newCustName = ""
            hapticFeedback(.success)
        }
    }
    
    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    private func hapticFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

// MARK: - MISSING COMPONENT FIX
struct AppointmentRow: View {
    let appointment: Appointment
    
    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 4) {
                Text(appointment.customerName)
                    .font(.headline)
                
                HStack {
                    Text(appointment.startTime, style: .time)
                    Text("•")
                    Text(appointment.service?.name ?? "General")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("$\(appointment.price, specifier: "%.0f")")
                    .bold()
                Text(appointment.status.rawValue.uppercased())
                    .font(.system(size: 8, weight: .black))
                    .padding(4)
                    .background(appointment.isPaid ? Color.teal.opacity(0.2) : Color.orange.opacity(0.2))
                    .foregroundColor(appointment.isPaid ? .teal : .orange)
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 15).fill(Color(.systemBackground)))
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Appointment.self, Service.self, User.self, configurations: config)
    return OwnerDashboard().modelContainer(container)
}
