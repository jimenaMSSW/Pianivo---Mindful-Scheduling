import SwiftUI
import SwiftData

struct EmployeeDashboard: View {
    @Environment(\.modelContext) private var modelContext
    
    // FETCH: All appointments for local filtering
    @Query(sort: \Appointment.startTime, order: .forward) 
    private var appointments: [Appointment]
    
    @AppStorage("businessName") private var bName = "Pianivo"
    @AppStorage("businessAddress") private var bAddress = "123 Music Lane, Miami, FL"
    
    @State private var selectedView = "Calendar"
    @State private var selectedDate = Date()
    
    let employeeName = "Staff A" 
    
    var myAppointments: [Appointment] {
        appointments.filter { $0.employeeName == employeeName }
    }
    
    var todayEarnings: Double {
        myAppointments
            .filter { Calendar.current.isDateInToday($0.startTime) && $0.isPaid }
            .reduce(0) { $0 + $1.price }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 15) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(bName).font(.title3.bold())
                        Text(bAddress).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 35, height: 35)
                        .foregroundColor(.teal)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
                
                HStack(spacing: 15) {
                    // FIXED: Using modern .formatted() to avoid "Extra argument in call"
                    SummaryBox(title: "TODAY'S EARNINGS", 
                               value: todayEarnings.formatted(.currency(code: "USD").precision(.fractionLength(0))), 
                               color: .teal)
                    SummaryBox(title: "TOTAL SESSIONS", 
                               value: "\(myAppointments.count)", 
                               color: .orange)
                }
            }
            .padding()
            
            Picker("View Mode", selection: $selectedView) {
                Text("Calendar").tag("Calendar")
                Text("List").tag("List")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 10)
            
            if selectedView == "Calendar" {
                ScrollView {
                    DatePicker("Schedule", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(.teal)
                        .padding()
                    
                    let dailyAppts = myAppointments.filter { Calendar.current.isDate($0.startTime, inSameDayAs: selectedDate) }
                    
                    if dailyAppts.isEmpty {
                        ContentUnavailableView("No Sessions", systemImage: "leaf", description: Text("Enjoy your recovery time!"))
                    } else {
                        VStack(spacing: 12) {
                            ForEach(dailyAppts) { appt in
                                AppointmentCard(appt: appt, showEmployee: false)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            } else {
                List {
                    ForEach(myAppointments) { appt in
                        AppointmentCard(appt: appt, showEmployee: false)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .leading) {
                                Button {
                                    appt.isPaid.toggle()
                                } label: {
                                    Label(appt.isPaid ? "Unpaid" : "Paid", systemImage: "dollarsign.circle.fill")
                                }
                                .tint(.teal)
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("My Flow")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#Preview {
    let schema = Schema([Appointment.self, Service.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    // Create mock data for the preview
    let mock = Appointment(
        customerName: "Alex", 
        employeeName: "Staff A", 
        startTime: .now, 
        endTime: .now.addingTimeInterval(3600),
        price: 75.0,
        isPaid: true
    )
    container.mainContext.insert(mock)
    
    return NavigationStack {
        EmployeeDashboard()
    }
    .modelContainer(container)
}
