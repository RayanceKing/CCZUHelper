//
//  PostDetailImagePreviewView.swift
//  CCZUHelper
//
//  Created by Codex on 2026/2/23.
//

import SwiftUI
import Kingfisher
import Photos

#if canImport(UIKit)
import UIKit
#endif

struct ImagePreviewView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.displayScale) private var displayScale
    let url: URL

    @State private var uiImage: PostDetailPlatformImage? = nil
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isSaving: Bool = false
    @State private var showSaveSuccess: Bool = false
    @State private var showSaveError: Bool = false
    @State private var saveErrorMessage: String = ""
    @State private var showShareSheet: Bool = false
    @State private var shareItems: [Any] = []

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            GeometryReader { proxy in
                let maxW = proxy.size.width
                let maxH = proxy.size.height

                ZStack {
                    KFImage(url)
                        .downsampling(size: CGSize(width: max(1, maxW), height: max(1, maxH)))
                        .scaleFactor(displayScale)
                        .cancelOnDisappear(true)
                        .placeholder {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .retry(maxCount: 2, interval: .seconds(2))
                        .onSuccess { result in
#if canImport(UIKit)
                            uiImage = result.image
#endif
                        }
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: maxW, maxHeight: maxH)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let newScale = lastScale * value
                                        scale = max(1.0, min(newScale, 6.0))
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                    },
                                DragGesture()
                                    .onChanged { v in
                                        offset = CGSize(width: lastOffset.width + v.translation.width, height: lastOffset.height + v.translation.height)
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1.1 {
                                    scale = 1.0
                                    lastScale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.0
                                    lastScale = 2.0
                                }
                            }
                        }
                        .contextMenu {
                            Button {
#if canImport(UIKit)
                                if let image = uiImage {
                                    shareItems = [image]
                                } else {
                                    shareItems = [url]
                                }
                                showShareSheet = true
#endif
                            } label: {
                                Label("teahouse.image.menu.share".localized, systemImage: "square.and.arrow.up")
                            }

                            Button {
                                Task { await saveImageAction() }
                            } label: {
                                Label("teahouse.image.menu.save_to_photos".localized, systemImage: "square.and.arrow.down")
                            }

                            Button {
#if canImport(UIKit)
                                if let image = uiImage {
                                    UIPasteboard.general.image = image
                                } else {
                                    UIPasteboard.general.string = url.absoluteString
                                }
#endif
                            } label: {
                                Label("teahouse.image.menu.copy".localized, systemImage: "doc.on.doc")
                            }

                            Button {
                                // not supported yet
                            } label: {
                                Label("teahouse.image.menu.copy_subject".localized, systemImage: "circle.dashed.rectangle")
                            }
                            .disabled(true)

                            Button {
                                // not supported yet
                            } label: {
                                Label("teahouse.image.menu.lookup".localized, systemImage: "magnifyingglass")
                            }
                            .disabled(true)
                        } preview: {
                            KFImage(url)
                                .downsampling(size: CGSize(width: 280, height: 220))
                                .scaleFactor(displayScale)
                                .cancelOnDisappear(true)
                                .placeholder {
                                    ZStack {
                                        Color.secondary.opacity(0.08)
                                        ProgressView()
                                    }
                                }
                                .retry(maxCount: 2, interval: .seconds(2))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 280, height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                }
                .frame(maxWidth: maxW, maxHeight: maxH)
            }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .padding(16)
            }
        }
        .onDisappear {
            uiImage = nil
            shareItems.removeAll()
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
        }
        .overlay {
            if isSaving {
                ProgressView {
                    Text("teahouse.saving".localized)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
#if canImport(UIKit)
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: shareItems)
        }
#endif
        .alert(Text("teahouse.save_success"), isPresented: $showSaveSuccess) {
            Button(role: .cancel) { } label: { Text("common.ok".localized) }
        }
        .alert(Text("teahouse.save_failed"), isPresented: $showSaveError) {
            Button(role: .cancel) { } label: { Text("common.ok".localized) }
        } message: {
            Text(saveErrorMessage)
        }
    }

    private func saveImageAction() async {
        guard let image = uiImage else {
            saveErrorMessage = "teahouse.image.error.image_not_loaded".localized
            showSaveError = true
            return
        }
        await MainActor.run { isSaving = true }
        do {
            try await requestAndSave(image: image)
            await MainActor.run {
                isSaving = false
                showSaveSuccess = true
            }
        } catch {
            await MainActor.run {
                isSaving = false
                saveErrorMessage = error.localizedDescription
                showSaveError = true
            }
        }
    }

    private func requestAndSave(image: PostDetailPlatformImage) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                switch status {
                case .authorized, .limited:
                    continuation.resume(returning: ())
                case .denied, .restricted, .notDetermined:
                    continuation.resume(
                        throwing: NSError(
                            domain: "Teahouse",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "teahouse.image.error.photo_permission_denied".localized]
                        )
                    )
                @unknown default:
                    continuation.resume(
                        throwing: NSError(
                            domain: "Teahouse",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "teahouse.image.error.photo_permission_unknown".localized]
                        )
                    )
                }
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }, completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "Teahouse",
                            code: 3,
                            userInfo: [NSLocalizedDescriptionKey: "teahouse.image.error.save_failed".localized]
                        )
                    )
                }
            })
        }
    }
}

