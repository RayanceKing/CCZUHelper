import Foundation
import XCTest
@testable import CCZUKit

private struct Reply {
    var status = 200
    var body = #"{"status":0,"message":[]}"#
    var delay: TimeInterval = 0
    var error: URLError?
}

private final class Server: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [URLRequest] = []
    let handler: (URLRequest, Int) -> Reply
    init(_ handler: @escaping (URLRequest, Int) -> Reply) { self.handler = handler }

    func reply(to request: URLRequest) -> Reply {
        lock.lock()
        requests.append(request)
        let count = requests.filter { $0.url?.path == request.url?.path }.count
        lock.unlock()
        return handler(request, count)
    }

    func count(_ path: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return requests.filter { $0.url?.path == path }.count
    }
}

private final class MockProtocol: URLProtocol, @unchecked Sendable {
    static var server: Server!
    private var work: DispatchWorkItem?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let reply = Self.server.reply(to: request)
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if let error = reply.error {
                client?.urlProtocol(self, didFailWithError: error)
                return
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
        self.work = work
        DispatchQueue.global().asyncAfter(deadline: .now() + reply.delay, execute: work)
    }
    override func stopLoading() { work?.cancel() }
}

@MainActor
final class TeachingSessionTests: XCTestCase {
    private let loginPath = CCZUConstants.Jwqywx.loginURL.path
    private let gradesPath = CCZUConstants.Jwqywx.gradesURL.path

    private func loginReply(_ generation: Int, delay: TimeInterval = 0) -> Reply {
        Reply(body: """
        {"status":0,"token":"test-\(generation)","message":[{"yhdm":"test-user","yhmc":"Test",
        "yhsf":"student","xq":"test-term","dqz":2,"zc":0,"gh":"","smscode":"","xb":"",
        "yhqx":"","yhid":"test-id"}]}
        """, delay: delay)
    }

    private func application(server: Server) -> JwqywxApplication {
        MockProtocol.server = server
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockProtocol.self]
        let client = DefaultHTTPClient(account: Account(username: "test-user", password: "test-password"), configuration: configuration)
        return JwqywxApplication(client: client)
    }

    func testExpiredSessionRelogsAndRetriesRequestOnce() async throws {
        let first = loginReply(1), second = loginReply(2)
        let server = Server { request, count in
            if request.url?.path == "/api/login" { return count == 1 ? first : second }
            return request.value(forHTTPHeaderField: "Authorization") == "Bearer test-1"
                ? Reply(status: 401, body: "Unauthorized") : Reply()
        }
        let app = application(server: server)
        try await app.ensureLoggedIn()
        let result = try await app.getGrades()
        XCTAssertTrue(result.message.isEmpty)
        XCTAssertEqual(server.count(loginPath), 2)
        XCTAssertEqual(server.count(gradesPath), 2)
    }

    func testConcurrentExpiredRequestsShareOneRelogin() async throws {
        let first = loginReply(1), second = loginReply(2, delay: 0.05)
        let server = Server { request, count in
            if request.url?.path == "/api/login" { return count == 1 ? first : second }
            return request.value(forHTTPHeaderField: "Authorization") == "Bearer test-1"
                ? Reply(status: 401, delay: 0.02) : Reply()
        }
        let app = application(server: server)
        try await app.ensureLoggedIn()
        async let a = app.getGrades()
        async let b = app.getGrades()
        async let c = app.getGrades()
        _ = try await (a, b, c)
        XCTAssertEqual(server.count(loginPath), 2)
        XCTAssertEqual(server.count(gradesPath), 6)
    }

    func testConcurrentInitialRequestsShareLogin() async throws {
        let login = loginReply(1, delay: 0.03)
        let server = Server { _, _ in login }
        let app = application(server: server)
        async let a: Void = app.ensureLoggedIn()
        async let b: Void = app.ensureLoggedIn()
        _ = try await (a, b)
        try await app.ensureLoggedIn()
        XCTAssertEqual(server.count(loginPath), 1)
    }

    func testLateRejectionSharesCompletedRefreshEvenWhenServerReissuesSameToken() async throws {
        let login = loginReply(1)
        let server = Server { request, count in
            if request.url?.path == "/api/login" { return login }
            if count <= 2 { return Reply(status: 401, delay: count == 1 ? 0.01 : 0.08) }
            return Reply()
        }
        let app = application(server: server)
        try await app.ensureLoggedIn()
        async let a = app.getGrades()
        async let b = app.getGrades()
        _ = try await (a, b)
        XCTAssertEqual(server.count(loginPath), 2)
        XCTAssertEqual(server.count(gradesPath), 4)
    }

    func testTermQueryAlsoRecoversAuthentication() async throws {
        let login = loginReply(1)
        let server = Server { request, count in
            if request.url?.path == "/api/login" { return login }
            return count == 1 ? Reply(status: 401) : Reply()
        }
        let app = application(server: server)
        _ = try await app.getTerms()
        XCTAssertEqual(server.count(loginPath), 2)
        XCTAssertEqual(server.count(CCZUConstants.Jwqywx.termsURL.path), 2)
    }

    func testRecoveryStillUnauthorizedSurfacesErrorWithoutLooping() async throws {
        let login = loginReply(1)
        let server = Server { request, _ in request.url?.path == "/api/login" ? login : Reply(status: 401) }
        let app = application(server: server)
        try await app.ensureLoggedIn()
        do { _ = try await app.getGrades(); XCTFail("Expected failure") }
        catch { XCTAssertEqual(error as? TeachingResponseError, .recoveryFailed) }
        XCTAssertEqual(server.count(loginPath), 2)
        XCTAssertEqual(server.count(gradesPath), 2)
    }

    func testFailedReloginDoesNotReplayTheOriginalRequest() async throws {
        let login = loginReply(1)
        let server = Server { request, count in
            if request.url?.path == "/api/login" { return count == 1 ? login : Reply(status: 503) }
            return Reply(status: 401)
        }
        let app = application(server: server)
        try await app.ensureLoggedIn()
        do { _ = try await app.getGrades(); XCTFail("Expected failure") }
        catch { XCTAssertEqual(error as? TeachingResponseError, .httpStatus(503)) }
        XCTAssertEqual(server.count(loginPath), 2)
        XCTAssertEqual(server.count(gradesPath), 1)
    }

    func testBusinessAndHTTPFailuresNeverTriggerRelogin() async throws {
        for failure in [Reply(status: 403), Reply(status: 500), Reply(body: #"{"status":1,"message":"尚未开放"}"#)] {
            let login = loginReply(1)
            let server = Server { request, _ in request.url?.path == "/api/login" ? login : failure }
            let app = application(server: server)
            try await app.ensureLoggedIn()
            do { _ = try await app.getGrades(); XCTFail("Expected failure") } catch { }
            XCTAssertEqual(server.count(loginPath), 1)
            XCTAssertEqual(server.count(gradesPath), 1)
        }
    }

    func testMalformedSuccessCannotReplaceCacheWithEmptyData() async throws {
        for body in [#"{"status":0,"message":"系统维护"}"#, #"{"status":0,"message":[{}]}"#,
                     #"{"status":0,"message":null}"#, #"{"status":0}"#, "<html>error</html>"] {
            let login = loginReply(1)
            let server = Server { request, _ in request.url?.path == "/api/login" ? login : Reply(body: body) }
            let app = application(server: server)
            try await app.ensureLoggedIn()
            var cachedNames = ["Existing grade"]
            do {
                cachedNames = try await app.getGrades().message.map(\.courseName)
                XCTFail("Malformed data must throw")
            } catch { }
            XCTAssertEqual(cachedNames, ["Existing grade"])
            XCTAssertEqual(server.count(loginPath), 1)
        }
    }

    func testExpiredSecondMutationDoesNotRepeatSuccessfulFirstMutation() async throws {
        let login = loginReply(1)
        let server = Server { request, count in
            if request.url?.path == "/api/login" { return login }
            if request.url?.path == "/api/second-write", count == 1 { return Reply(status: 401) }
            return Reply(body: #"{"status":0,"message":1}"#)
        }
        let app = application(server: server)
        try await app.ensureLoggedIn()
        for path in ["first-write", "second-write"] {
            _ = try await app.postAuthenticatedJSON(url: URL(string: "http://jwqywx.cczu.edu.cn:8180/api/\(path)")!, json: ["value": "test"])
        }
        XCTAssertEqual(server.count("/api/first-write"), 1)
        XCTAssertEqual(server.count("/api/second-write"), 2)
        XCTAssertEqual(server.count(loginPath), 2)
    }

    func testNetworkFailureDoesNotReplayMutation() async throws {
        let login = loginReply(1)
        let server = Server { request, _ in
            request.url?.path == "/api/login" ? login : Reply(error: URLError(.networkConnectionLost))
        }
        let app = application(server: server)
        try await app.ensureLoggedIn()
        do {
            _ = try await app.dropCourses(selectedIds: [1])
            XCTFail("Expected failure")
        } catch { }
        XCTAssertEqual(server.count(CCZUConstants.Jwqywx.dropCoursesURL.path), 1)
        XCTAssertEqual(server.count(loginPath), 1)
    }

    func testCancellationReachesURLSessionAndDoesNotRelogin() async throws {
        let login = loginReply(1)
        let server = Server { request, _ in request.url?.path == "/api/login" ? login : Reply(delay: 5) }
        let app = application(server: server)
        try await app.ensureLoggedIn()
        let task = Task { try await app.getGrades() }
        try await Task.sleep(nanoseconds: 30_000_000)
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(server.count(loginPath), 1)
    }

    func testBusinessAuthenticationErrorRecovers() async throws {
        let login = loginReply(1)
        let server = Server { request, count in
            if request.url?.path == "/api/login" { return login }
            return count == 1 ? Reply(body: #"{"status":-1,"message":"登录已过期，请重新登录"}"#) : Reply()
        }
        let app = application(server: server)
        try await app.ensureLoggedIn()
        _ = try await app.getGrades()
        XCTAssertEqual(server.count(loginPath), 2)
        XCTAssertEqual(server.count(gradesPath), 2)
    }

    func testLogin401IsInvalidCredentialsAndDoesNotLoop() async throws {
        let server = Server { _, _ in Reply(status: 401) }
        let app = application(server: server)
        do { try await app.ensureLoggedIn(); XCTFail("Expected failure") }
        catch { guard case CCZUError.invalidCredentials = error else { return XCTFail("Wrong error: \(error)") } }
        XCTAssertEqual(server.count(loginPath), 1)
    }
}
