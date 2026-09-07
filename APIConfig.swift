import Foundation

enum APIConfig {
    static let baseURL = URL(string: "https://pianivo-mindful-scheduling.onrender.com")!
    static let bookingURL = URL(string: "book/", relativeTo: baseURL)!.absoluteURL

    static func bookingURL(
        serviceName: String,
        price: Double,
        businessCode: String = "",
        businessName: String = "",
        requiresDeposit: Bool = false,
        depositPercentage: Double = 0
    ) -> URL {
        var components = URLComponents(url: bookingURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "service", value: serviceName),
            URLQueryItem(name: "price", value: String(format: "%.2f", price)),
            URLQueryItem(name: "business_code", value: businessCode),
            URLQueryItem(name: "business_name", value: businessName),
            URLQueryItem(name: "deposit_enabled", value: requiresDeposit ? "1" : "0"),
            URLQueryItem(name: "deposit_percentage", value: String(format: "%.2f", depositPercentage))
        ]
        return components.url ?? bookingURL
    }
}
