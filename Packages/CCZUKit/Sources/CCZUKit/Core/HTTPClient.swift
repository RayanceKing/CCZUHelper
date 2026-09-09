import Foundation

/// HTTP客户端协议
public protocol HTTPClient: Sendable {
    var account: Account { get }
    var session: URLSession { get }
    var properties: PropertyStorage { get }

    func request(url: URL, method: String, headers: [String: String]?, body: Data?) async throws -> (Data, HTTPURLResponse)
}

/// 属性存储
public actor PropertyStorage {
    private var storage: [String: Property] = [:]

    public init() {}

    public func get(_ key: String) -> Property? {
        return storage[key]
    }

    public func set(_ key: String, value: Property) {
        storage[key] = value
    }

    public func remove(_ key: String) {
        storage.removeValue(forKey: key)
    }
}

/// 默认HTTP客户端实现
public final class DefaultHTTPClient: HTTPClient, @unchecked Sendable {
    public let account: Account
    public let session: URLSession
    public let properties: PropertyStorage

    public init(account: Account, configuration: URLSessionConfiguration = .default) {
        self.account = account

        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        configuration.httpCookieStorage = HTTPCookieStorage.shared

        self.session = URLSession(configuration: configuration)
        self.properties = PropertyStorage()
    }

    public convenience init(username: String, password: String) {
        self.init(account: Account(username: username, password: password))
    }

    public func request(
        url: URL,
        method: String = "GET",
        headers: [String: String]? = nil,
        body: Data? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body

        // 添加默认headers
        for (key, value) in CCZUConstants.defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // 添加自定义headers
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw CCZUError.invalidResponse }
            if url.host == CCZUConstants.Jwqywx.loginURL.host {
                try TeachingResponseValidator.validate(data: data, response: response)
            }
            return (data, response)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw CCZUError.networkError(error)
        }

    }

    // 发送 JSON（支持 Any 结构体, 以 JSONSerialization 组装）
    public func postJSON(url: URL, headers: [String: String] = [:], anyJSON: [String: Any]) async throws -> (Data, HTTPURLResponse) {
        var headers = headers
        headers["Content-Type"] = "application/json;charset=utf-8"
        let body = try JSONSerialization.data(withJSONObject: anyJSON, options: [])
        return try await post(url: url, headers: headers, body: body)
    }
}

extension HTTPClient {
    /// GET请求
    public func get(url: URL, headers: [String: String]? = nil) async throws -> (Data, HTTPURLResponse) {
        return try await request(url: url, method: "GET", headers: headers, body: nil)
    }

    /// POST请求
    public func post(url: URL, headers: [String: String]? = nil, body: Data? = nil) async throws -> (Data, HTTPURLResponse) {
        return try await request(url: url, method: "POST", headers: headers, body: body)
    }

    /// POST JSON请求
    public func postJSON<T: Encodable>(url: URL, headers: [String: String]? = nil, json: T) async throws -> (Data, HTTPURLResponse) {
        var allHeaders = headers ?? [:]
        allHeaders["Content-Type"] = "application/json"

        let jsonData = try JSONEncoder().encode(json)
        return try await post(url: url, headers: allHeaders, body: jsonData)
    }

    /// POST Form请求
    public func postForm(url: URL, headers: [String: String]? = nil, form: [String: String]) async throws -> (Data, HTTPURLResponse) {
        var allHeaders = headers ?? [:]
        allHeaders["Content-Type"] = "application/x-www-form-urlencoded"

        let formString = form.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        let formData = formString.data(using: .utf8)

        return try await post(url: url, headers: allHeaders, body: formData)
    }

    /// POST Form请求（formData 别名）
    public func postForm(url: URL, headers: [String: String]? = nil, formData: [String: String]) async throws -> (Data, HTTPURLResponse) {
        return try await postForm(url: url, headers: headers, form: formData)
    }
}
