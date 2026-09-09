import Foundation

extension JwqywxApplication {
    private func authenticatedRequest(
        _ operation: ([String: String]) async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
        try await ensureLoggedIn()
        let rejectedGeneration = authenticationGeneration
        do {
            return try await operation(customHeaders)
        } catch TeachingResponseError.authenticationExpired {
            try Task.checkCancellation()
            // Another request may already have replaced the rejected session.
            if authenticationGeneration == rejectedGeneration { _ = try await login() }
            try Task.checkCancellation()
            do {
                return try await operation(customHeaders)
            } catch TeachingResponseError.authenticationExpired {
                throw TeachingResponseError.recoveryFailed
            }
        }
    }

    func postAuthenticatedJSON<T: Encodable>(url: URL, json: T) async throws -> (Data, HTTPURLResponse) {
        try await authenticatedRequest { headers in
            try await client.postJSON(url: url, headers: headers, json: json)
        }
    }

    func getAuthenticated(url: URL) async throws -> (Data, HTTPURLResponse) {
        try await authenticatedRequest { headers in
            try await client.get(url: url, headers: headers)
        }
    }

    func postAuthenticatedJSON(url: URL, anyJSON: [String: Any]) async throws -> (Data, HTTPURLResponse) {
        try await authenticatedRequest { headers in
            try await client.postJSON(url: url, headers: headers, anyJSON: anyJSON)
        }
    }
}
