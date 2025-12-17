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
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let result = results.first else {
                parent.completion(nil)
                return
            }
            
            // 对于头像临时文件，直接加载图片数据然后保存
            if parent.filePrefix.contains("temp") {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Error loading image: \(error)")
                        DispatchQueue.main.async {
                            self.parent.completion(nil)
                        }
                        return
                    }
                    
                    guard let uiImage = image as? UIImage else {
                        DispatchQueue.main.async {
                            self.parent.completion(nil)
                        }
                        return
                    }
                    
                    // 保存为临时文件
                    guard let imageData = uiImage.jpegData(compressionQuality: 0.9) else {
                        DispatchQueue.main.async {
                            self.parent.completion(nil)
                        }
                        return
                    }
                    
                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let timestamp = Int(Date().timeIntervalSince1970)
                    let destinationURL = documentsPath.appendingPathComponent("\(self.parent.filePrefix)_\(timestamp).jpg")
                    
                    do {
                        try imageData.write(to: destinationURL)
                        DispatchQueue.main.async {
                            self.parent.completion(destinationURL)
                        }
                    } catch {
                        print("Error saving temp image: \(error)")
                        DispatchQueue.main.async {
                            self.parent.completion(nil)
                        }
                    }
                }
                return
            }
            
            // 原有的背景图片处理逻辑
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                if let error = error {
                    print("Error loading image: \(error)")
                    DispatchQueue.main.async {
                        self.parent.completion(nil)
                    }
                    return
                }
                
                guard let url = url else {
                    DispatchQueue.main.async {
                        self.parent.completion(nil)
                    }
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
                    DispatchQueue.main.async {
                        self.parent.completion(destinationURL)
                    }
                } catch {
                    print("Error copying image: \(error)")
                    DispatchQueue.main.async {
                        self.parent.completion(nil)
                    }
                }
            }
        }
    }
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
            
            Button("cancel".localized) {
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
