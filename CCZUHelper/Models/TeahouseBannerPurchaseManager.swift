//
//  TeahouseBannerPurchaseManager.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/2/23.
//

import SwiftUI
#if canImport(StoreKit)
import StoreKit
#endif

/// 茶楼横幅购买管理器 - 处理 IAP 逻辑
final class TeahouseBannerPurchaseManager {
    
    static let shared = TeahouseBannerPurchaseManager()
    
    private init() {}
    
    /// 检查是否有隐藏横幅的权利
    func checkBannerHideEntitlement() async -> Bool {
#if canImport(StoreKit)
        let productIds = InAppPurchaseProducts.teahouseHideBannersCandidates
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            guard productIds.contains(transaction.productID) else { continue }
            if transaction.revocationDate != nil { continue }
            if let expirationDate = transaction.expirationDate, expirationDate < Date() { continue }
            return true
        }
#endif
        return false
    }
    
    /// 购买隐藏横幅功能
    func purchaseBannerHide() async -> PurchaseResult {
#if canImport(StoreKit)
        do {
            let productIds = InAppPurchaseProducts.teahouseHideBannersCandidates
            let unavailableMsg = "teahouse.hide_banners.product_unavailable".localized
            let verificationFailedMsg = "teahouse.hide_banners.purchase_verification_failed".localized
            let pendingMsg = "teahouse.hide_banners.purchase_pending".localized
            let failedMsg = "teahouse.hide_banners.purchase_failed".localized
            
            let products = try await Product.products(for: productIds)
            let product = productIds
                .compactMap { id in products.first(where: { $0.id == id }) }
                .first
            
            guard let product else {
                return .error(unavailableMsg)
            }

#if os(visionOS)
            return .error(failedMsg)
#else
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return .error(verificationFailedMsg)
                }
                await transaction.finish()
                return .success
                
            case .pending:
                return .error(pendingMsg)
                
            case .userCancelled:
                return .cancelled
                
            @unknown default:
                return .error(failedMsg)
            }
#endif
        } catch {
            return .error(error.localizedDescription)
        }
#else
        return .error("IAP not available")
#endif
    }
    
    /// 恢复之前的购买
    func restorePurchases() async -> PurchaseResult {
#if canImport(StoreKit)
        do {
            try await AppStore.sync()
            let hasPurchase = await checkBannerHideEntitlement()
            if hasPurchase {
                return .success
            } else {
                let notFoundMsg = "teahouse.hide_banners.restore_not_found".localized
                return .error(notFoundMsg)
            }
        } catch {
            let failedMsg = "teahouse.hide_banners.restore_failed".localized
            return .error(failedMsg)
        }
#else
        return .error("IAP not available")
#endif
    }
    
    /// 刷新购买状态
    func refreshPurchaseStatus() async -> Bool {
        let hasEntitlement = await checkBannerHideEntitlement()
        return hasEntitlement
    }
}

/// 购买结果
enum PurchaseResult {
    case success
    case cancelled
    case error(String)
    
    var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }
}
