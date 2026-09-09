// The Swift Programming Language
// https://docs.swift.org/swift-book

/// CCZUKit - 常州大学API客户端库
///
/// 本库提供了访问常州大学各种服务的接口,包括:
/// - SSO统一登录
/// - 教务企业微信应用（成绩、课表、考试安排等）
/// - 学生基本信息查询
/// - 电费实时查询
/// - 课程评价
/// - 课程选修（选课、通识课程等）
/// - 日历解析
///
/// ## 主要功能
///
/// ### 初始化客户端
/// ```swift
/// import CCZUKit
///
/// // 使用学号和密码创建客户端
/// let client = try DefaultHTTPClient(username: "2400130204", password: "your_password")
/// ```
///
/// ### SSO登录
/// ```swift
/// // 进行SSO统一认证登录
/// let loginInfo = try await SSOLogin.ssoUniversalLogin(client: client)
/// ```
///
/// ### 教务查询
/// ```swift
/// let app = JwqywxApplication(client: client)
/// try await app.login()
///
/// // 获取本学期成绩
/// let grades = try await app.getGrades()
///
/// // 获取当前学期课表
/// let schedule = try await app.getCurrentClassSchedule()
///
/// // 获取本学期考试安排
/// let exams = try await app.getExamArrangements()
///
/// // 获取学生基本信息
/// let basicInfo = try await app.getStudentBasicInfo()
/// ```
///
/// ### 电费查询
/// ```swift
/// // 查询电费情况
/// let areas = try await app.getElectricityAreas()
/// let buildings = try await app.getBuildings(area: areas[0])
/// let electricity = try await app.queryElectricity(area: areas[0], building: buildings[0], roomId: "roomId")
/// ```
///
/// ### 课程评价
/// ```swift
/// // 获取可评价的课程
/// let courses = try await app.getEvaluatableClasses()
///
/// // 评价教师
/// try await app.submitTeacherEvaluation(...)
/// ```
///
/// ### 课程选修
/// ```swift
/// // 获取可选课程
/// let courses = try await app.getSelectableCourses()
///
/// // 选课
/// try await app.selectCourses(courseIds: [...])
///
/// // 退课
/// try await app.dropCourses(registrationIds: [...])
/// ```
///
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public struct CCZUKit {
    private init() {}
}
