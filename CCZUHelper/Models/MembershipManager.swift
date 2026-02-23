//
//  MembershipManager.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/2/23.
//

import Foundation

#if canImport(StoreKit)
import StoreKit
#endif

// MARK: - 购买结果

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

// MARK: - 会员管理器

@MainActor
final class MembershipManager {
    static let shared = MembershipManager()

    private init() {}

    func checkProEntitlement() async -> Bool {
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

    func fetchProProduct() async throws -> Product? {
#if canImport(StoreKit)
        let productIds = InAppPurchaseProducts.teahouseHideBannersCandidates
        let products = try await Product.products(for: productIds)
        return productIds.compactMap { id in products.first(where: { $0.id == id }) }.first
#else
        return nil
#endif
    }

    func purchasePro() async -> PurchaseResult {
#if canImport(StoreKit)
        do {
            let unavailableMsg = "teahouse.product_unavailable".localized
            let verificationFailedMsg = "teahouse.purchase_verification_failed".localized
            let pendingMsg = "teahouse.purchase_pending".localized
            let failedMsg = "teahouse.purchase_failed".localized

            guard let product = try await fetchProProduct() else {
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

    func restorePurchases() async -> PurchaseResult {
#if canImport(StoreKit)
        do {
            try await AppStore.sync()
            let hasPurchase = await checkProEntitlement()
            return hasPurchase ? .success : .error("restore.not_found".localized)
        } catch {
            return .error("restore.failed".localized)
        }
#else
        return .error("IAP not available")
#endif
    }

    func refreshEntitlement(settings: AppSettings?) async -> Bool {
        let hasEntitlement = await checkProEntitlement()
        guard let settings else { return hasEntitlement }
        settings.hasPurchase = hasEntitlement
        if !hasEntitlement {
            settings.hideTeahouseBanners = false
            settings.enableICloudDataSync = false
            settings.enableLiveActivity = false
        }
        return hasEntitlement
    }

#if canImport(StoreKit)
    func handleTransactionUpdate(_ result: VerificationResult<Transaction>, settings: AppSettings?) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        _ = await refreshEntitlement(settings: settings)
    }
#endif
}
