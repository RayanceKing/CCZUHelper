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

#if canImport(VisionKit)
import VisionKit
#endif

#if canImport(Vision)
import Vision
#endif

#if canImport(CoreImage)
import CoreImage
import CoreImage.CIFilterBuiltins
#endif

struct ImagePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale

    let urls: [URL]
    let initialIndex: Int

    @State private var currentIndex: Int
    @State private var imagesByIndex: [Int: PostDetailPlatformImage] = [:]

    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    @State private var showLookupResult = false
    @State private var lookupMessage = ""

    init(urls: [URL], initialIndex: Int = 0) {
        self.urls = urls
        self.initialIndex = initialIndex
        let clamped = min(max(0, initialIndex), max(0, urls.count - 1))
        _currentIndex = State(initialValue: clamped)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if urls.isEmpty {
                Text("teahouse.image.error.image_not_loaded".localized)
                    .foregroundStyle(.white)
            } else {
                GeometryReader { proxy in
                    TabView(selection: $currentIndex) {
                        ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                            ZoomableRemoteImageView(
                                url: url,
                                displayScale: displayScale,
                                canvasSize: proxy.size,
                                onImageLoaded: { loadedImage in
                                    imagesByIndex[index] = loadedImage
                                }
                            )
                            .tag(index)
                            .contextMenu {
                                contextMenu(for: index)
                            } preview: {
                                PostDetailImageMenuPreview(url: url)
                            }
                            .contentShape(Rectangle())
                        }
                    }
#if !os(macOS)
                    .tabViewStyle(.page(indexDisplayMode: .never))
#endif
                }

                if urls.count > 1 {
                    VStack {
                        Spacer()
                        Text("\(currentIndex + 1)/\(urls.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.5), in: Capsule())
                            .padding(.bottom, 28)
                    }
                }
            }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .padding(16)
            }
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
        .alert("Vision", isPresented: $showLookupResult) {
            Button("common.ok".localized, role: .cancel) { }
        } message: {
            Text(lookupMessage)
        }
        .onDisappear {
            imagesByIndex.removeAll()
            shareItems.removeAll()
        }
    }

    @ViewBuilder
    private func contextMenu(for index: Int) -> some View {
        let url = urls[index]

        Button {
#if canImport(UIKit)
            if let image = imagesByIndex[index] {
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
            Task { await saveImageAction(for: index) }
        } label: {
            Label("teahouse.image.menu.save_to_photos".localized, systemImage: "square.and.arrow.down")
        }

        Button {
#if canImport(UIKit)
            if let image = imagesByIndex[index] {
                UIPasteboard.general.image = image
            } else {
                UIPasteboard.general.string = url.absoluteString
            }
#endif
        } label: {
            Label("teahouse.image.menu.copy".localized, systemImage: "doc.on.doc")
        }

        Button {
            Task { await copySubjectAction(for: index) }
        } label: {
            Label("teahouse.image.menu.copy_subject".localized, systemImage: "circle.dashed.rectangle")
        }
        .disabled(!supportsVisionActions || imagesByIndex[index] == nil)

        Button {
            Task { await lookupAction(for: index) }
        } label: {
            Label("teahouse.image.menu.lookup".localized, systemImage: "magnifyingglass")
        }
        .disabled(!supportsVisionActions || imagesByIndex[index] == nil)
    }

    private var supportsVisionActions: Bool {
#if canImport(UIKit) && canImport(Vision)
        if #available(iOS 17.0, visionOS 1.0, *) {
            return true
        }
#endif
        return false
    }

    private func saveImageAction(for index: Int) async {
        guard let image = imagesByIndex[index] else {
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
        let permissionDeniedMessage = NSLocalizedString("teahouse.image.error.photo_permission_denied", comment: "")
        let permissionUnknownMessage = NSLocalizedString("teahouse.image.error.photo_permission_unknown", comment: "")
        let saveFailedMessage = NSLocalizedString("teahouse.image.error.save_failed", comment: "")
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
                            userInfo: [NSLocalizedDescriptionKey: permissionDeniedMessage]
                        )
                    )
                @unknown default:
                    continuation.resume(
                        throwing: NSError(
                            domain: "Teahouse",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: permissionUnknownMessage]
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
                            userInfo: [NSLocalizedDescriptionKey: saveFailedMessage]
                        )
                    )
                }
            })
        }
    }

    private func copySubjectAction(for index: Int) async {
#if canImport(UIKit) && canImport(Vision)
        guard let image = imagesByIndex[index] else {
            await MainActor.run {
                saveErrorMessage = "teahouse.image.error.image_not_loaded".localized
                showSaveError = true
            }
            return
        }

        do {
            if #available(iOS 17.0, visionOS 1.0, *) {
                let subjectImage = try extractForegroundSubject(from: image)
                await MainActor.run {
                    UIPasteboard.general.image = subjectImage
                }
            } else {
                await MainActor.run {
                    saveErrorMessage = "Vision unavailable on current OS"
                    showSaveError = true
                }
            }
        } catch {
            await MainActor.run {
                saveErrorMessage = error.localizedDescription
                showSaveError = true
            }
        }
#endif
    }

    private func lookupAction(for index: Int) async {
#if canImport(UIKit) && canImport(Vision)
        guard let image = imagesByIndex[index] else {
            await MainActor.run {
                saveErrorMessage = "teahouse.image.error.image_not_loaded".localized
                showSaveError = true
            }
            return
        }

        do {
            if #available(iOS 17.0, visionOS 1.0, *) {
                let result = try classifyImage(image)
                await MainActor.run {
                    lookupMessage = result
                    showLookupResult = true
                }
            } else {
                await MainActor.run {
                    saveErrorMessage = "Vision unavailable on current OS"
                    showSaveError = true
                }
            }
        } catch {
            await MainActor.run {
                saveErrorMessage = error.localizedDescription
                showSaveError = true
            }
        }
#endif
    }

#if canImport(UIKit) && canImport(Vision)
    @available(iOS 17.0, visionOS 1.0, *)
    private func extractForegroundSubject(from image: UIImage) throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "Vision", code: 11, userInfo: [NSLocalizedDescriptionKey: "Invalid CGImage"]) 
        }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        try requestHandler.perform([request])

        guard let observation = request.results?.first else {
            throw NSError(domain: "Vision", code: 12, userInfo: [NSLocalizedDescriptionKey: "No foreground subject detected"])
        }

        let maskPixelBuffer = try observation.generateScaledMaskForImage(
            forInstances: observation.allInstances,
            from: requestHandler
        )

        let input = CIImage(cgImage: cgImage)
        let mask = CIImage(cvPixelBuffer: maskPixelBuffer)
        let clear = CIImage(color: .clear).cropped(to: input.extent)

        let filter = CIFilter.blendWithMask()
        filter.inputImage = input
        filter.backgroundImage = clear
        filter.maskImage = mask

        guard let output = filter.outputImage else {
            throw NSError(domain: "Vision", code: 13, userInfo: [NSLocalizedDescriptionKey: "Failed to build masked image"])
        }

        let context = CIContext()
        guard let outputCGImage = context.createCGImage(output, from: input.extent) else {
            throw NSError(domain: "Vision", code: 14, userInfo: [NSLocalizedDescriptionKey: "Failed to render image"])
        }

        return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
    }

    @available(iOS 17.0, visionOS 1.0, *)
    private func classifyImage(_ image: UIImage) throws -> String {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "Vision", code: 21, userInfo: [NSLocalizedDescriptionKey: "Invalid CGImage"])
        }

        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        guard let observations = request.results, !observations.isEmpty else {
            return "No classification result"
        }

        let topResults = observations.prefix(3)
        return topResults
            .map { "\($0.identifier) (\(Int($0.confidence * 100))%)" }
            .joined(separator: "\n")
    }
#endif
}

private struct ZoomableRemoteImageView: View {
    let url: URL
    let displayScale: CGFloat
    let canvasSize: CGSize
    let onImageLoaded: (PostDetailPlatformImage) -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var loadedImage: PostDetailPlatformImage? = nil

    var body: some View {
        dragAwareContent(imageContent)
            .frame(width: canvasSize.width, height: canvasSize.height)
            .clipped()
            .scaleEffect(scale)
            .offset(offset)
            .simultaneousGesture(magnificationGesture)
            .modifier(BottomSafeAreaBypassModifier(isActive: scale > 1))
            .onTapGesture(count: 2) {
                withAnimation(.spring()) {
                    if scale > 1.1 {
                        scale = 1
                        lastScale = 1
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        scale = 2
                        lastScale = 2
                    }
                }
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = max(1, min(newScale, 6))
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 {
                    offset = .zero
                    lastOffset = .zero
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let loadedImage {
            let fittedSize = fittedDisplaySize(for: loadedImage)
#if canImport(UIKit) && canImport(VisionKit)
            if #available(iOS 16.0, visionOS 1.0, *) {
                LiveTextImageView(image: loadedImage)
                    .frame(width: fittedSize.width, height: fittedSize.height)
            } else {
                Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: fittedSize.width, height: fittedSize.height)
            }
#elseif canImport(UIKit)
            Image(uiImage: loadedImage)
                .resizable()
                .scaledToFit()
                .frame(width: fittedSize.width, height: fittedSize.height)
#elseif canImport(AppKit)
            Image(nsImage: loadedImage)
                .resizable()
                .scaledToFit()
                .frame(width: fittedSize.width, height: fittedSize.height)
#endif
        } else {
            KFImage(url)
                .downsampling(size: CGSize(width: max(1, canvasSize.width), height: max(1, canvasSize.height)))
                .scaleFactor(displayScale)
                .cancelOnDisappear(true)
                .placeholder {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .retry(maxCount: 2, interval: .seconds(2))
                .onSuccess { result in
                    loadedImage = result.image
                    onImageLoaded(result.image)
                }
                .resizable()
                .scaledToFit()
                .frame(maxWidth: canvasSize.width, maxHeight: canvasSize.height, alignment: .center)
        }
    }

    private func fittedDisplaySize(for image: PostDetailPlatformImage) -> CGSize {
        let imageSize = image.size
        let safeImageWidth = max(1, imageSize.width)
        let safeImageHeight = max(1, imageSize.height)
        let widthScale = canvasSize.width / safeImageWidth
        let heightScale = canvasSize.height / safeImageHeight
        let scale = min(widthScale, heightScale)
        return CGSize(width: safeImageWidth * scale, height: safeImageHeight * scale)
    }

    @ViewBuilder
    private func dragAwareContent<Content: View>(_ content: Content) -> some View {
        if scale > 1 {
            content.gesture(dragGesture)
        } else {
            content
        }
    }
}

private struct BottomSafeAreaBypassModifier: ViewModifier {
    let isActive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isActive {
            content.ignoresSafeArea(.container, edges: .bottom)
        } else {
            content
        }
    }
}

#if canImport(UIKit) && canImport(VisionKit)
@available(iOS 16.0, visionOS 1.0, *)
private struct LiveTextImageView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.image = image
        imageView.isUserInteractionEnabled = true

        imageView.addInteraction(context.coordinator.interaction)
        context.coordinator.configureAnalysis(for: image)

        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.image = image
        context.coordinator.configureAnalysis(for: image)
    }

    final class Coordinator {
        let interaction = ImageAnalysisInteraction()
        private var analysisTask: Task<Void, Never>?

        func configureAnalysis(for image: UIImage) {
            // Keep text selection, avoid extra detector interactions that can
            // make horizontal paging feel heavy.
            interaction.preferredInteractionTypes = [.textSelection]
            analysisTask?.cancel()
            analysisTask = Task {
                let analyzer = ImageAnalyzer()
                let configuration = ImageAnalyzer.Configuration([.text])
                let analysis = try? await analyzer.analyze(image, configuration: configuration)
                if Task.isCancelled { return }
                await MainActor.run {
                    interaction.analysis = analysis
                    interaction.preferredInteractionTypes = [.textSelection]
                }
            }
        }

        deinit {
            analysisTask?.cancel()
        }
    }
}
#endif
