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
            guard let imageData = image.jpegData(compressionQuality: 0.9) else { return nil }

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let timestamp = Int(Date().timeIntervalSince1970)
            let destinationURL = documentsPath.appendingPathComponent("\(parent.filePrefix)_\(timestamp).\(fileExtension)")

            let fileManager = FileManager.default
            if let existingFiles = try? fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil) {
                for file in existingFiles where file.lastPathComponent.hasPrefix("\(parent.filePrefix)_") {
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
        private func presentMantisCropper(with image: UIImage, from picker: PHPickerViewController) {
            var config = Mantis.Config()
            let screenBounds = UIScreen.main.bounds
            let screenRatio = max(screenBounds.width, 1) / max(screenBounds.height, 1)
            config.presetFixedRatioType = .alwaysUsingOnePresetFixedRatio(ratio: screenRatio)

            let cropViewController = Mantis.cropViewController(image: image, config: config)
            let delegateProxy = CropDelegateProxy(
                onCrop: { [weak self] cropped in
                    guard let self = self else { return }
                    let destinationURL = self.saveImageToDocuments(cropped)
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
                    self.completeOnMain(nil)
                    self.parent.dismiss()
                    self.cropDelegateProxy = nil
                }
            )
            cropDelegateProxy = delegateProxy
            cropViewController.delegate = delegateProxy
            picker.present(cropViewController, animated: true)
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
