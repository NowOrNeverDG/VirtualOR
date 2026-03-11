import Foundation

enum APIConfig {
    #if DEBUG
    static let baseURL = "https://api-dev.example.com/v1"
    #else
    static let baseURL = "https://api.example.com/v1"
    #endif

    static let timeoutInterval: TimeInterval = 30
}
