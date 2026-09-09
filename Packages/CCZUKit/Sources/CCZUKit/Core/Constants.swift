import Foundation

/// API常量
public enum CCZUConstants {
    /// 统一身份认证登录入口（字符串形式，兼容旧代码）
    public static let rootSSOLogin = "http://sso.cczu.edu.cn/sso/login"
    /// WebVPN 根地址
    public static let rootVPNURL = "https://zmvpn.cczu.edu.cn"
    /// 教务企业微信应用根地址
    public static let wechatAppAPI = "http://jwqywx.cczu.edu.cn"

    public static let defaultHeaders: [String: String] = [
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept": "application/json, text/plain, */*",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8"
    ]
}

public extension CCZUConstants {
    enum Jwqywx {
        /// 教务企业微信请求 Origin
        public static let origin = "http://jwqywx.cczu.edu.cn"
        /// 教务企业微信请求 Referer
        public static let referer = "http://jwqywx.cczu.edu.cn/"
        /// 教务企业微信 API 基础地址
        public static let apiBase = "http://jwqywx.cczu.edu.cn:8180/api"

        /// 认证请求头字段名
        public static let authHeader = "Authorization"
        /// Bearer Token 前缀
        public static let bearerPrefix = "Bearer "

        public static let noTermFoundMessage = "No term found"
        public static let noBasicInfoMessage = "No basic info"
        public static let defaultExamType = "学分制考试"
        public static let defaultSelectionFunctionCode = "xkbm_fsxz"

        public static let cacheDirectoryName = "CCZUKit"
        public static let trainingPlanCachePrefix = "training_plan_"
        public static let trainingPlanCacheExtension = ".json"

        /// 登录接口
        public static let loginURL = URL(string: "\(apiBase)/login")!
        /// 成绩查询接口
        public static let gradesURL = URL(string: "\(apiBase)/cj_xh")!
        /// 学分绩点接口
        public static let creditsAndRankURL = URL(string: "\(apiBase)/cj_xh_xfjd")!
        /// 学期列表接口
        public static let termsURL = URL(string: "\(apiBase)/xqall")!
        /// 培养方案接口
        public static let trainingPlanURL = URL(string: "\(apiBase)/cj_xh_jxjh_cj")!
        /// 学生基本信息接口
        public static let studentBasicInfoURL = URL(string: "\(apiBase)/xs_xh_jbxx")!
        /// 课表接口
        public static let classScheduleURL = URL(string: "\(apiBase)/kb_xq_xh")!
        /// 授课教师补充接口
        public static let courseTeacherSupplementURL = URL(string: "\(apiBase)/kbk_xq_xh")!
        /// 考试安排接口
        public static let examArrangementsURL = URL(string: "\(apiBase)/ks_xs_kslb")!
        /// 可评价课程接口
        public static let evaluatableClassesURL = URL(string: "\(apiBase)/pj_xspj_kcxx")!
        /// 已提交评价接口
        public static let submittedEvaluationsURL = URL(string: "\(apiBase)/pj_xh_pjxx")!
        /// 提交评价接口
        public static let submitTeacherEvaluationURL = URL(string: "\(apiBase)/pj_insert_xspj")!

        /// 选课功能权限检查接口
        public static let checkSelectionPermissionURL = URL(string: "\(apiBase)/qx_yhdm_gnmk_syqx")!
        /// 选课批次查询接口
        public static let selectionBatchesURL = URL(string: "\(apiBase)/xk_xkxm_nj")!
        /// 选课批次权限接口
        public static let batchPermissionURL = URL(string: "\(apiBase)/xkqx_dm_nj")!
        /// 可选课程列表接口
        public static let selectableCoursesURL = URL(string: "\(apiBase)/xk_xh_kbk")!
        /// 选课提交接口
        public static let selectCoursesURL = URL(string: "\(apiBase)/xk_insert_xfz")!
        /// 退课接口
        public static let dropCoursesURL = URL(string: "\(apiBase)/xk_delete_xfzxkmd")!

        /// 通识可选课程接口
        public static let generalElectiveCoursesURL = URL(string: "\(apiBase)/yxk_xk_xh_kxkc_gx")!
        /// 通识实际已选人数接口
        public static let generalElectiveActualCountsURL = URL(string: "\(apiBase)/yxk_xk_xkrs_gx")!
        /// 通识已选课程接口
        public static let selectedGeneralElectiveCoursesURL = URL(string: "\(apiBase)/yxk_xk_xh_yxkc_gx")!
        /// 通识批次权限接口
        public static let checkGeneralElectivePermissionURL = URL(string: "\(apiBase)/yxk_xkqx_dm_nj")!
        /// 通识选课提交接口
        public static let selectGeneralElectiveCoursesURL = URL(string: "\(apiBase)/yxk_xk_insert_ggxx")!
        /// 通识退课接口
        public static let dropGeneralElectiveCourseURL = URL(string: "\(apiBase)/yxk_xk_delete_ggxx")!
    }

    enum SSO {
        /// SSO 登录页 URL
        public static let loginURL = URL(string: CCZUConstants.rootSSOLogin)!

        /// 按服务参数构造 SSO 登录 URL
        public static func serviceLoginURL(service: String) -> URL {
            if service.isEmpty {
                return loginURL
            }
            return URL(string: "\(CCZUConstants.rootSSOLogin)?service=\(service)")!
        }
    }

    enum Electricity {
        /// 电费查询接口固定 account 参数
        public static let account = "1"
        /// 电费-楼栋列表查询接口
        public static let queryBuildingURL = URL(string: "http://wxxy.cczu.edu.cn/wechat/callinterface/queryElecBuilding.html")!
        /// 电费-房间电量查询接口
        public static let queryRoomURL = URL(string: "http://wxxy.cczu.edu.cn/wechat/callinterface/queryElecRoomInfo.html")!

        /// 电费楼栋查询请求头 User-Agent
        public static let buildingUserAgent = "Mozilla/5.0 (Linux; Android 15; V2232A Build/AP3A.240905.015.A2; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.136 Mobile Safari/537.36 XWEB/1340157 MMWEBSDK/20250201 MMWEBID/140 wxwork/4.1.38 MicroMessenger/7.0.1 NetType/WIFI Language/zh Lang/zh ColorScheme/Light wwmver/3.26.38.639"
        /// 电费房间查询请求头 User-Agent
        public static let roomUserAgent = "Mozilla/5.0 (Linux; Android 15; V2232A Build/AP3A.240905.015.A2; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.136 Mobile Safari/537.36 XWEB/1340125 MMWEBSDK/20250201 MMWEBID/140 wxwork/4.1.38 MicroMessenger/7.0.1 NetType/WIFI Language/zh Lang/zh ColorScheme/Light wwmver/3.26.38.639"

        /// 预置可选校区列表
        public static let predefinedAreas: [(area: String, areaname: String, aid: String)] = [
            ("西太湖校区", "西太湖校区", "0030000000002501"),
            ("武进校区", "武进校区", "0030000000002502"),
            ("西太湖校区1-7,10-11", "西太湖校区1-7,10-11", "0030000000002503")
        ]
    }
}
