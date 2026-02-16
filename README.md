<div align="center">
<img width=200 src="AppIcon-iOS-Default-1024x1024@1x.png"  alt="图标"/>

<h3>龙城学伴</h3>
 <img src="https://img.shields.io/badge/Swift-5.9+-orange" alt="Swift"> <img src="https://img.shields.io/badge/Platform-iOS%20%7C%20iPadOS%20%7C%20macOS%20%7C%20watchOS%20%7C%20visionOS-lightgrey" alt="Platform"> <img src="https://img.shields.io/badge/License-GPL--3.0-blue" alt="License">
 </div>

## 简介
龙城学伴 是一款专为常州大学学生设计的跨平台应用。项目采用 SwiftUI 框架和现代 Swift Concurrency (async/await) 开发，通过深度集成 CCZUKit 客户端库，旨在提供一站式的教务服务、课程管理和校园生活辅助功能。数据存储采用 SwiftData 模型。
![宣传图](宣传图.png)

## 主要功能与技术亮点
### 📅 课程表与管理

- 多课表支持：支持从教务系统一键导入课表、管理多个课表实例、并支持 ICS 文件格式的导入和导出。

- 学期设置：可自定义学期开始日期和周起始日。

- 同步集成：一键将课程同步到系统日历 中，并提供课程的本地通知提醒功能。

### 📊 学业数据查询

- 成绩查询：快速查询各学期的课程成绩。

- 绩点计算：计算并展示**学分绩点（GPA）**信息。

- 考试安排：查看本学期的考试时间与地点安排，并提供考试通知提醒。

- 一键评价：支持对未评价课程进行一键评价（默认评分）功能。

- 服务集成：集成教务通知、空闲教室、选课系统和培养方案等常用教务服务。

### ✨ 效率与用户体验

- 快捷指令：完整的 App Intents 支持，可通过 Siri 或快捷指令查询今日/明日课程、下一节课和 GPA 等信息。

- 桌面小组件：提供多种尺寸的课程表桌面小组件（Widget），展示今日课程状态和进度。

- 账号同步：利用 iCloud Keychain 跨设备同步账号和密码，实现安全存储和自动登录恢复。

- 茶楼功能：一个实验性的本地化校园社交/论坛功能，支持发帖和点赞（帖子数据当前本地存储）。

## 核心依赖 CCZUKit
本项目深度依赖 CCZUKit 来处理与常州大学教务系统（WebVPN）的交互。

CCZUKit 是常州大学官方服务的 Swift 客户端库，提供了便捷的 API 访问接口。本项目是 Rust 版本 cczuni 的 Swift 重写版本，专为 Apple 平台优化。

### CCZUKit 特性

✅ SSO 统一登录：支持普通模式和 WebVPN 模式

✅ 教务企业微信：成绩查询、课表查询、学分绩点查询

✅ 课表解析：自动解析课程信息，包括周次、时间、地点

✅ 类型安全：完整的 Swift 类型系统支持

✅ 现代异步：基于 Swift Concurrency (async/await)

✅ 跨平台：支持 iOS、macOS、watchOS、visionOS

系统要求
- iOS 17.0+ / macOS 15.0+ / watchOS 7.0+ / visionOS 26.0+
- Swift 5.9+
- Xcode 17.0+

## 安装
1. 克隆仓库

``` Bash
git clone https://github.com/RayanceKing/CCZUHelper
cd CCZUHelper 
```
2. 添加 CCZUKit 依赖

本项目将 CCZUKit 作为 Swift Package Manager (SPM) 依赖：

- 在 Xcode 中打开项目。

- 导航至 File > Add Packages...。

- 输入 CCZUKit 的仓库 URL：https://github.com/RayanceKing/CCZUKit。

- 选择主分支（main） 并添加。

3. 配置 App Group

- 为确保 App、Widget 和 Watch App 之间的数据共享（group.com.cczu.helper），需要在 Xcode 中配置 App Group。

## 项目结构
- `CCZUHelper/Views`：UI 页面与复用组件。
- `CCZUHelper/Models`：业务模型与服务逻辑。
- `CCZUHelper/AppIntents`：快捷指令与 Siri 相关能力。
- `CCZUHelper/Shared`：跨模块共享代码。
- `CCZUHelper/Shared/Utilities`：通用工具层（如日期格式化、URL 构造），用于减少重复实现与降低业务文件复杂度。
