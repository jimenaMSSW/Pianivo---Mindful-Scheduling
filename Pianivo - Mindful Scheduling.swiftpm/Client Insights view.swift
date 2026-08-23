import SwiftUI
import SwiftData

struct ClientInsightsView: View {
    @Query private var allAppointments: [Appointment]
    let studentName: String
    
    init(studentName: String) {
        self.studentName = studentName
        let filterName = studentName
        let predicate = #Predicate<Appointment> { appointment in
            appointment.customerName == filterName
        }
        _allAppointments = Query(filter: predicate, sort: \Appointment.startTime)
    }
    
    // MARK: - Debugged Analytics
    private var wellnessScore: Double {
        let highStress = allAppointments.filter { $0.isHighStress }.count
        if allAppointments.isEmpty { return 1.0 }
        return max(1.0 - (Double(highStress) * 0.15), 0.1)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Score Circle
                    ZStack {
                        Circle().stroke(Color.teal.opacity(0.1), lineWidth: 15)
                        Circle()
                            .trim(from: 0, to: wellnessScore)
                            .stroke(Color.teal, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(wellnessScore * 100))%")
                            .font(.system(.title, design: .rounded).bold())
                    }
                    .frame(width: 140, height: 140)
                    .padding()
                    
                    // Stats Area
                    VStack(spacing: 12) {
                        InsightRow(title: "Sessions", value: "\(allAppointments.count)", icon: "leaf.fill")
                        InsightRow(title: "Stress Alerts", value: "\(allAppointments.filter { $0.isHighStress }.count)", icon: "exclamationmark.shield")
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
                }
                .padding()
            }
            .navigationTitle("Insights")
        }
    }
}

// THIS MUST BE OUTSIDE THE MAIN STRUCT TO BE FOUND BY THE COMPILER
struct InsightRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text(value).bold().foregroundColor(.teal)
        }
    }
}
#Preview {
    let schema = Schema([Appointment.self, Service.self, User.self])
    let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    return ClientInsightsView(studentName: "Alex")
        .modelContainer(container)
}
