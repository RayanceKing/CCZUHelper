  //
  //  OtherSettingsSections.swift
  //  CCZUHelper
  //
  //  Created by rayanceking on 2026/2/23.
  //

  import SwiftUI
  #if canImport(StoreKit)
  import StoreKit
  #endif

  /// 其他功能和账户操作部分
  struct OtherSettingsSections: View {
      @Environment(AppSettings.self) private var settings
      @State private var showMembershipPurchaseSheet = false
      @State private var isPurchasing = false
      @State private var isRestoring = false
      @State private var isLoadingProduct = false
      @State private var productDisplayPrice: String?
      @State private var showErrorAlert = false
      @State private var errorMessage = ""

      #if os(macOS)
      let onSelectNotifications: () -> Void
      #else
      let onNavigateToNotifications: () -> Void
      #endif

      @Binding var showLogoutConfirmation: Bool
      @Environment(\.dismiss) private var dismiss

      var body: some View {
          Group {
              // 其他功能
              otherFunctionsSection

              // 账户操作
              accountActionsSection
          }
          .sheet(isPresented: $showMembershipPurchaseSheet) {
              MembershipPurchaseView()
                  .environment(settings)
          }
          .alert("purchase.failed_title".localized, isPresented: $showErrorAlert) {
              Button("common.ok".localized, role: .cancel) {}
          } message: {
              Text(errorMessage)
          }
          .task {
              await loadProductPrice()
          }
      }

      private var otherFunctionsSection: some View {
          Section {
              #if os(macOS)
              Button(action: onSelectNotifications) {
                  Label("settings.notifications".localized, systemImage: "bell")
                      .frame(maxWidth: .infinity, alignment: .leading)
              }
              .buttonStyle(.plain)
              #else
              NavigationLink {
                  NotificationSettingsView().environment(settings)
              } label: {
                  Label("settings.notifications".localized, systemImage: "bell")
              }
              #endif

              Toggle(
                  isOn: Binding(
                      get: { settings.enableICloudDataSync },
                      set: { newValue in
                          if newValue && !settings.hasPurchase {
                              settings.enableICloudDataSync = false
                              showMembershipPurchaseSheet = true
                          } else {
                              settings.enableICloudDataSync = newValue
                          }
                      }
                  )
              ) {
                  Label("settings.icloud_data_sync".localized, systemImage: "icloud")
              }

              Text("settings.icloud_data_sync_hint".localized)
                  .font(.caption)
                  .foregroundStyle(.secondary)

              // 购买按钮区域
              purchaseButtonsSection
          } header: {
              Text("settings.other".localized)
          }
      }

      private var purchaseButtonsSection: some View {
          VStack(spacing: 12) {
              // 未购买时显示立即购买按钮
              if !settings.hasPurchase {
                  Button(action: { Task { await purchase() } }) {
                      Text(
                          productDisplayPrice.map {
                              "\("purchase.buy_now".localized) (\($0))"
                          } ?? "purchase.buy_now".localized
                      )
                  }
                  .disabled(isPurchasing || isLoadingProduct || settings.hasPurchase)
              }

              // 恢复购买按钮 - 与茶馆账户样式一致
              Button(action: { Task { await restore() } }) {
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
          .padding(.vertical, 8)
      }

      private var accountActionsSection: some View {
          Section {
              if settings.isLoggedIn {
                  Button(role: .destructive, action: {
                      showLogoutConfirmation = true
                  }) {
                      HStack {
                          Spacer()
                          Text("settings.logout".localized)
                          Spacer()
                      }
                  }
                  .alert("settings.logout_confirm_title".localized, isPresented: $showLogoutConfirmation) {
                      Button("common.cancel".localized, role: .cancel) { }
                      Button("settings.logout".localized, role: .destructive) {
                          settings.logout()
                          #if os(macOS)
                          NSApp.terminate(nil)
                          #else
                          dismiss()
                          #endif
                      }
                  } message: {
                      Text("settings.logout_confirm_message".localized)
                  }
              }
          }
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
          case .cancelled:
              break
          case .error(let message):
              errorMessage = message
              showErrorAlert = true
          }
      }
  }

  #if os(macOS)
  #Preview {
      OtherSettingsSections(
          onSelectNotifications: {},
          showLogoutConfirmation: .constant(false)
      )
      .environment(AppSettings())
  }
  #else
  #Preview {
      OtherSettingsSections(
          onNavigateToNotifications: {},
          showLogoutConfirmation: .constant(false)
      )
      .environment(AppSettings())
  }
  #endif
