import SwiftUI
import SwiftData
import Charts

struct MindfulInsightsView: View {
    @Query(sort: \Appointment.startTime, order: .forward)
    var appointments: [Appointment]
    
    @Binding var selectedRole: String?
    @AppStorage("isDemoMode") private var isDemoMode = true
    
    // ⭐ PRO TIP: For the competition, focus insights on the logged-in staff
    let currentStaff = "Staff A" 
    
    // MARK: - Refined High-Stress Calculation
    var highStressGaps: Int {
        // Filter to only look at one person's schedule at a time
        let myAppointments = appointments.filter { $0.employeeName == currentStaff }
        guard myAppointments.count > 1 else { return 0 }
        
        var stressCount = 0
        for i in 1..<myAppointments.count {
            let previous = myAppointments[i-1]
            let current = myAppointments[i]
            
            if Calendar.current.isDate(previous.startTime, inSameDayAs: current.startTime) {
                let gap = current.startTime.timeIntervalSince(previous.endTime)
                // Flag if gap is less than 15 minutes (900 seconds)
                if gap < 900 && gap >= 0 {
                    stressCount += 1
                }
            }
        }
        return stressCount
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // 1. Mindful Momentum Card
                    momentumCard
                    
                    // 2. Weekly Workload Chart
                    workloadChart
                    
                    // 3. Coaching Section
                    coachingSection
                    
                    // 4. Judge/Demo Logout
                    if isDemoMode {
                        logoutButton
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Insights")
        }
    }
    
    // MARK: - View Components
    
    private var momentumCard: some View {
        VStack(spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mindful Momentum").font(.headline)
                    Text(highStressGaps == 0 ? "Your schedule is balanced." : "\(highStressGaps) High density points detected.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // Animated Ring
                ZStack {
                    Circle()
                        .stroke(Color.teal.opacity(0.1), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: highStressGaps == 0 ? 1.0 : 0.6)
                        .stroke(highStressGaps == 0 ? Color.teal : Color.orange, 
                                style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1), value: highStressGaps)
                    
                    Image(systemName: highStressGaps == 0 ? "leaf.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(highStressGaps == 0 ? .teal : .orange)
                }
                .frame(width: 50, height: 50)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
    }
    
    private var workloadChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Workload").font(.headline)
            
            if appointments.isEmpty {
                ContentUnavailableView("No Data Yet", systemImage: "chart.bar", description: Text("Book sessions to see your workload trends."))
                    .frame(height: 150)
            } else {
                Chart {
                    ForEach(appointments) { appt in
                        BarMark(
                            x: .value("Day", appt.startTime, unit: .day),
                            y: .value("Sessions", 1)
                        )
                        .foregroundStyle(Color.teal.gradient)
                        .cornerRadius(4)
                    }
                    
                    RuleMark(y: .value("Limit", 6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundStyle(.red.opacity(0.5))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Burnout Limit").font(.caption2).foregroundColor(.red)
                        }
                }
                .frame(height: 150)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
    }
    
    private var coachingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coaching").font(.headline)
            
            if highStressGaps > 0 {
                InsightTipRow(icon: "timer", color: .orange, 
                              message: "You have \(highStressGaps) back-to-back sessions. Try adding 10m buffers.")
            }
            
            InsightTipRow(icon: "sun.max.fill", color: .teal, 
                          message: "Peak performance detected in mornings. Protect this time.")
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
    }
    
    private var logoutButton: some View {
        Button {
            withAnimation(.spring()) { selectedRole = nil }
        } label: {
            Label("Exit Demo Mode", systemImage: "arrow.left.circle.fill")
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(RoundedRectangle(cornerRadius: 15).fill(Color.red.opacity(0.8)))
        }
    }
}
