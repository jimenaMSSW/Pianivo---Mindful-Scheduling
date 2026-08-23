import Foundation
import SwiftData

@Model
final class Appointment {
    @Attribute(.unique) var id: UUID = UUID()
    var customerName: String
    var employeeName: String
    var startTime: Date
    var endTime: Date
    var notes: String
    var isHighStress: Bool
    var phoneNumber: String
    var price: Double
    var isPaid: Bool
    var statusValue: String
    
    // Explicitly define the relationship
    // Ensure the 'inverse' matches the property name in the Service model
    @Relationship(inverse: \Service.appointments)
    var service: Service? 
    
    init(
        customerName: String,
        employeeName: String,
        startTime: Date,
        endTime: Date,
        status: AppointmentStatus = .pending,
        notes: String = "",
        isHighStress: Bool = false,
        phoneNumber: String = "",
        price: Double = 0.0,
        isPaid: Bool = false,
        service: Service? = nil
    ) {
        self.customerName = customerName
        self.employeeName = employeeName
        self.startTime = startTime
        self.endTime = endTime
        self.statusValue = status.rawValue
        self.notes = notes
        self.isHighStress = isHighStress
        self.phoneNumber = phoneNumber
        self.price = price
        self.isPaid = isPaid
        self.service = service
    }
    
    var status: AppointmentStatus {
        get { AppointmentStatus(rawValue: statusValue) ?? .pending }
        set { statusValue = newValue.rawValue }
    }
}ß
