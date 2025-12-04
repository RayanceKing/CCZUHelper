//
//  CreatePostView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/1.
//

import SwiftUI
import SwiftData
import PhotosUI

/// 创建帖子视图
struct CreatePostView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @State private var selectedCategory = "学习"
    @State private var title = ""
    @State private var content = ""
    @State private var isAnonymous = false
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var imageData: [Data] = []
    @State private var showImagePicker = false
    @State private var isPosting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private let categories = ["teahouse.category.study".localized, "teahouse.category.life".localized, "teahouse.category.secondhand".localized, "teahouse.category.confession".localized, "teahouse.category.lost_found".localized, "teahouse.category.other".localized]
    private let maxImages = 9
    
    var body: some View {
        NavigationStack {
            Form {
                // 分类选择
                Section("post.create.category".localized) {
                    Picker("post.create.category_select".localized, selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // 标题
                Section("post.create.title_field".localized) {
                    TextField("post.create.title_placeholder".localized, text: $title)
                        .textInputAutocapitalization(.never)
                }
                
                // 内容
                Section("post.create.content".localized) {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                        .textInputAutocapitalization(.sentences)
                }
                
                // 图片
                Section("post.create.images".localized(with: maxImages)) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // 已选择的图片
                            ForEach(Array(imageData.enumerated()), id: \.offset) { index, data in
                                if let uiImage = UIImage(data: data) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        Button(action: {
                                            imageData.remove(at: index)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.white)
                                                .background(Color.black.opacity(0.6))
                                                .clipShape(Circle())
                                        }
                                        .padding(4)
                                    }
                                }
                            }
                            
                            // 添加图片按钮
                            if imageData.count < maxImages {
                                PhotosPicker(
                                    selection: $selectedImages,
                                    maxSelectionCount: maxImages - imageData.count,
                                    matching: .images
                                ) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 100, height: 100)
                                        .overlay {
                                            Image(systemName: "plus")
                                                .font(.title)
                                                .foregroundStyle(.gray)
                                        }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // 发布选项
                Section {
                    Toggle("post.create.anonymous".localized, isOn: $isAnonymous)
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("post.create.test_notice".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("post.create.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                    .disabled(isPosting)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("post.create.publish".localized) {
                        publishPost()
                    }
                    .disabled(!canPublish || isPosting)
                }
            }
            .onChange(of: selectedImages) { oldValue, newValue in
                loadImages()
            }
            .alert("post.create.hint".localized, isPresented: $showAlert) {
                Button("ok".localized, role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var canPublish: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func loadImages() {
        Task {
            var newImageData: [Data] = []
            
            for item in selectedImages {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    newImageData.append(data)
                }
            }
            
            await MainActor.run {
                imageData.append(contentsOf: newImageData)
                selectedImages.removeAll()
            }
        }
    }
    
    private func publishPost() {
        guard canPublish else { return }
        
        isPosting = true
        
        Task {
            do {
                // 保存图片到本地
                let imagePaths = try await saveImagesToLocal(imageData)
                
                // 创建帖子
                let author = isAnonymous ? "post.create.anonymous_user".localized : (settings.username ?? "post.create.user".localized)
                let post = TeahousePost(
                    author: author,
                    authorId: isAnonymous ? nil : settings.username,
                    category: selectedCategory,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    images: imagePaths,
                    isLocal: true,
                    syncStatus: .local
                )
                
                await MainActor.run {
                    modelContext.insert(post)
                    
                    // TODO: 未来实现服务器同步
                    // syncToServer(post)
                    
                    isPosting = false
                    alertMessage = "post.create.success".localized
                    showAlert = true
                    
                    // 延迟关闭
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isPosting = false
                    alertMessage = "post.create.failed".localized(with: error.localizedDescription)
                    showAlert = true
                }
            }
        }
    }
    
    private func saveImagesToLocal(_ dataArray: [Data]) async throws -> [String] {
        var paths: [String] = []
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesFolder = documentsPath.appendingPathComponent("TeahouseImages")
        
        // 创建图片文件夹
        try FileManager.default.createDirectory(at: imagesFolder, withIntermediateDirectories: true)
        
        for data in dataArray {
            let filename = "\(UUID().uuidString).jpg"
            let fileURL = imagesFolder.appendingPathComponent(filename)
            
            try data.write(to: fileURL)
            paths.append(fileURL.path)
        }
        
        return paths
    }
    
    // 预留的服务器同步接口
    private func syncToServer(_ post: TeahousePost) {
        // TODO: 实现与服务器的同步逻辑
        // 1. 上传图片到服务器
        // 2. 上传帖子数据到服务器
        // 3. 更新本地帖子的同步状态
        
        Task {
            // 模拟网络请求
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                post.syncStatus = .synced
                post.isLocal = false
            }
        }
    }
}

#Preview {
    CreatePostView()
        .environment(AppSettings())
        .modelContainer(for: [TeahousePost.self], inMemory: true)
}
