//
//  UserMenuButton.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/3.
//

import SwiftUI

/// 用户菜单按钮组件
struct UserMenuButton: View {
    @Environment(AppSettings.self) private var settings
    @Binding var showManageSchedules: Bool
    @Binding var showLoginSheet: Bool
    @Binding var showImagePicker: Bool
    
    var body: some View {
        Menu {
            // 课程表设置
            Menu {
                Button(action: { showManageSchedules = true }) {
                    Label("管理课表", systemImage: "list.bullet")
                }
                
                Divider()
                
                // 日历开始时间
                Menu {
                    ForEach(6...12, id: \.self) { hour in
                        Button("\(hour):00") {
                            settings.calendarStartHour = hour
                        }
                    }
                } label: {
                    Label("日历开始时间: \(settings.calendarStartHour):00", systemImage: "clock")
                }
                
                // 日历结束时间
                Menu {
                    ForEach(18...23, id: \.self) { hour in
                        Button("\(hour):00") {
                            settings.calendarEndHour = hour
                        }
                    }
                } label: {
                    Label("日历结束时间: \(settings.calendarEndHour):00", systemImage: "clock.fill")
                }
                
                Divider()
                
                Toggle(isOn: Binding(
                    get: { settings.showGridLines },
                    set: { settings.showGridLines = $0 }
                )) {
                    Label("显示分割线", systemImage: "squareshape.split.3x3")
                }
                
                Toggle(isOn: Binding(
                    get: { settings.showTimeRuler },
                    set: { settings.showTimeRuler = $0 }
                )) {
                    Label("显示时间标尺", systemImage: "ruler")
                }
                
                Toggle(isOn: Binding(
                    get: { settings.showAllDayEvents },
                    set: { settings.showAllDayEvents = $0 }
                )) {
                    Label("显示全天日程", systemImage: "calendar.day.timeline.left")
                }
                
                Divider()
                
                // 时间间隔
                Menu {
                    ForEach(AppSettings.TimeInterval.allCases, id: \.rawValue) { interval in
                        Button(interval.displayName) {
                            settings.timeInterval = interval
                        }
                    }
                } label: {
                    Label("时间间隔: \(settings.timeInterval.displayName)", systemImage: "timer")
                }
                
                // 课程块透明度
                Menu {
                    ForEach([0.5, 0.6, 0.7, 0.8, 0.9, 1.0], id: \.self) { opacity in
                        Button("\(Int(opacity * 100))%") {
                            settings.courseBlockOpacity = opacity
                        }
                    }
                } label: {
                    Label("课程块透明度: \(Int(settings.courseBlockOpacity * 100))%", systemImage: "square.fill")
                }
                
                Divider()
                
                Toggle(isOn: Binding(
                    get: { settings.backgroundImageEnabled },
                    set: { newValue in
                        settings.backgroundImageEnabled = newValue
                        if newValue {
                            showImagePicker = true
                        }
                    }
                )) {
                    Label("开启背景图片", systemImage: "photo")
                }
                
            } label: {
                Label("课程表设置", systemImage: "gearshape")
            }
            
            Button(action: {}) {
                Label("通知", systemImage: "bell")
            }
            
            // 主题设置
            Menu {
                ForEach(AppSettings.ThemeMode.allCases, id: \.rawValue) { mode in
                    Button(action: { settings.themeMode = mode }) {
                        HStack {
                            Text(mode.rawValue)
                            if settings.themeMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("主题设置", systemImage: "paintbrush")
            }
            
            Divider()
            
            if settings.isLoggedIn {
                Button(role: .destructive, action: { settings.logout() }) {
                    Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } else {
                Button(action: { showLoginSheet = true }) {
                    Label("登录", systemImage: "person.circle")
                }
            }
            
        } label: {
            if settings.isLoggedIn {
                // 已登录显示用户头像
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(.blue)
            } else {
                // 未登录显示默认图标
                Image(systemName: "person.crop.circle.badge.xmark")
                    .font(.title2)
                    .foregroundStyle(.gray)
            }
        }
    }
}

#Preview {
    UserMenuButton(
        showManageSchedules: .constant(false),
        showLoginSheet: .constant(false),
        showImagePicker: .constant(false)
    )
    .environment(AppSettings())
}
