//
//  BannerCard.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/17.
//

import SwiftUI

struct BannerCard: View {
    let banner: ActiveBanner
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if #available(iOS 26.0, macOS 15.0, *) {
                    Text(banner.title ?? "")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(banner.content ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(banner.title ?? "")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(banner.content ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            
            Text("\(dateLabel(for: banner.startDate)) - \(dateLabel(for: banner.endDate))")
                .font(.caption)
                .foregroundStyle(
                    {
                        if #available(iOS 26.0, macOS 15.0, *) {
                            return AnyShapeStyle(.secondary)
                        } else {
                            return AnyShapeStyle(.white.opacity(0.8))
                        }
                    }()
                )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Group {
                #if os(visionOS)
                // visionOS: 使用原有有色背景，避免 glassEffect 不可用
                color(from: banner.color ?? "#007AFF")
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                #else
                if #available(iOS 26.0, macOS 26.0, *) {
                    // 无颜色液态玻璃（iOS/macOS）
                    RoundedRectangle(cornerRadius: 14)
                        .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 14))
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                } else {
                    // 旧系统回退到原有有色背景
                    color(from: banner.color ?? "#007AFF")
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                #endif
            }
        )
    }

    private func dateLabel(for date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
    }

    private func color(from hex: String) -> Color {
        var hexString = hex.replacingOccurrences(of: "#", with: "")
        if hexString.count == 6 {
            hexString.append("FF")
        }
        guard let value = UInt64(hexString, radix: 16) else { return .blue }
        let r = Double((value & 0xFF000000) >> 24) / 255
        let g = Double((value & 0x00FF0000) >> 16) / 255
        let b = Double((value & 0x0000FF00) >> 8) / 255
        let a = Double(value & 0x000000FF) / 255
        return Color(red: r, green: g, blue: b, opacity: a)
    }
}

// 横幅轮播
struct BannerCarousel: View {
    let banners: [ActiveBanner]
    @State private var currentIndex = 0
    @State private var autoScrollTimer: Timer?
    private let interactionInset: CGFloat = 8

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(banners.indices, id: \.self) { index in
                BannerCard(banner: banners[index])
                    .padding(.horizontal, interactionInset)
                    .padding(.vertical, 4)
                    .tag(index)
            }
        }
        // 预留交互放大量，避免 interactive 按压时被分页容器裁剪
        .frame(height: 140)
        #if os(macOS)
        .tabViewStyle(.automatic)
        #else
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        #endif
        .onAppear {
            startAutoScroll()
        }
        .onDisappear {
            stopAutoScroll()
        }
    }

    private func startAutoScroll() {
        stopAutoScroll()
        guard banners.count > 1 else { return }
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            withAnimation {
                currentIndex = (currentIndex + 1) % banners.count
            }
        }
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }

    private func color(from hex: String) -> Color {
        var hexString = hex.replacingOccurrences(of: "#", with: "")
        if hexString.count == 6 {
            hexString.append("FF")
        }
        guard let value = UInt64(hexString, radix: 16) else { return .blue }
        let r = Double((value & 0xFF000000) >> 24) / 255
        let g = Double((value & 0x00FF0000) >> 16) / 255
        let b = Double((value & 0x0000FF00) >> 8) / 255
        let a = Double(value & 0x000000FF) / 255
        return Color(red: r, green: g, blue: b, opacity: a)
    }

    private func dateLabel(for date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
    }
}
