import SwiftUI

struct BookingSheetView: View {
    var initialClientName: String? = nil

    var body: some View {
        HostedBookingView(
            title: "Book Appointment",
            url: APIConfig.bookingURL
        )
    }
}
