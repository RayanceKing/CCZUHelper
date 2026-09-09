import Foundation

// MARK: - 登录用户数据
public struct LoginUserData: Decodable, Sendable {
    public let userid: String
    public let username: String
    public let userident: String
    public let term: String
    public let currentValue: Int
    public let position: Int
    public let employeeNumber: String
    public let smscode: String
    public let gender: String
    public let permission: String
    public let id: String

    enum CodingKeys: String, CodingKey {
        case userid = "yhdm"
        case username = "yhmc"
        case userident = "yhsf"
        case term = "xq"
        case currentValue = "dqz"
        case position = "zc"
        case employeeNumber = "gh"
        case smscode
        case gender = "xb"
        case permission = "yhqx"
        case id = "yhid"
    }
}

// MARK: - 课程成绩
public struct CourseGrade: Decodable, Sendable {
    public let classId: String
    public let className: String
    public let studentId: String
    public let studentName: String
    public let courseId: String
    public let courseName: String
    public let term: Int
    public let courseType: String
    public let courseTypeName: String
    public let courseHours: Int
    public let courseCredits: Double
    public let teacherName: String
    public let isExamType: Int
    public let examType: String
    public let examGrade: String
    public let ident: Int
    public let grade: Double
    public let gradePoints: Double

    enum CodingKeys: String, CodingKey {
        case classId = "bh"
        case className = "bj"
        case studentId = "xh"
        case studentName = "xm"
        case courseId = "kcdm"
        case courseName = "kcmc"
        case term = "xq"
        case courseType = "kclb"
        case courseTypeName = "lbmc"
        case courseHours = "xs"
        case courseCredits = "xf"
        case teacherName = "jsmc"
        case isExamType = "ksxzm"
        case examType = "ksxz"
        case examGrade = "kscj"
        case ident = "idn"
        case grade = "cj"
        case gradePoints = "xfjd"
    }
}

// MARK: - 学生绩点信息
public struct StudentPoint: Decodable, Sendable {
    public let classId: String
    public let className: String
    public let studentId: String
    public let studentName: String
    public let studentGender: String
    public let studentStatus: String
    public let studentBirthday: String
    public let studentXid: String
    public let gradePoints: Double

    enum CodingKeys: String, CodingKey {
        case classId = "bh"
        case className = "bj"
        case studentId = "xh"
        case studentName = "xm"
        case studentGender = "xb"
        case studentStatus = "xjqk"
        case studentBirthday = "csny"
        case studentXid = "xsid"
        case gradePoints = "pjxfjd"
    }
}

// MARK: - 学期信息
public struct Term: Decodable, Sendable {
    public let term: String

    enum CodingKeys: String, CodingKey {
        case term = "xq"
    }
}

// MARK: - 课程信息
public struct RawCourse: Sendable {
    public let course: String
    public let teacher: String

    public init(course: String, teacher: String) {
        self.course = course
        self.teacher = teacher
    }
}

// MARK: - 考试安排
public struct ExamArrangement: Decodable, Sendable {
    public let id: Int
    public let courseId: String
    public let courseName: String
    public let courseCode: String
    public let classId: String
    public let className: String
    public let studentId: String
    public let studentName: String
    public let examLocation: String?
    public let examTime: String?
    public let examType: String
    public let studyType: String
    public let campus: String
    public let remark: String?
    public let week: Int?
    public let startSlot: Int?
    public let endSlot: Int?
    public let term: String
    public let examDayInfo: String?
    public let isActive: Int
    public let examSeat: Int?
    public let classNumber: String
    public let teacherRoomId: Int
    public let startTeacherSlot: Int?
    public let endTeacherSlot: Int?
    public let classShortName: String          // 班级简称

    enum CodingKeys: String, CodingKey {
        case id
        case courseId = "kch"
        case courseName = "kcmc"
        case courseCode = "kcdm"
        case classId = "xsbh"
        case className = "xsbj"
        case studentId = "xh"
        case studentName = "xm"
        case examLocation = "jse"
        case examTime = "sj"           // 实际API使用 "sj" 而不是 "kssj"
        case examType = "lb"
        case studyType = "xklb"
        case campus = "bmmc"
        case remark = "bz"
        case week = "zc"
        case startSlot = "jc1"
        case endSlot = "jc2"
        case term = "xq"
        case examDayInfo = "sjxx"
        case isActive = "yx"
        case examSeat = "ksz"
        case classNumber = "BH"
        case teacherRoomId = "jseid"
        case startTeacherSlot = "jkjs1"
        case endTeacherSlot = "jkjs2"
        case classShortName = "bj"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        courseId = try container.decode(String.self, forKey: .courseId).trimmingCharacters(in: .whitespaces)
        courseName = try container.decode(String.self, forKey: .courseName).trimmingCharacters(in: .whitespaces)
        courseCode = try container.decode(String.self, forKey: .courseCode).trimmingCharacters(in: .whitespaces)
        classId = try container.decode(String.self, forKey: .classId).trimmingCharacters(in: .whitespaces)
        className = try container.decode(String.self, forKey: .className).trimmingCharacters(in: .whitespaces)
        studentId = try container.decode(String.self, forKey: .studentId).trimmingCharacters(in: .whitespaces)
        studentName = try container.decode(String.self, forKey: .studentName).trimmingCharacters(in: .whitespaces)
        examLocation = try container.decodeIfPresent(String.self, forKey: .examLocation)?.trimmingCharacters(in: .whitespaces)
        examTime = try container.decodeIfPresent(String.self, forKey: .examTime)?.trimmingCharacters(in: .whitespaces)
        examType = try container.decode(String.self, forKey: .examType).trimmingCharacters(in: .whitespaces)
        studyType = try container.decode(String.self, forKey: .studyType).trimmingCharacters(in: .whitespaces)
        campus = try container.decode(String.self, forKey: .campus).trimmingCharacters(in: .whitespaces)
        remark = try container.decodeIfPresent(String.self, forKey: .remark)?.trimmingCharacters(in: .whitespaces)
        week = try container.decodeIfPresent(Int.self, forKey: .week)
        startSlot = try container.decodeIfPresent(Int.self, forKey: .startSlot)
        endSlot = try container.decodeIfPresent(Int.self, forKey: .endSlot)
        term = try container.decode(String.self, forKey: .term).trimmingCharacters(in: .whitespaces)
        examDayInfo = try container.decodeIfPresent(String.self, forKey: .examDayInfo)?.trimmingCharacters(in: .whitespaces)
        isActive = try container.decode(Int.self, forKey: .isActive)
        examSeat = try container.decodeIfPresent(Int.self, forKey: .examSeat)
        classNumber = try container.decode(String.self, forKey: .classNumber).trimmingCharacters(in: .whitespaces)
        teacherRoomId = try container.decode(Int.self, forKey: .teacherRoomId)
        startTeacherSlot = try container.decodeIfPresent(Int.self, forKey: .startTeacherSlot)
        endTeacherSlot = try container.decodeIfPresent(Int.self, forKey: .endTeacherSlot)
        classShortName = try container.decode(String.self, forKey: .classShortName).trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - 学生基本信息
public struct StudentBasicInfo: Decodable, Sendable {
    public let name: String                    // 姓名
    public let major: String                   // 专业名称
    public let genderCode: String              // 性别代码
    public let phone: String                   // 手机号
    public let birthday: String                // 出生日期
    public let className: String               // 班级
    public let studentId: String               // 学生ID
    public let collegeName: String             // 学院名称
    public let gender: String                  // 性别
    public let grade: Int                      // 年级
    public let campus: String                  // 校区名称
    public let majorCode: String               // 专业代码
    public let classCode: String               // 班级号
    public let studyLength: String             // 学制
    public let studentStatus: String           // 学籍情况
    public let studentNumber: String           // 学号
    public let dormitoryNumber: String         // 宿舍编号

    enum CodingKeys: String, CodingKey {
        case name = "xm"
        case major = "zymc"
        case genderCode = "xbdm"
        case phone = "smscode"
        case birthday = "csny"
        case className = "bj"
        case studentId = "xsid"
        case collegeName = "xbmc"
        case gender = "xb"
        case grade = "nj"
        case campus = "bmmc"
        case majorCode = "zydm"
        case classCode = "bh"
        case studyLength = "xz"
        case studentStatus = "xjqk"
        case studentNumber = "xh"
        case dormitoryNumber = "shbh"
    }
}

// MARK: - 可评价的课程信息
public struct EvaluatableClass: Decodable, Sendable {
    public let classId: String                 // 班级号 (bh)
    public let courseCode: String              // 课程代码 (kcdm)
    public let courseName: String              // 课程名称 (kcmc)
    public let courseSerial: String            // 课程序列号 (kch)
    public let categoryCode: String            // 类别代码 (lbdh)
    public let teacherCode: String             // 教师代码 (jsdm)
    public let teacherName: String             // 教师名称 (jsmc)
    public let evaluationStatus: String?       // 评价状态 (pjqk)
    public let evaluationId: Int               // 评价ID (pjid)
    public let teacherId: String               // 教师ID (jsid)

    enum CodingKeys: String, CodingKey {
        case classId = "bh"
        case courseCode = "kcdm"
        case courseName = "kcmc"
        case courseSerial = "kch"
        case categoryCode = "lbdh"
        case teacherCode = "jsdm"
        case teacherName = "jsmc"
        case evaluationStatus = "pjqk"
        case evaluationId = "pjid"
        case teacherId = "jsid"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        classId = try container.decode(String.self, forKey: .classId).trimmingCharacters(in: .whitespaces)
        courseCode = try container.decode(String.self, forKey: .courseCode).trimmingCharacters(in: .whitespaces)
        courseName = try container.decode(String.self, forKey: .courseName).trimmingCharacters(in: .whitespaces)
        courseSerial = try container.decode(String.self, forKey: .courseSerial).trimmingCharacters(in: .whitespaces)
        categoryCode = try container.decode(String.self, forKey: .categoryCode).trimmingCharacters(in: .whitespaces)
        teacherCode = try container.decode(String.self, forKey: .teacherCode).trimmingCharacters(in: .whitespaces)
        teacherName = try container.decode(String.self, forKey: .teacherName).trimmingCharacters(in: .whitespaces)
        evaluationStatus = try container.decodeIfPresent(String.self, forKey: .evaluationStatus)?.trimmingCharacters(in: .whitespaces)
        evaluationId = try container.decode(Int.self, forKey: .evaluationId)
        teacherId = (try container.decodeIfPresent(String.self, forKey: .teacherId) ?? "").trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - 已提交的评价信息
public struct SubmittedEvaluation: Decodable, Sendable {
    public let term: String                    // 学期 (xq)
    public let evaluationId: String            // 评价ID (pjid)
    public let studentNumber: String           // 学号 (xh)
    public let teacherCode: String             // 教师代码 (jsdm)
    public let teacherName: String             // 教师名称 (jsmc)
    public let courseCode: String              // 课程代码 (kcdm)
    public let courseName: String              // 课程名称 (kcmc)
    public let overallScore: Int               // 总体评分 (zhdf)
    public let scores: String                  // 各项评分 (pjjg)
    public let comments: String                // 评价意见 (yjjy)

    enum CodingKeys: String, CodingKey {
        case term = "xq"
        case evaluationId = "pjid"
        case studentNumber = "xh"
        case teacherCode = "jsdm"
        case teacherName = "jsmc"
        case courseCode = "kcdm"
        case courseName = "kcmc"
        case overallScore = "zhdf"
        case scores = "pjjg"
        case comments = "yjjy"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        term = try container.decode(String.self, forKey: .term).trimmingCharacters(in: .whitespaces)
        evaluationId = try container.decode(String.self, forKey: .evaluationId).trimmingCharacters(in: .whitespaces)
        studentNumber = try container.decode(String.self, forKey: .studentNumber).trimmingCharacters(in: .whitespaces)
        teacherCode = try container.decode(String.self, forKey: .teacherCode).trimmingCharacters(in: .whitespaces)
        teacherName = try container.decode(String.self, forKey: .teacherName).trimmingCharacters(in: .whitespaces)
        courseCode = try container.decode(String.self, forKey: .courseCode).trimmingCharacters(in: .whitespaces)
        courseName = try container.decode(String.self, forKey: .courseName).trimmingCharacters(in: .whitespaces)
        overallScore = try container.decode(Int.self, forKey: .overallScore)
        scores = try container.decode(String.self, forKey: .scores).trimmingCharacters(in: .whitespaces)
        comments = try container.decode(String.self, forKey: .comments).trimmingCharacters(in: .whitespaces)
    }
}


// MARK: - Elink登录信息
public struct ElinkLoginInfo: Decodable, Sendable {
    public let userid: String
    public let username: String?

    enum CodingKeys: String, CodingKey {
        case userid
        case username
    }
}
