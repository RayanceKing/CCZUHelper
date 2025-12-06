//
//  CCZUHelperShortcuts.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/6.
//

import AppIntents

/// CCZUHelper 快捷指令提供者
struct CCZUHelperShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetTodayScheduleIntent(),
            phrases: [
                "Get my \(.applicationName) schedule for today",
                "Show today's classes in \(.applicationName)",
                "What classes do I have today in \(.applicationName)",
                "\(.applicationName)今天有什么课",
                "\(.applicationName)今天的课程"
            ],
            shortTitle: "Today's Schedule",
            systemImageName: "calendar.badge.clock"
        )
        
        AppShortcut(
            intent: GetTomorrowScheduleIntent(),
            phrases: [
                "Get my \(.applicationName) schedule for tomorrow",
                "Show tomorrow's classes in \(.applicationName)",
                "\(.applicationName)明天有什么课",
                "\(.applicationName)明天的课程"
            ],
            shortTitle: "Tomorrow's Schedule",
            systemImageName: "calendar"
        )
        
        AppShortcut(
            intent: GetNextClassIntent(),
            phrases: [
                "Get my next class in \(.applicationName)",
                "When is my next class in \(.applicationName)",
                "\(.applicationName)下一节课",
                "\(.applicationName)下节课是什么"
            ],
            shortTitle: "Next Class",
            systemImageName: "clock"
        )
        
        AppShortcut(
            intent: HasClassTodayIntent(),
            phrases: [
                "Do I have class today in \(.applicationName)",
                "Check if I have class in \(.applicationName)",
                "\(.applicationName)今天有课吗",
                "\(.applicationName)今天是否有课"
            ],
            shortTitle: "Has Class Today",
            systemImageName: "questionmark.circle"
        )
        
        AppShortcut(
            intent: GetScheduleIntent(),
            phrases: [
                "Get my \(.applicationName) schedule",
                "Show my classes in \(.applicationName)",
                "\(.applicationName)查看课表",
                "\(.applicationName)我的课表"
            ],
            shortTitle: "Get Schedule",
            systemImageName: "calendar"
        )
        
        AppShortcut(
            intent: GetExamScheduleIntent(),
            phrases: [
                "Get my \(.applicationName) exams",
                "Show my exam schedule in \(.applicationName)",
                "\(.applicationName)考试安排",
                "\(.applicationName)查看考试"
            ],
            shortTitle: "Get Exams",
            systemImageName: "doc.text.magnifyingglass"
        )
        
        AppShortcut(
            intent: GetGradesIntent(),
            phrases: [
                "Get my \(.applicationName) grades",
                "Show my grades in \(.applicationName)",
                "\(.applicationName)我的成绩",
                "\(.applicationName)查看成绩"
            ],
            shortTitle: "Get Grades",
            systemImageName: "chart.bar.doc.horizontal"
        )
        
        AppShortcut(
            intent: GetGPAIntent(),
            phrases: [
                "Get my \(.applicationName) GPA",
                "Show my GPA in \(.applicationName)",
                "\(.applicationName)我的绩点",
                "\(.applicationName)查看GPA"
            ],
            shortTitle: "Get GPA",
            systemImageName: "star.circle"
        )
        
        AppShortcut(
            intent: OpenScheduleIntent(),
            phrases: [
                "Open schedule in \(.applicationName)",
                "\(.applicationName)打开课表",
                "\(.applicationName)打开课程表"
            ],
            shortTitle: "Open Schedule",
            systemImageName: "calendar.badge.plus"
        )
        
        AppShortcut(
            intent: OpenGradesIntent(),
            phrases: [
                "Open grades in \(.applicationName)",
                "\(.applicationName)打开成绩",
                "\(.applicationName)打开成绩查询"
            ],
            shortTitle: "Open Grades",
            systemImageName: "chart.bar.xaxis"
        )
    }
}
