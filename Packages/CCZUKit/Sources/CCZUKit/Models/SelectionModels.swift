import Foundation

// MARK: - 选课相关模型

/// 可选/已选课程项（来自 xk_xh_kbk）
public struct SelectableCourse: Decodable, Sendable {
    public let term: String            // xq 学期
    public let classCode: String       // bh 班级号
    public let className: String       // bj 班级名
    public let courseCode: String      // kcdm 课程代码
    public let courseName: String      // kcmc 课程名称
    public let courseSerial: String    // kch 课程序列号
    public let categoryCode: String    // lbdh 类别代码
    public let hours: Int              // xs 学时
    public let credits: Double         // xf 学分
    public let examTypeName: String    // ksfs 考试方式(文字)
    public let capacity: Int           // kkrs 开课人数/容量
    public let courseAttrCode: String  // kcxbdm 课程属性代码
    public let teacherCode: String     // jsdm 教师代码
    public let teacherName: String     // jsmc 教师名称
    public let isExamType: Int         // ksxzm 考试性质码
    public let examMode: Int           // ksfsm 考试方式码
    public let idn: Int                // idn 课程标识
    public let selectionStatus: String // xkqk 选课情况（"已选"/空）
    public let selectedId: Int         // xkidn 已选记录ID（未选为0）
    public let studyType: String       // xklb 修读类别

    enum CodingKeys: String, CodingKey {
        case term = "xq"
        case classCode = "bh"
        case className = "bj"
        case courseCode = "kcdm"
        case courseName = "kcmc"
        case courseSerial = "kch"
        case categoryCode = "lbdh"
        case hours = "xs"
        case credits = "xf"
        case examTypeName = "ksfs"
        case capacity = "kkrs"
        case courseAttrCode = "kcxbdm"
        case teacherCode = "jsdm"
        case teacherName = "jsmc"
        case isExamType = "ksxzm"
        case examMode = "ksfsm"
        case idn
        case selectionStatus = "xkqk"
        case selectedId = "xkidn"
        case studyType = "xklb"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        term = try c.decode(String.self, forKey: .term).trimmingCharacters(in: .whitespaces)
        classCode = try c.decode(String.self, forKey: .classCode).trimmingCharacters(in: .whitespaces)
        className = try c.decode(String.self, forKey: .className).trimmingCharacters(in: .whitespaces)
        courseCode = try c.decode(String.self, forKey: .courseCode).trimmingCharacters(in: .whitespaces)
        courseName = try c.decode(String.self, forKey: .courseName).trimmingCharacters(in: .whitespaces)
        courseSerial = try c.decode(String.self, forKey: .courseSerial).trimmingCharacters(in: .whitespaces)
        categoryCode = try c.decode(String.self, forKey: .categoryCode).trimmingCharacters(in: .whitespaces)
        hours = try c.decode(Int.self, forKey: .hours)
        credits = try c.decode(Double.self, forKey: .credits)
        examTypeName = try c.decode(String.self, forKey: .examTypeName).trimmingCharacters(in: .whitespaces)
        capacity = try c.decode(Int.self, forKey: .capacity)
        courseAttrCode = try c.decode(String.self, forKey: .courseAttrCode).trimmingCharacters(in: .whitespaces)
        teacherCode = try c.decode(String.self, forKey: .teacherCode).trimmingCharacters(in: .whitespaces)
        teacherName = try c.decode(String.self, forKey: .teacherName).trimmingCharacters(in: .whitespaces)
        isExamType = try c.decode(Int.self, forKey: .isExamType)
        examMode = try c.decode(Int.self, forKey: .examMode)
        idn = try c.decode(Int.self, forKey: .idn)
        selectionStatus = (try c.decodeIfPresent(String.self, forKey: .selectionStatus) ?? "").trimmingCharacters(in: .whitespaces)
        selectedId = try c.decode(Int.self, forKey: .selectedId)
        studyType = try c.decode(String.self, forKey: .studyType).trimmingCharacters(in: .whitespaces)
    }
}

/// 简单响应（message 可能是 Int 或 String）
public struct SimpleJWResponse: Decodable, Sendable {
    public let status: Int
    public let token: String?
    public let messageInt: Int?
    public let messageString: String?

    enum CodingKeys: String, CodingKey { case status, token, message }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = try c.decode(Int.self, forKey: .status)
        token = try c.decodeIfPresent(String.self, forKey: .token)
        // message 可能为数字或字符串
        if let intVal = try? c.decode(Int.self, forKey: .message) {
            messageInt = intVal
            messageString = nil
        } else if let strVal = try? c.decode(String.self, forKey: .message) {
            messageInt = nil
            messageString = strVal
        } else {
            messageInt = nil
            messageString = nil
        }
    }
}

// MARK: - 选课批次与权限

/// 选课批次信息（学期对应的选课时间窗）
public struct SelectionBatch: Decodable, Sendable {
    public let code: String               // dm 批次代码如 "0003-004"
    public let name: String               // mc 批次名称如"学分制选课"
    public let grade: Int                 // nj 年级
    public let term: String               // xkxq 对应学期如 "25-26-2"
    public let remark: String             // bz 备注
    public let selectionMethod: String    // cxbmfs 选课方式
    public let maxCourses: Int            // xkmc 最多选课数
    public let beginDate: String          // begindate ISO 时间
    public let endDate: String            // enddate ISO 时间
    public let isSelectable: Bool         // xk 是否可选

    /// 是否在开放时间段内
    public var isOpen: Bool {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let begin = formatter.date(from: beginDate),
           let end = formatter.date(from: endDate) {
            return now >= begin && now <= end
        }
        return false
    }

    /// 是否允许选课（等同于 isSelectable）
    public var isAllowed: Bool {
        return isSelectable
    }

    enum CodingKeys: String, CodingKey {
        case code = "dm"
        case name = "mc"
        case grade = "nj"
        case term = "xkxq"
        case remark = "bz"
        case selectionMethod = "cxbmfs"
        case maxCourses = "xkmc"
        case beginDate = "begindate"
        case endDate = "enddate"
        case isSelectable = "xk"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decode(String.self, forKey: .code).trimmingCharacters(in: .whitespaces)
        name = try c.decode(String.self, forKey: .name).trimmingCharacters(in: .whitespaces)
        grade = try c.decode(Int.self, forKey: .grade)
        term = try c.decode(String.self, forKey: .term).trimmingCharacters(in: .whitespaces)
        remark = (try c.decodeIfPresent(String.self, forKey: .remark) ?? "").trimmingCharacters(in: .whitespaces)
        selectionMethod = (try c.decodeIfPresent(String.self, forKey: .selectionMethod) ?? "").trimmingCharacters(in: .whitespaces)
        maxCourses = try c.decode(Int.self, forKey: .maxCourses)
        beginDate = try c.decode(String.self, forKey: .beginDate)
        endDate = try c.decode(String.self, forKey: .endDate)
        isSelectable = try c.decode(Bool.self, forKey: .isSelectable)
    }
}

/// 选课权限（某批次是否对该年级开放）
public struct SelectionPermission: Decodable, Sendable {
    public let isAllowed: Bool            // xk 是否有权选课（后端返回整数0/1）
    public let term: String               // xkxq 对应学期
    public let remark: String             // bz 备注
    public let selectionMethod: String    // cxbmfs 选课方式
    public let maxCourses: Int            // xkmc 最多选课数

    enum CodingKeys: String, CodingKey {
        case isAllowed = "xk"
        case term = "xkxq"
        case remark = "bz"
        case selectionMethod = "cxbmfs"
        case maxCourses = "xkmc"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // 后端返回整数 0/1，需要先解码为 Int 再转换为 Bool
        let xkInt = try c.decode(Int.self, forKey: .isAllowed)
        isAllowed = xkInt != 0
        term = try c.decode(String.self, forKey: .term).trimmingCharacters(in: .whitespaces)
        remark = (try c.decodeIfPresent(String.self, forKey: .remark) ?? "").trimmingCharacters(in: .whitespaces)
        selectionMethod = (try c.decodeIfPresent(String.self, forKey: .selectionMethod) ?? "").trimmingCharacters(in: .whitespaces)
        maxCourses = try c.decode(Int.self, forKey: .maxCourses)
    }
}

// MARK: - 通识类选修课程相关模型

/// 通识类选修课程项（来自 yxk_xk_xh_kxkc_gx）
public struct GeneralElectiveCourse: Decodable, Sendable {
    public let term: String                    // xq 学期
    public let courseSerial: Int               // kcxh 课程序号
    public let courseCode: String              // kcdm 课程代码
    public let courseName: String              // kcmc 课程名称
    public let teacherCode: String             // jsdm 教师代码
    public let teacherName: String             // jsmc 教师名称
    public let hours: Int                      // xs 学时
    public let credits: Double                 // xf 学分
    public let categoryCode: String            // lbdh 类别代码
    public let categoryName: String            // lbmc 类别名称
    public let timeDescription: String         // sj 时间描述
    public let capacity: Int                   // xxrs 限选人数
    public let selectedCount: Int              // xkrs 已选人数
    public let availableCount: Int             // kxrs 可选人数
    public let batchCode: String               // lbdm 批次代码
    public let description: String?            // xxsm 详细说明
    public let campus: String                  // jse 教学地点
    public let week: Int                       // zc 周次
    public let startSlot: Int                  // jc1 开始节次
    public let endSlot: Int                    // jc2 结束节次

    enum CodingKeys: String, CodingKey {
        case term = "xq"
        case courseSerial = "kcxh"
        case courseCode = "kcdm"
        case courseName = "kcmc"
        case teacherCode = "jsdm"
        case teacherName = "jsmc"
        case hours = "xs"
        case credits = "xf"
        case categoryCode = "lbdh"
        case categoryName = "lbmc"
        case timeDescription = "sj"
        case capacity = "xxrs"
        case selectedCount = "xkrs"
        case availableCount = "kxrs"
        case batchCode = "lbdm"
        case description = "xxsm"
        case campus = "jse"
        case week = "zc"
        case startSlot = "jc1"
        case endSlot = "jc2"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        term = try c.decode(String.self, forKey: .term).trimmingCharacters(in: .whitespaces)
        courseSerial = try c.decode(Int.self, forKey: .courseSerial)
        courseCode = try c.decode(String.self, forKey: .courseCode).trimmingCharacters(in: .whitespaces)
        courseName = try c.decode(String.self, forKey: .courseName).trimmingCharacters(in: .whitespaces)
        teacherCode = try c.decode(String.self, forKey: .teacherCode).trimmingCharacters(in: .whitespaces)
        teacherName = try c.decode(String.self, forKey: .teacherName).trimmingCharacters(in: .whitespaces)
        hours = try c.decode(Int.self, forKey: .hours)
        credits = try c.decode(Double.self, forKey: .credits)
        categoryCode = try c.decode(String.self, forKey: .categoryCode).trimmingCharacters(in: .whitespaces)
        categoryName = try c.decode(String.self, forKey: .categoryName).trimmingCharacters(in: .whitespaces)
        timeDescription = try c.decode(String.self, forKey: .timeDescription).trimmingCharacters(in: .whitespaces)
        capacity = try c.decode(Int.self, forKey: .capacity)
        selectedCount = try c.decode(Int.self, forKey: .selectedCount)
        availableCount = try c.decode(Int.self, forKey: .availableCount)
        batchCode = try c.decode(String.self, forKey: .batchCode).trimmingCharacters(in: .whitespaces)
        description = try c.decodeIfPresent(String.self, forKey: .description)?.trimmingCharacters(in: .whitespaces)
        campus = try c.decode(String.self, forKey: .campus).trimmingCharacters(in: .whitespaces)
        week = try c.decode(Int.self, forKey: .week)
        startSlot = try c.decode(Int.self, forKey: .startSlot)
        endSlot = try c.decode(Int.self, forKey: .endSlot)
    }

    /// 可用于程序内构建或复制并修改已选/可选人数的初始化器
    public init(
        term: String,
        courseSerial: Int,
        courseCode: String,
        courseName: String,
        teacherCode: String,
        teacherName: String,
        hours: Int,
        credits: Double,
        categoryCode: String,
        categoryName: String,
        timeDescription: String,
        capacity: Int,
        selectedCount: Int,
        availableCount: Int,
        batchCode: String,
        description: String?,
        campus: String,
        week: Int,
        startSlot: Int,
        endSlot: Int
    ) {
        self.term = term
        self.courseSerial = courseSerial
        self.courseCode = courseCode
        self.courseName = courseName
        self.teacherCode = teacherCode
        self.teacherName = teacherName
        self.hours = hours
        self.credits = credits
        self.categoryCode = categoryCode
        self.categoryName = categoryName
        self.timeDescription = timeDescription
        self.capacity = capacity
        self.selectedCount = selectedCount
        self.availableCount = availableCount
        self.batchCode = batchCode
        self.description = description
        self.campus = campus
        self.week = week
        self.startSlot = startSlot
        self.endSlot = endSlot
    }
}

/// 实际已选人数返回项（yxk_xk_xkrs_gx）
public struct ActualSelectedCount: Decodable, Sendable {
    public let courseSerial: Int
    public let selectedCount: Int

    enum CodingKeys: String, CodingKey {
        case courseSerial = "kcxh"
        case selectedCount = "xkrs"
    }
}

/// 已选通识类选修课程项（来自 yxk_xk_xh_yxkc_gx）
public struct SelectedGeneralElectiveCourse: Decodable, Sendable {
    public let term: String                    // xq 学期
    public let studentId: String               // xh 学号
    public let courseSerial: Int               // kcxh 课程序号
    public let courseCode: String              // kcdm 课程代码
    public let courseName: String              // kcmc 课程名称
    public let teacherCode: String             // jsdm 教师代码
    public let teacherName: String             // jsmc 教师名称
    public let hours: Int                      // xs 学时
    public let credits: Double                 // xf 学分
    public let categoryCode: String            // lbdh 类别代码
    public let categoryName: String            // lbmc 类别名称
    public let timeDescription: String         // sj 时间描述
    public let capacity: Int                   // xxrs 限选人数
    public let selectedCount: Int              // xkrs 已选人数
    public let availableCount: Int             // kxrs 可选人数
    public let batchCode: String               // lbdm 批次代码
    public let description: String?            // xxsm 详细说明
    public let campus: String                  // jse 教学地点
    public let week: Int                       // zc 周次
    public let startSlot: Int                  // jc1 开始节次
    public let endSlot: Int                    // jc2 结束节次

    enum CodingKeys: String, CodingKey {
        case term = "xq"
        case studentId = "xh"
        case courseSerial = "kcxh"
        case courseCode = "kcdm"
        case courseName = "kcmc"
        case teacherCode = "jsdm"
        case teacherName = "jsmc"
        case hours = "xs"
        case credits = "xf"
        case categoryCode = "lbdh"
        case categoryName = "lbmc"
        case timeDescription = "sj"
        case capacity = "xxrs"
        case selectedCount = "xkrs"
        case availableCount = "kxrs"
        case batchCode = "lbdm"
        case description = "xxsm"
        case campus = "jse"
        case week = "zc"
        case startSlot = "jc1"
        case endSlot = "jc2"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // 使用灵活解析：后端返回字段可能不完全一致，使用 decodeIfPresent 并提供默认值以避免解码失败
        term = (try c.decodeIfPresent(String.self, forKey: .term) ?? "").trimmingCharacters(in: .whitespaces)
        studentId = (try c.decodeIfPresent(String.self, forKey: .studentId) ?? "").trimmingCharacters(in: .whitespaces)
        courseSerial = try c.decodeIfPresent(Int.self, forKey: .courseSerial) ?? 0
        courseCode = (try c.decodeIfPresent(String.self, forKey: .courseCode) ?? "").trimmingCharacters(in: .whitespaces)
        courseName = (try c.decodeIfPresent(String.self, forKey: .courseName) ?? "").trimmingCharacters(in: .whitespaces)
        teacherCode = (try c.decodeIfPresent(String.self, forKey: .teacherCode) ?? "").trimmingCharacters(in: .whitespaces)
        teacherName = (try c.decodeIfPresent(String.self, forKey: .teacherName) ?? "").trimmingCharacters(in: .whitespaces)
        hours = try c.decodeIfPresent(Int.self, forKey: .hours) ?? 0
        credits = try c.decodeIfPresent(Double.self, forKey: .credits) ?? (Double(try c.decodeIfPresent(Int.self, forKey: .credits) ?? 0))
        categoryCode = (try c.decodeIfPresent(String.self, forKey: .categoryCode) ?? "").trimmingCharacters(in: .whitespaces)
        categoryName = (try c.decodeIfPresent(String.self, forKey: .categoryName) ?? "").trimmingCharacters(in: .whitespaces)
        timeDescription = (try c.decodeIfPresent(String.self, forKey: .timeDescription) ?? "").trimmingCharacters(in: .whitespaces)
        capacity = try c.decodeIfPresent(Int.self, forKey: .capacity) ?? 0
        selectedCount = try c.decodeIfPresent(Int.self, forKey: .selectedCount) ?? 0
        availableCount = try c.decodeIfPresent(Int.self, forKey: .availableCount) ?? max(0, capacity - selectedCount)
        batchCode = (try c.decodeIfPresent(String.self, forKey: .batchCode) ?? "").trimmingCharacters(in: .whitespaces)
        description = try c.decodeIfPresent(String.self, forKey: .description)?.trimmingCharacters(in: .whitespaces)
        campus = (try c.decodeIfPresent(String.self, forKey: .campus) ?? "").trimmingCharacters(in: .whitespaces)
        week = try c.decodeIfPresent(Int.self, forKey: .week) ?? 0
        startSlot = try c.decodeIfPresent(Int.self, forKey: .startSlot) ?? 0
        endSlot = try c.decodeIfPresent(Int.self, forKey: .endSlot) ?? 0
    }
}

/// 通识类选修课程批次权限（来自 yxk_xkqx_dm_nj）
public struct GeneralElectivePermission: Decodable, Sendable {
    public let isAllowed: Bool                 // xk 是否有权选课
    public let term: String                    // xkxq 对应学期
    public let remark: String                  // bz 备注
    public let selectionMethod: String         // cxbmfs 选课方式
    public let maxCourses: Int                 // xkmc 最多选课数

    enum CodingKeys: String, CodingKey {
        case isAllowed = "xk"
        case term = "xkxq"
        case remark = "bz"
        case selectionMethod = "cxbmfs"
        case maxCourses = "xkmc"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let xkInt = try c.decode(Int.self, forKey: .isAllowed)
        isAllowed = xkInt != 0
        term = try c.decode(String.self, forKey: .term).trimmingCharacters(in: .whitespaces)
        remark = (try c.decodeIfPresent(String.self, forKey: .remark) ?? "").trimmingCharacters(in: .whitespaces)
        selectionMethod = (try c.decodeIfPresent(String.self, forKey: .selectionMethod) ?? "").trimmingCharacters(in: .whitespaces)
        maxCourses = try c.decode(Int.self, forKey: .maxCourses)
    }
}
