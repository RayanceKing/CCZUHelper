# 龙城学伴 · Android 版

iOS 版 `CCZUHelper`（SwiftUI + SwiftData）的 Android 移植：**Kotlin + Jetpack Compose + Material3**，
教务能力直接复用 `CCZUKit/android` 的 Kotlin 库（`:cczukit`，模块方式引入，不拷贝源码）。

## 目录结构

```
android/
├── settings.gradle.kts        # include :app + :cczukit（指向 ../../CCZUKit/android/cczukit）
├── app/
│   └── src/main/java/com/cczu/helper/
│       ├── MainActivity.kt / HelperApplication.kt
│       ├── di/AppContainer.kt              # 极简 DI
│       ├── data/
│       │   ├── AppSettings.kt              # DataStore：设置 / 教务账号 / 茶楼账号
│       │   ├── CourseModels.kt             # CourseEntity / ScheduleEntity / 配色
│       │   ├── CourseStore.kt              # 课表本地存储（JSON 文件 + StateFlow）
│       │   ├── ClassTime.kt                # 作息时间表（对应 ClassTimeManager）
│       │   ├── CourseTimeCalculator.kt     # ParsedCourse → CourseEntity（合并连续节次）
│       │   ├── IcsConverter.kt             # ICS 导入 / 导出
│       │   ├── SessionManager.kt           # JwqywxApplication 会话与自动重登
│       │   └── UiState.kt
│       ├── supabase/
│       │   ├── SupabaseApi.kt              # OkHttp + Gson 直接调用 PostgREST / GoTrue / 图床
│       │   ├── TeahouseModels.kt
│       │   └── TeahouseRepository.kt
│       └── ui/
│           ├── AppNav.kt / Routes.kt       # 底部四 Tab + NavHost
│           ├── login/LoginScreen.kt
│           ├── schedule/                   # 课表（周视图网格 + 课表管理）
│           ├── services/                   # 成绩 / 绩点 / 考试 / 评价 / 选课 / 电费 / 培养方案
│           ├── teahouse/                   # 帖子列表 / 详情 / 发帖 / 登录 / 我的帖子
│           ├── settings/SettingsScreen.kt
│           └── user/                       # 我的 / 个人信息
└── README.md
```

## 构建

```bash
cd android
export JAVA_HOME=/path/to/jdk-17          # 必须用 JDK 17 或 21，Gradle 8.9 不支持 JDK 22+
export ANDROID_HOME=$HOME/Library/Android/sdk
./gradlew :app:assembleDebug
```

或用 Android Studio 打开 `android/` 目录（Gradle JDK 选择 17/21）。
`local.properties` 已写入本机 SDK 路径，换机器需重新生成。

版本栈：AGP 8.7.3 / Gradle 8.9 / Kotlin 2.0.21 / Compose BOM 2024.12.01 / compileSdk 35 / minSdk 26。

## 与 iOS 版的对应关系

| iOS（Swift） | Android（Kotlin） |
|---|---|
| `AppSettings`（UserDefaults） | `SettingsRepository`（DataStore） |
| `Course` / `Schedule`（SwiftData） | `CourseEntity` / `ScheduleEntity` + `CourseStore`（JSON） |
| `ClassTimeManager` | `ClassTimeManager`（Kotlin object） |
| `CourseTimeCalculator` | `CourseTimeCalculator` |
| `ICSConverter` | `IcsConverter` |
| `AppSettings.configureJwqywx` | `SessionManager.configure` |
| `CCZUKit`（Swift，URLSession） | `:cczukit`（Kotlin，OkHttp） |
| `Supabase` Swift SDK | `SupabaseApi`（OkHttp + Gson 直连 REST） |
| `AuthViewModel` | `TeahouseRepository` + `TeahouseLoginScreen` |
| SwiftUI `TabView` | Compose `NavigationBar` + `NavHost` |
| SwiftUI 课表网格 | `ScheduleGrid`（BoxWithConstraints + offset 布局） |

## 已移植

- 教务登录（含启动自动恢复凭据）、个人信息
- 课表周视图（周次筛选、重叠课程并排、当前时间线、时间标尺、节次/标准时间两种模式）
- 课表管理（多课表、切换、删除、ICS 导入导出）
- 成绩查询、学分绩点、考试安排、一键评价（默认 90 分 / [100,80,100,80,100,80]）
- 选课 / 退课、培养方案、电费查询
- 茶楼：帖子列表 / 搜索 / 详情 / 评论 / 点赞 / 发帖（含图片上传）/ 我的帖子 / 登录注册
- 设置：周起始日、时间轴模式、网格线、透明度、学期开始日、提醒开关

## 未移植（Apple 平台专属，无 Android 对应）

- WidgetKit 桌面小组件、ActivityKit 灵动岛、AppIntents / Siri 快捷指令
- StoreKit 会员内购、`FoundationModels` 端侧摘要
- iCloud Keychain 跨设备同步（改为本地 DataStore 存储凭据）
- WatchConnectivity 手表同步、系统日历写入（EventKit）
- 竞赛查询（HTML WebView）、体测成绩、教务通知

> 这些功能要么依赖 Apple 私有框架，要么需要额外的后端/网页解析实现，
> 建议后续按 Android 原生方案（AppWidget、通知渠道、Google Play Billing）单独补齐。

## 已知取舍

1. **凭据存储**：教务账号密码存在 DataStore 明文文件里（iOS 版存 iCloud Keychain）。
   如需更高安全性，可替换为 `androidx.security:security-crypto` 的 EncryptedSharedPreferences。
2. **本地持久化**：课表用 JSON 文件而非 Room，数据结构简单、避免 KSP 版本耦合；
   若后续要做复杂查询可迁移到 Room。
3. **明文流量**：教务 / 电费接口是 http，已通过 `network_security_config.xml` 全局放开，
   上架前建议改成按域名白名单。
4. **Supabase**：未引入 supabase-kt，直接走 REST，依赖更少、版本风险更低。
