import Foundation
import CCZUKit

enum TeachingErrorPresentation {
    static func requiresLogin(_ message: String) -> Bool {
        let message = message.lowercased()
        return ["登录", "登陆", "密码", "登入", "密碼", "login", "log in", "sign in", "ログイン", "로그인"]
            .contains(where: message.contains)
    }

    static func message(for error: Error) -> String? {
        if error is CancellationError { return nil }
        if let urlError = error as? URLError {
            if urlError.code == .cancelled { return nil }
            if urlError.code == .timedOut { return "error.timeout".localized }
            return "error.network_failed".localized
        }
        if let sdkError = error as? CCZUError {
            switch sdkError {
            case .networkError(let underlying): return message(for: underlying)
            case .decodingError, .invalidResponse: return "teaching.error.invalid_response".localized
            default: return sdkError.localizedDescription
            }
        }
        if error is DecodingError { return "teaching.error.invalid_response".localized }
        return error.localizedDescription
    }
}
