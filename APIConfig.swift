import Foundation

enum APIConfig {
    static let baseURL = URL(string: "https://pianivo-mindful-scheduling.onrender.com")!
    static let bookingURL = URL(string: "book/", relativeTo: baseURL)!.absoluteURL
}
