import Foundation

enum APIConfig {
    static let baseURL = URL(string: "https://pianivo-mindful-scheduling.onrender.com")!
    static let bookingURL = URL(string: "book/", relativeTo: baseURL)!.absoluteURL
    static let ownerSubscriptionCheckoutURL = URL(string: "subscriptions/owner/checkout/", relativeTo: baseURL)!.absoluteURL
    static let ownerSubscriptionStatusURL = URL(string: "subscriptions/owner/status/", relativeTo: baseURL)!.absoluteURL

    static func bookingURL(serviceName: String, price: Double) -> URL {
        var components = URLComponents(url: bookingURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "service", value: serviceName),
            URLQueryItem(name: "price", value: String(format: "%.2f", price))
        ]
        return components.url ?? bookingURL
    }
}
