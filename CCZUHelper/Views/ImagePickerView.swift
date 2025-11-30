//
//  ImagePickerView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import PhotosUI

/// 图片选择视图
struct ImagePickerView: UIViewControllerRepresentable {
    let completion: (URL?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
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
                
                // 复制文件到应用的文档目录
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let destinationURL = documentsPath.appendingPathComponent("background_image.jpg")
                
                try? FileManager.default.removeItem(at: destinationURL)
                
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
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("选择背景图片")
                .font(.headline)
                .padding()
            
            Button("选择图片") {
                selectImage()
            }
            .padding()
            
            Button("取消") {
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
                // 复制文件到应用的文档目录
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let destinationURL = documentsPath.appendingPathComponent("background_image.jpg")
                
                try? FileManager.default.removeItem(at: destinationURL)
                
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
