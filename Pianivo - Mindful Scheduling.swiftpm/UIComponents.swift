import SwiftUI

struct AppointmentCard: View {
    let appt: Appointment
    var showEmployee: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(appt.customerName).font(.headline)
                Text(appt.startTime.formatted(date: .omitted, time: .shortened))
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(appt.status.displayTitle)
                .padding(6)
                .background(Color.teal.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

struct SummaryBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption2.bold()).foregroundColor(.secondary)
            Text(value).font(.title2.bold()).foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
    }
}
