// 测试账户使用说明
//
// 为开发和测试方便，软件内置了一个测试账户功能。
//
// MARK: - 如何使用测试账户
//
// 1. 在教务系统登陆时，使用以下信息：
//    - 邮箱: test@edupal.czumc.cn
//    - 密码: (可为空，或输入 "test")
//
// 2. 测试账户的特点：
//    ✅ 免除真实教务系统验证
//    ✅ 使用内置样例数据
//    ✅ 本地快速登陆
//    ✅ 完整的课程和学籍信息
//
// 3. 哪些功能支持测试账户：
//    ✅ 教务系统登陆
//    ✅ 用户信息页面
//    ✅ 课程表显示
//    ❌ 茶馆账户（不支持，仍需真实 Supabase 注册）
//
// MARK: - 测试数据详情
//
// 测试学生信息（来自 TestData.sampleStudentInfo）：
// - 姓名: 测试用户
// - 学号: 2022001001
// - 班级: 计科2201
// - 学院: 计算机学院
// - 年级: 2022
// - 其他: 参见 TestData.swift
//
// 样例课程（来自 TestData.sampleCourses）：
// - 周一: 数据结构、线性代数
// - 周二: 数据库原理、Web开发
// - 周三: 人工智能基础
// - 周四: 操作系统、计算机网络
// - 周五: Java开发、算法设计
//
// MARK: - 文件结构
//
// 新建文件：
// - Models/TestData.swift              (测试常量和样例数据)
// - Models/TestDataManager.swift       (测试数据管理和模拟应用)
//
// 修改文件：
// - Models/AppSettings.swift           (支持测试账户登陆)
// - Views/Teahouse/TeahouseLoginView.swift (测试账户注册检查)
// - Views/UserInfoView.swift           (测试账户信息加载)
// - Views/RegistrationProfileSetupView.swift (测试账户资料加载)
//
