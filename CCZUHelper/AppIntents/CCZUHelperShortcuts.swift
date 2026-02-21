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
            shortTitle: "intent.short.today_schedule",
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
            shortTitle: "intent.short.tomorrow_schedule",
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
            shortTitle: "intent.short.next_class",
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
            shortTitle: "intent.short.has_class_today",
            systemImageName: "questionmark.circle"
        )
        
        AppShortcut(
            intent: GetScheduleForSpecificDateIntent(),
            phrases: [
                "Get my \(.applicationName) schedule for a date",
                "Show classes in \(.applicationName) on a date",
                "\(.applicationName)查询某天课程",
                "\(.applicationName)查询指定日期课表"
            ],
            shortTitle: "intent.short.schedule_for_date",
            systemImageName: "calendar.badge.magnifyingglass"
        )
        
        AppShortcut(
            intent: GetExamScheduleIntent(),
            phrases: [
                "Get my \(.applicationName) exams",
                "Show my exam schedule in \(.applicationName)",
                "\(.applicationName)考试安排",
                "\(.applicationName)查看考试"
            ],
            shortTitle: "intent.short.get_exams",
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
            shortTitle: "intent.short.get_grades",
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
            shortTitle: "intent.short.get_gpa",
            systemImageName: "star.circle"
        )
        
        AppShortcut(
            intent: OpenScheduleIntent(),
            phrases: [
                "Open schedule in \(.applicationName)",
                "\(.applicationName)打开课表",
                "\(.applicationName)打开课程表"
            ],
            shortTitle: "intent.short.open_schedule",
            systemImageName: "calendar.badge.plus"
        )
        
        AppShortcut(
            intent: OpenGradesIntent(),
            phrases: [
                "Open grades in \(.applicationName)",
                "\(.applicationName)打开成绩",
                "\(.applicationName)打开成绩查询"
            ],
            shortTitle: "intent.short.open_grades",
            systemImageName: "chart.bar.xaxis"
        )
    }
}
