import Foundation

enum ApiError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(Int)
    case decodingError(Error)
    case rawResponse(String)
    case maxRetriesExceeded(attempts: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .rawResponse(let response):
            return "Raw response: \(response)"
        case .maxRetriesExceeded(let attempts):
            return "Connection failed after \(attempts) attempts"
        }
    }
}

class ApiService {
    private let urlString = "https://www.minimax.io/v1/api/openplatform/coding_plan/remains"
    private let maxRetries = 5
    private let retryDelay: TimeInterval = 15

    var onRetry: ((Int, Int) -> Void)? // Called on each retry: (currentAttempt, maxRetries)

    func fetchUsage(apiKey: String) async throws -> MiniMaxUsage {
        guard let url = URL(string: urlString) else {
            throw ApiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        var lastError: Error = ApiError.invalidResponse

        for attempt in 1...maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ApiError.invalidResponse
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw ApiError.serverError(httpResponse.statusCode)
                }

                do {
                    let decoder = JSONDecoder()
                    let usage = try decoder.decode(MiniMaxUsage.self, from: data)
                    return usage
                } catch {
                    if let rawString = String(data: data, encoding: .utf8) {
                        print("Raw response: \(rawString)")
                        throw ApiError.rawResponse(rawString.prefix(500).description)
                    }
                    throw ApiError.decodingError(error)
                }
            } catch let error as ApiError {
                lastError = error
            } catch {
                lastError = ApiError.networkError(error)
            }

            // Retry if not last attempt
            if attempt < maxRetries {
                onRetry?(attempt, maxRetries)
                print("Attempt \(attempt) failed, retrying in \(retryDelay)s... (\(attempt)/\(maxRetries))")
                try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
        }

        throw ApiError.maxRetriesExceeded(attempts: maxRetries)
    }
}
