//
//  ServicesView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI

/// 服务视图
struct ServicesView: View {
    @Environment(AppSettings.self) private var settings
    
    @State private var showGradeQuery = false
    @State private var showExamSchedule = false
    @State private var showEmptyClassroom = false
    @State private var showCreditGPA = false
    
    private let services: [ServiceItem] = [
        ServiceItem(title: "成绩查询", icon: "chart.bar.doc.horizontal", color: .blue),
        ServiceItem(title: "学分绩点", icon: "star.circle", color: .orange),
        ServiceItem(title: "考试安排", icon: "calendar.badge.clock", color: .purple),
        ServiceItem(title: "空闲教室", icon: "building.2", color: .green),
        ServiceItem(title: "图书馆", icon: "books.vertical", color: .brown),
        ServiceItem(title: "校园卡", icon: "creditcard", color: .pink),
        ServiceItem(title: "校园网", icon: "wifi", color: .cyan),
        ServiceItem(title: "更多服务", icon: "ellipsis.circle", color: .gray),
    ]
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 服务网格
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(services) { service in
                            Button(action: {
                                handleServiceTap(service.title)
                            }) {
                                ServiceButton(item: service)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    
                    // 常用功能
                    VStack(alignment: .leading, spacing: 12) {
                        Text("常用功能")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            ServiceRow(title: "教务通知", icon: "bell.badge", hasNew: true)
                            Divider().padding(.leading, 50)
                            ServiceRow(title: "课程评价", icon: "hand.thumbsup")
                            Divider().padding(.leading, 50)
                            ServiceRow(title: "选课系统", icon: "checklist")
                            Divider().padding(.leading, 50)
                            ServiceRow(title: "培养方案", icon: "doc.text")
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                    
                    // 快捷入口
                    VStack(alignment: .leading, spacing: 12) {
                        Text("快捷入口")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                QuickLink(title: "教务系统", icon: "globe", color: .blue, url: URL(string: "http://jwqywx.cczu.edu.cn/"))
                                QuickLink(title: "邮件系统", icon: "envelope", color: .orange, url: URL(string: "https://www.cczu.edu.cn/yxxt/list.htm"))
                                QuickLink(title: "VPN", icon: "network", color: .green, url: URL(string: "https://zmvpn.cczu.edu.cn"))
                                QuickLink(title: "智慧校园", icon: "building", color: .purple, url: nil)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("服务")
            .background(Color(.systemGroupedBackground))
            .ignoresSafeArea(.container, edges: .bottom)
            .sheet(isPresented: $showGradeQuery) {
                GradeQueryView()
                    .environment(settings)
            }
            .sheet(isPresented: $showExamSchedule) {
                ExamScheduleView()
                    .environment(settings)
            }
            .sheet(isPresented: $showEmptyClassroom) {
                EmptyClassroomView()
            }
            .sheet(isPresented: $showCreditGPA) {
                CreditGPAView()
                    .environment(settings)
            }
        }
    }
    
    private func handleServiceTap(_ title: String) {
        switch title {
        case "成绩查询":
            showGradeQuery = true
        case "学分绩点":
            showCreditGPA = true
        case "考试安排":
            showExamSchedule = true
        case "空闲教室":
            showEmptyClassroom = true
        default:
            // 其他服务待实现
            break
        }
    }
}

/// 服务项目模型
struct ServiceItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
}

/// 服务按钮
struct ServiceButton: View {
    let item: ServiceItem
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: item.icon)
                .font(.title)
                .foregroundStyle(item.color)
                .frame(width: 50, height: 50)
                .background(item.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Text(item.title)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }
}

/// 服务行
struct ServiceRow: View {
    let title: String
    let icon: String
    var hasNew: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            if hasNew {
                Text("NEW")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .contentShape(Rectangle())
    }
}

/// 快捷链接
struct QuickLink: View {
    @Environment(\.openURL) private var openURL
    
    let title: String
    let icon: String
    let color: Color
    var url: URL?
    
    var body: some View {
        Button(action: {
            if let url = url {
                openURL(url)
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ServicesView()
        .environment(AppSettings())
}
