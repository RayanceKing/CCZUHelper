//
//  MembershipPurchaseView.swift
//  CCZUHelper
//
//  Created by Codex on 2026/2/23.
//

import SwiftUI
#if canImport(StoreKit)
import StoreKit
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct MembershipPurchaseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    @State private var isLoadingProduct = false
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var productDisplayPrice: String?
    @State private var showConfetti = false

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if settings.hasPurchase {
                                purchasedStatusView
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                    .padding(.bottom, 20)
                            }

                            featureCard(
                                icon: "rectangle.on.rectangle.slash",
                                title: "teahouse.hide_banners".localized,
                                subtitle: "teahouse.hide_banners.description".localized
                            )
                            featureCard(
                                icon: "icloud",
                                title: "settings.icloud_data_sync".localized,
                                subtitle: "settings.icloud_data_sync_hint".localized
                            )
                            featureCard(
                                icon: "app.badge.fill",
                                title: "settings.enable_live_activity".localized,
                                subtitle: "settings.course_notification".localized
                            )

                            if !settings.hasPurchase {
                                VStack(spacing: 12) {
                                    purchaseButton
                                    restoreButton
                                }
                                .padding(.bottom, 20)
                            }
                        }
                        .padding(20)
                    }

                    if settings.hasPurchase {
                        VStack(spacing: 12) {
                            Text("purchase.more_coming".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                            restoreButton
                        }
                        .padding()
                        .background(adaptiveBackgroundColor)
                    }
                }

                if showConfetti {
                    ConfettiView()
                        .transition(.opacity)
                }
            }
            .navigationTitle("purchase.title".localized)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
            .task {
                await loadProductPrice()
                let wasPurchased = settings.hasPurchase
                _ = await MembershipManager.shared.refreshEntitlement(settings: settings)
                let isNowPurchased = settings.hasPurchase
                if !wasPurchased && isNowPurchased {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showConfetti = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showConfetti = false
                        }
                    }
                }
            }
            .alert("purchase.failed_title".localized, isPresented: $showErrorAlert) {
                Button("common.ok".localized, role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var purchaseButton: some View {
        Button(action: { Task { await purchase() } }) {
            HStack {
                if isPurchasing || isLoadingProduct {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text(
                        productDisplayPrice.map { "\("purchase.buy_now".localized) (\($0))" }
                            ?? "purchase.buy_now".localized
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .modifier(PurchasePrimaryButtonStyle())
        .disabled(isPurchasing || isLoadingProduct || settings.hasPurchase)
    }

    private var restoreButton: some View {
        Button(action: { Task { await restore() } }) {
            HStack {
                if isRestoring {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Text("purchase.restore".localized)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .buttonBorderShape(.automatic)
        .disabled(isPurchasing || isRestoring)
    }

    private var purchasedStatusView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(privilegeGradient)
            Text("purchase.purchased".localized)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(privilegeGradient)
        }
    }

    private var privilegeGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "#528BF3") ?? .blue,
                Color(hex: "#9A6DE0") ?? .purple,
                Color(hex: "#E14A70") ?? .red,
                Color(hex: "#F08D3B") ?? .orange
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var adaptiveBackgroundColor: Color {
        #if canImport(UIKit)
        return Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return .clear
        #endif
    }

    private func featureCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 30, height: 30)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @MainActor
    private func loadProductPrice() async {
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        do {
            #if canImport(StoreKit)
            let product = try await MembershipManager.shared.fetchProProduct()
            productDisplayPrice = product?.displayPrice
            #else
            productDisplayPrice = nil
            #endif
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    @MainActor
    private func purchase() async {
        isPurchasing = true
        defer { isPurchasing = false }
        let result = await MembershipManager.shared.purchasePro()
        switch result {
        case .success:
            _ = await MembershipManager.shared.refreshEntitlement(settings: settings)
            dismiss()
        case .cancelled:
            break
        case .error(let message):
            errorMessage = message
            showErrorAlert = true
        }
    }

    @MainActor
    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        let result = await MembershipManager.shared.restorePurchases()
        switch result {
        case .success:
            _ = await MembershipManager.shared.refreshEntitlement(settings: settings)
            dismiss()
        case .cancelled:
            break
        case .error(let message):
            errorMessage = message
            showErrorAlert = true
        }
    }
}

private struct PurchasePrimaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if os(visionOS)
        content
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .buttonBorderShape(.automatic)
        #else
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .buttonBorderShape(.automatic)
        } else {
            content
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .buttonBorderShape(.automatic)
        }
        #endif
    }
}

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .offset(x: particle.position.x, y: particle.position.y)
                        .opacity(particle.opacity)
                        .rotationEffect(.degrees(particle.rotation.degrees))
                }
            }
            .onAppear {
                generateParticles(in: geometry.size)
            }
        }
        .allowsHitTesting(false)
    }

    private func generateParticles(in size: CGSize) {
        let colors: [Color] = [
            Color(hex: "#528BF3") ?? .blue,
            Color(hex: "#9A6DE0") ?? .purple,
            Color(hex: "#E14A70") ?? .red,
            Color(hex: "#F08D3B") ?? .orange,
            Color(hex: "#4CD964") ?? .green,
            Color(hex: "#FFCC00") ?? .yellow
        ]

        for _ in 0..<100 {
            let particle = ConfettiParticle(
                id: UUID(),
                color: colors.randomElement() ?? .blue,
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: -size.height...0)
                ),
                size: CGFloat.random(in: 5...15),
                opacity: Double.random(in: 0.6...1.0),
                rotation: Angle(degrees: Double.random(in: 0...360))
            )
            particles.append(particle)
        }

        withAnimation(.easeOut(duration: 2.5)) {
            for index in particles.indices {
                particles[index].position.y += size.height + 200
                particles[index].rotation += Angle(degrees: Double.random(in: 180...720))
                particles[index].opacity = 0
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id: UUID
    let color: Color
    var position: CGPoint
    let size: CGFloat
    var opacity: Double
    var rotation: Angle
}

// MARK: - 购买控制组件

struct TeahouseBannerPurchaseControls: View {
    let hideBannerBinding: Binding<Bool>
    let isPurchasing: Bool
    let isRestoring: Bool
    let onPurchase: () -> Void
    let onRestore: () -> Void

    var body: some View {
        Toggle(isOn: hideBannerBinding) {
            VStack(alignment: .leading, spacing: 4) {
                Text("teahouse.hide_banners".localized)
                Text("teahouse.hide_banners.description".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .disabled(isPurchasing || isRestoring)

        Button(action: onPurchase) {
            Text("purchase.buy_now".localized)
        }
        .disabled(isPurchasing || isRestoring)

        Button(action: onRestore) {
            HStack {
                Text("purchase.restore".localized)
                if isRestoring {
                    Spacer()
                    ProgressView()
                }
            }
        }
        .disabled(isRestoring || isPurchasing)
    }
}

