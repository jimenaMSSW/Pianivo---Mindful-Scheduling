import SwiftUI

// MARK: - Appointment Card
struct AppointmentCard: View {
    let appt: Appointment
    var showEmployee: Bool = true
    
    var body: some View {
        HStack(spacing: 16) {
            // 1. Service Color Strip
            // FIX: Ensure the capsule takes up the full height of the text content
            Capsule()
                .fill(appt.service?.themeColor ?? .teal)
                .frame(width: 4)
                .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(appt.customerName)
                    .font(.headline)
                    .lineLimit(1) // Prevent name from pushing layout down
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(appt.startTime.formatted(date: .omitted, time: .shortened))
                    Text("•")
                    Text(appt.service?.name ?? "Appointment")
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                if showEmployee {
                    Label(appt.employeeName, systemImage: "person.circle")
                        .font(.caption2)
                        .foregroundColor(.teal)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // 2. Status & Stress Badges
            VStack(alignment: .trailing, spacing: 6) {
                // FIX: Use a ZStack or fixed height here to prevent the card
                // from changing height when the stress icon is present.
                if appt.isHighStress {
                    Image(systemName: "bolt.shield.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Placeholder to maintain alignment height
                    Color.clear.frame(height: 12)
                }
                
                Text(appt.status == .completed ? "PAID" : "PENDING")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(appt.status == .completed ? Color.teal.opacity(0.1) : Color.orange.opacity(0.1))
                    .foregroundColor(appt.status == .completed ? .teal : .orange)
                    .clipShape(Capsule())
            }
            .frame(minWidth: 60) // Ensure the badge area has consistent width
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(appt.isHighStress ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle()) // Makes the whole card tappable, not just the text
    }
}

// MARK: - Summary Card
struct SummaryBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundColor(color)
                    .padding(8)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .lineLimit(1)
            }
            
            Text(value)
                .font(.system(.title2, design: .rounded).bold())
                .foregroundColor(.primary)
                .minimumScaleFactor(0.7) // FIX: Prevents "..." on small screens
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Mini Status Circle
struct MiniStatusCircle: View {
    let progress: Double // 0.0 to 1.0
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.1), lineWidth: 4)
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(), value: progress) // Adds smooth filling effect
        }
        .frame(width: 40, height: 40)
    }
}
