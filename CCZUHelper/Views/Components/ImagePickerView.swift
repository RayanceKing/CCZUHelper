//
//  ImagePickerView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import UniformTypeIdentifiers

#if os(iOS) || os(visionOS)
import PhotosUI
#if os(iOS)
import Mantis
#endif

/// 图片选择视图
struct ImagePickerView: UIViewControllerRepresentable {
    let completion: (URL?) -> Void
    let filePrefix: String  // 文件名前缀，用于区分不同用途的图片
    
    @Environment(\.dismiss) private var dismiss
    
    init(completion: @escaping (URL?) -> Void, filePrefix: String = "background") {
        self.completion = completion
        self.filePrefix = filePrefix
    }
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePickerView
        #if os(iOS)
        private var cropDelegateProxy: CropDelegateProxy?
        #endif
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        private func completeOnMain(_ url: URL?) {
            DispatchQueue.main.async {
                self.parent.completion(url)
            }
        }

        private func saveImageToDocuments(_ image: UIImage, fileExtension: String = "jpg") -> URL? {
            Self.saveImage(image, filePrefix: parent.filePrefix, fileExtension: fileExtension)
        }

        static func saveImage(_ image: UIImage, filePrefix: String, fileExtension: String = "jpg") -> URL? {
            guard let imageData = image.jpegData(compressionQuality: 0.9) else { return nil }

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let timestamp = Int(Date().timeIntervalSince1970)
            let destinationURL = documentsPath.appendingPathComponent("\(filePrefix)_\(timestamp).\(fileExtension)")

            let fileManager = FileManager.default
            if let existingFiles = try? fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil) {
                for file in existingFiles where file.lastPathComponent.hasPrefix("\(filePrefix)_") {
                    try? fileManager.removeItem(at: file)
                }
            }

            do {
                try imageData.write(to: destinationURL)
                return destinationURL
            } catch {
                print("Error saving image: \(error)")
                return nil
            }
        }

        #if os(iOS)
        /// 交给 Mantis 之前允许的最大像素边长（超出先降采样，避免 iPad 上大图渲染黑屏）
        private static let maxInputPixelSize: CGFloat = 4096
        /// 壁纸落盘前允许的最大像素边长
        private static let maxOutputPixelSize: CGFloat = 4096

        private func presentMantisCropper(with image: UIImage, from picker: PHPickerViewController) {
            // 相册里的原图可能非常大（高像素照片 / ProRAW），iPad 上直接交给 Mantis
            // 会触发 UIImageView 渲染失败而黑屏，先按像素边长降采样。
            let preparedImage = Self.downscaled(image, maxPixelSize: Self.maxInputPixelSize)

            var config = Mantis.Config()
            // 用真实窗口尺寸而不是 picker.view.bounds / UIScreen.main.bounds 计算比例。
            // iPad 分屏、Stage Manager、多窗口场景下后两者都会和视图实际尺寸不一致，
            // 导致裁剪框比例被算错。
            let referenceBounds = Self.referenceBounds(for: picker.view)
            let ratio = referenceBounds.height > 0
                ? referenceBounds.width / referenceBounds.height
                : 1
            config.presetFixedRatioType = .alwaysUsingOnePresetFixedRatio(ratio: min(max(ratio, 0.2), 5.0))
            // 超过阈值时使用「降采样显示 + CIImage 裁剪管线」，这是 Mantis 官方
            // 为避免大图黑屏 / CGContext 爆内存提供的开关。
            config.cropViewConfig.maxImagePixelCount = 4096 * 4096

            let cropViewController = Mantis.cropViewController(image: preparedImage, config: config)
            // iPad 上默认会以 pageSheet 叠加在 PHPicker 之上，CropView 拿到的 bounds
            // 与最终尺寸不一致，图片容器尺寸会被算成 0，表现为黑屏、裁剪结果为空。
            // 统一全屏呈现，和 iPhone 上的行为保持一致。
            cropViewController.modalPresentationStyle = .fullScreen
            cropViewController.modalTransitionStyle = .coverVertical

            let delegateProxy = CropDelegateProxy(
                onCrop: { [weak self] cropped in
                    guard let self = self else { return }
                    let output = Self.downscaled(cropped, maxPixelSize: Self.maxOutputPixelSize)
                    let destinationURL = self.saveImageToDocuments(output)
                    self.completeOnMain(destinationURL)
                    self.parent.dismiss()
                    self.cropDelegateProxy = nil
                },
                onCancel: { [weak self] in
                    guard let self = self else { return }
                    self.completeOnMain(nil)
                    self.parent.dismiss()
                    self.cropDelegateProxy = nil
                },
                onFail: { [weak self] in
                    guard let self = self else { return }
                    // 裁剪失败时退化为直接使用原图，避免「点了完成却什么都没设置」
                    let output = Self.downscaled(preparedImage, maxPixelSize: Self.maxOutputPixelSize)
                    let destinationURL = self.saveImageToDocuments(output)
                    self.completeOnMain(destinationURL)
                    self.parent.dismiss()
                    self.cropDelegateProxy = nil
                }
            )
            cropDelegateProxy = delegateProxy
            cropViewController.delegate = delegateProxy
            picker.present(cropViewController, animated: true)
        }

        /// 取用于计算裁剪比例的真实可用区域，优先用窗口尺寸（能正确反映 iPad 分屏 / 多窗口）
        private static func referenceBounds(for view: UIView) -> CGRect {
            if let windowBounds = view.window?.bounds,
               windowBounds.width > 0, windowBounds.height > 0 {
                return windowBounds
            }
            if view.bounds.width > 0, view.bounds.height > 0 {
                return view.bounds
            }
            return UIScreen.main.bounds
        }

        /// 按像素边长上限降采样（保持宽高比，不改变 UIImage 的显示方向）
        private static func downscaled(_ image: UIImage, maxPixelSize: CGFloat) -> UIImage {
            let pixelWidth = image.size.width * image.scale
            let pixelHeight = image.size.height * image.scale
            let longestEdge = max(pixelWidth, pixelHeight)
            guard maxPixelSize > 0, longestEdge > maxPixelSize else { return image }

            let factor = maxPixelSize / longestEdge
            let targetSize = CGSize(
                width: max(1, floor(pixelWidth * factor)),
                height: max(1, floor(pixelHeight * factor))
            )
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }
        #endif
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                parent.dismiss()
                parent.completion(nil)
                return
            }
            
            // 对于头像临时文件，直接加载图片数据然后保存
            if parent.filePrefix.contains("temp") {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Error loading image: \(error)")
                        self.completeOnMain(nil)
                        return
                    }
                    
                    guard let uiImage = image as? UIImage else {
                        self.completeOnMain(nil)
                        return
                    }

                    let destinationURL = self.saveImageToDocuments(uiImage)
                    self.completeOnMain(destinationURL)
                    DispatchQueue.main.async {
                        self.parent.dismiss()
                    }
                }
                return
            }

            #if os(iOS)
            if parent.filePrefix == "background" {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    guard let self = self else { return }

                    if let error = error {
                        print("Error loading image for crop: \(error)")
                        self.completeOnMain(nil)
                        DispatchQueue.main.async {
                            self.parent.dismiss()
                        }
                        return
                    }

                    guard let uiImage = image as? UIImage else {
                        self.completeOnMain(nil)
                        DispatchQueue.main.async {
                            self.parent.dismiss()
                        }
                        return
                    }

                    DispatchQueue.main.async {
                        self.presentMantisCropper(with: uiImage, from: picker)
                    }
                }
                return
            }
            #endif
            
            // 原有的背景图片处理逻辑
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                if let error = error {
                    print("Error loading image: \(error)")
                    self.completeOnMain(nil)
                    return
                }
                
                guard let url = url else {
                    self.completeOnMain(nil)
                    return
                }
                
                // 复制文件到应用的文档目录，使用时间戳生成唯一文件名
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let timestamp = Int(Date().timeIntervalSince1970)
                let fileExtension = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
                let destinationURL = documentsPath.appendingPathComponent("\(self.parent.filePrefix)_\(timestamp).\(fileExtension)")
                
                // 删除旧的同前缀图片（如果存在）
                let fileManager = FileManager.default
                if let existingFiles = try? fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil) {
                    for file in existingFiles where file.lastPathComponent.hasPrefix("\(self.parent.filePrefix)_") {
                        try? fileManager.removeItem(at: file)
                    }
                }
                
                do {
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    self.completeOnMain(destinationURL)
                } catch {
                    print("Error copying image: \(error)")
                    self.completeOnMain(nil)
                }

                DispatchQueue.main.async {
                    self.parent.dismiss()
                }
            }
        }
    }

    #if os(iOS)
    private final class CropDelegateProxy: NSObject, CropViewControllerDelegate {
        private let onCrop: (UIImage) -> Void
        private let onCancel: () -> Void
        private let onFail: () -> Void

        init(onCrop: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void, onFail: @escaping () -> Void) {
            self.onCrop = onCrop
            self.onCancel = onCancel
            self.onFail = onFail
        }

        func cropViewControllerDidCrop(_ cropViewController: CropViewController, cropped: UIImage, transformation: Transformation, cropInfo: CropInfo) {
            onCrop(cropped)
        }

        func cropViewControllerDidCancel(_ cropViewController: CropViewController, original: UIImage) {
            onCancel()
        }

        func cropViewControllerDidFailToCrop(_ cropViewController: CropViewController, original: UIImage) {
            onFail()
        }
    }
    #endif
}

#elseif os(macOS)
import AppKit

/// macOS 图片选择视图
struct ImagePickerView: View {
    let completion: (URL?) -> Void
    let filePrefix: String
    
    @Environment(\.dismiss) private var dismiss
    
    init(completion: @escaping (URL?) -> Void, filePrefix: String = "background") {
        self.completion = completion
        self.filePrefix = filePrefix
    }
    
    var body: some View {
        VStack {
            Text("image.picker.title".localized)
                .font(.headline)
                .padding()
            
            Button("image.picker.select".localized) {
                selectImage()
            }
            .padding()
            
            Button("common.cancel".localized) {
                completion(nil)
                dismiss()
            }
            .padding()
        }
        .frame(width: 300, height: 200)
    }
    
    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                // 复制文件到应用的文档目录，使用时间戳生成唯一文件名
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let timestamp = Int(Date().timeIntervalSince1970)
                let fileExtension = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
                let destinationURL = documentsPath.appendingPathComponent("\(filePrefix)_\(timestamp).\(fileExtension)")
                
                // 删除旧的同前缀图片（如果存在）
                let fileManager = FileManager.default
                if let existingFiles = try? fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil) {
                    for file in existingFiles where file.lastPathComponent.hasPrefix("\(filePrefix)_") {
                        try? fileManager.removeItem(at: file)
                    }
                }
                
                do {
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    completion(destinationURL)
                } catch {
                    print("Error copying image: \(error)")
                    completion(nil)
                }
            }
            dismiss()
        }
    }
}
#endif
