import Foundation

public enum TeachingResponseError: LocalizedError, Equatable {
    case authenticationExpired
    case recoveryFailed
    case httpStatus(Int)
    case rejected(status: Int, reason: String? = nil)
    case malformedResponse

    public var errorDescription: String? {
        switch self {
        case .authenticationExpired: return "教务登录已失效，请重新登录后重试。"
        case .recoveryFailed: return "自动重新登录后，教务系统仍未接受登录状态。请稍后重试或重新登录。"
        case .httpStatus(let status): return "教务系统请求失败（HTTP \(status)），请稍后重试。"
        case .rejected(let status, let reason):
            return reason.map { "教务系统未能完成请求：\($0)（错误码 \(status)）" }
                ?? "教务系统未能完成请求（错误码 \(status)），请稍后重试。"
        case .malformedResponse: return "教务系统返回的数据格式异常，本次更新未完成。"
        }
    }
}

enum TeachingResponseValidator {
    static func validate(data: Data, response: HTTPURLResponse) throws {
        let isLogin = response.url?.path == CCZUConstants.Jwqywx.loginURL.path
        if response.statusCode == 401 {
            if isLogin { throw CCZUError.invalidCredentials }
            throw TeachingResponseError.authenticationExpired
        }
        if response.statusCode >= 500 {
            throw TeachingResponseError.httpStatus(response.statusCode)
        }
        let object = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        // Only explicit authentication failures trigger replay. A generic 403 or server
        // failure can mean permissions, maintenance or a failed write, not an expired token.
        let message = (object["message"] as? String ?? object["msg"] as? String ?? "").lowercased()
        let authMessages = ["未登录", "未登陆", "请先登录", "请先登陆", "登录失效", "登录已失效",
                            "登录过期", "登录已过期", "登录超时", "登陆失效", "登陆过期",
                            "重新登录", "重新登陆", "token expired", "token is expired",
                            "invalid token", "token无效", "token失效", "token过期", "not logged in",
                            "unauthorized", "jwt expired"]
        if isLogin, ["密码错误", "密码不正确", "用户名不存在", "账号或密码"].contains(where: message.contains) {
            throw CCZUError.invalidCredentials
        }
        if authMessages.contains(where: message.contains) || (object["status"] as? Int) == 401 || (object["code"] as? Int) == 401 {
            throw TeachingResponseError.authenticationExpired
        }
        guard (200..<300).contains(response.statusCode) else {
            throw TeachingResponseError.httpStatus(response.statusCode)
        }
        guard let status = object["status"] as? Int else { throw TeachingResponseError.malformedResponse }
        guard status == 0 else {
            let reason = (object["message"] as? String ?? object["msg"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw TeachingResponseError.rejected(status: status, reason: reason.flatMap { $0.isEmpty ? nil : String($0.prefix(200)) })
        }
    }
}
