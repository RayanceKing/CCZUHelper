import Foundation

/// SSO登录连接类型
public enum SSOLoginConnectType: String, Sendable {
    case webvpn = "WEBVPN"
    case common = "COMMON"
}

/// SSO统一登录协议
public protocol SSOLogin {
    /// SSO统一登录
    func ssoUniversalLogin() async throws -> ElinkLoginInfo?

    /// SSO服务登录
    func ssoServiceLogin(service: String) async throws -> (Data, HTTPURLResponse)
}

extension DefaultHTTPClient: SSOLogin {

    /// SSO统一登录
    public func ssoUniversalLogin() async throws -> ElinkLoginInfo? {
        let url = CCZUConstants.SSO.loginURL

        let (_, response) = try await get(url: url)

        // 检查状态码判断是否需要WebVPN
        if response.statusCode == 302 {
            // WebVPN模式
            return try await handleWebVPNLogin(from: response)
        } else if response.statusCode == 200 {
            // 普通模式
            _ = try await ssoServiceLogin(service: "")
            await properties.set("SSOLoginConnectType", value: .string(SSOLoginConnectType.common.rawValue))
            return nil
        }

        throw CCZUError.loginFailed("Unexpected status code: \(response.statusCode)")
    }

    /// 处理WebVPN登录
    private func handleWebVPNLogin(from response: HTTPURLResponse) async throws -> ElinkLoginInfo? {
        guard let location = response.value(forHTTPHeaderField: "Location"),
              let redirectURL = URL(string: location) else {
            throw CCZUError.ssoLoginFailed("缺少重定向地址")
        }

        // 递归处理重定向
        let (pageData, _) = try await recursionRedirectHandle(url: redirectURL)

        guard let html = String(data: pageData, encoding: .utf8) else {
            throw CCZUError.invalidResponse
        }

        // 解析隐藏字段
        var form = parseHiddenValues(from: html)
        form["username"] = account.username
        form["password"] = Data(account.password.utf8).base64EncodedString()

        // 提交登录表单
        let (_, loginResponse) = try await postForm(url: redirectURL, form: form)

        // 检查登录响应是否返回了错误页面（没有Location表示登录失败）
        guard let loginLocation = loginResponse.value(forHTTPHeaderField: "Location"),
              let loginRedirectURL = URL(string: loginLocation) else {
            throw CCZUError.invalidCredentials
        }

        var headers = CCZUConstants.defaultHeaders
        headers["Referer"] = CCZUConstants.rootVPNURL
        let _ = try await get(url: loginRedirectURL, headers: headers)

        // 从Cookie中提取clientInfo
        if let cookies = HTTPCookieStorage.shared.cookies(for: loginRedirectURL),
           let clientInfoCookie = cookies.first(where: { $0.name == "clientInfo" }),
           let decodedData = Data(base64Encoded: clientInfoCookie.value),
           let jsonString = String(data: decodedData, encoding: .utf8) {

            let decoder = JSONDecoder()
            let loginInfo = try decoder.decode(ElinkLoginInfo.self, from: jsonString.data(using: .utf8)!)

            await properties.set("SSOLoginConnectType", value: .string(SSOLoginConnectType.webvpn.rawValue))
            return loginInfo
        }

        throw CCZUError.ssoLoginFailed("无法提取登录信息")
    }

    /// SSO服务登录
    public func ssoServiceLogin(service: String) async throws -> (Data, HTTPURLResponse) {
        let url = CCZUConstants.SSO.serviceLoginURL(service: service)

        let (data, response) = try await get(url: url)

        // 已经登录,直接重定向
        if response.statusCode == 302 {
            if let location = response.value(forHTTPHeaderField: "Location"),
               let redirectURL = URL(string: location) {
                return try await recursionRedirectHandle(url: redirectURL)
            }
        }

        // 需要登录
        guard let html = String(data: data, encoding: .utf8) else {
            throw CCZUError.invalidResponse
        }

        var loginParam = parseHiddenValues(from: html)
        loginParam["username"] = account.username
        loginParam["password"] = Data(account.password.utf8).base64EncodedString()

        let (_, loginResponse) = try await postForm(url: url, form: loginParam)

        // 登录成功可能返回302重定向，也可能返回200（已在当前会话登录）
        if loginResponse.statusCode == 302,
           let location = loginResponse.value(forHTTPHeaderField: "Location"),
           let redirectURL = URL(string: location) {
            return try await recursionRedirectHandle(url: redirectURL)
        }

        if loginResponse.statusCode == 200 {
            // 检查响应内容中是否包含登录失败的提示（账号密码错误）
            if let responseHtml = String(data: data, encoding: .utf8),
               responseHtml.contains("用户名不存在") || responseHtml.contains("密码错误") ||
               responseHtml.contains("用户名或密码错误") {
                throw CCZUError.invalidCredentials
            }
            // 视为登录成功，返回当前页面响应
            return (Data(), loginResponse)
        }

        throw CCZUError.ssoLoginFailed("SSO服务登录失败")
    }

    /// 递归处理重定向
    private func recursionRedirectHandle(url: URL, depth: Int = 0) async throws -> (Data, HTTPURLResponse) {
        guard depth < 10 else {
            throw CCZUError.unknown("Too many redirects")
        }

        let (data, response) = try await get(url: url)

        if response.statusCode == 302,
           let location = response.value(forHTTPHeaderField: "Location") {
            let nextURL: URL
            if location.hasPrefix("http") {
                guard let url = URL(string: location) else {
                    throw CCZUError.unknown("Invalid redirect URL")
                }
                nextURL = url
            } else {
                guard let url = URL(string: location, relativeTo: url) else {
                    throw CCZUError.unknown("Invalid relative redirect URL")
                }
                nextURL = url
            }
            return try await recursionRedirectHandle(url: nextURL, depth: depth + 1)
        }

        return (data, response)
    }

    /// 解析HTML中的隐藏字段
    private func parseHiddenValues(from html: String) -> [String: String] {
        var result: [String: String] = [:]

        // 简单的正则解析 input[type="hidden"]
        let pattern = #"<input[^>]*type\s*=\s*["']hidden["'][^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return result
        }

        let nsString = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            let matchString = nsString.substring(with: match.range)

            // 提取name和value
            if let name = extractAttribute("name", from: matchString),
               let value = extractAttribute("value", from: matchString) {
                result[name] = value
            }
        }

        return result
    }

    /// 提取HTML属性值
    private func extractAttribute(_ attribute: String, from html: String) -> String? {
        let pattern = #"\#(attribute)\s*=\s*["']([^"']*)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let nsString = html as NSString
        if let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: nsString.length)) {
            if match.numberOfRanges > 1 {
                return nsString.substring(with: match.range(at: 1))
            }
        }

        return nil
    }
}
