import Foundation
import SwiftData

@Model
final class Service {
    @Attribute(.unique) var name: String
    var price: Double
    
    // This MUST match the 'service' variable name used in the Appointment model
    @Relationship(deleteRule: .nullify, inverse: \Appointment.service) 
    var appointments: [Appointment]? = []
    
    init(name: String, price: Double) {
        self.name = name
        self.price = price
    }
}
