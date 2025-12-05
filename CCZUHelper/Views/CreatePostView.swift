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
    
    private var categories: [String] {
        [
            NSLocalizedString("teahouse.category.study", comment: ""),
            NSLocalizedString("teahouse.category.life", comment: ""),
            NSLocalizedString("teahouse.category.secondhand", comment: ""),
            NSLocalizedString("teahouse.category.confession", comment: ""),
            NSLocalizedString("teahouse.category.lost_found", comment: ""),
            NSLocalizedString("teahouse.category.other", comment: "")
        ]
    }
    
    @State private var selectedCategory = ""
    @State private var title = ""
    @State private var content = ""
    @State private var isAnonymous = false
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var imageData: [Data] = []
    @State private var showImagePicker = false // This state variable is not currently used.
    @State private var isPosting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private let maxImages = 9
    
    var body: some View {
        NavigationStack {
            Form {
                categorySection
                titleSection
                contentSection
                imageSelectionSection
                publishingOptionsSection
            }
            .navigationTitle(NSLocalizedString("create_post.title", comment: ""))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("cancel", comment: "")) {
                        dismiss()
                    }
                    .disabled(isPosting)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("create_post.publish", comment: "")) {
                        publishPost()
                    }
                    .disabled(!canPublish || isPosting)
                }
            }
            .onChange(of: selectedImages) { oldValue, newValue in
                loadImages()
            }
            .alert(NSLocalizedString("create_post.alert_title", comment: ""), isPresented: $showAlert) {
                Button(NSLocalizedString("ok", comment: ""), role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                // 初始化默认分类为第一个
                if selectedCategory.isEmpty && !categories.isEmpty {
                    selectedCategory = categories[0]
                }
            }
        }
    }
    
    private var categorySection: some View {
        Section(NSLocalizedString("create_post.category", comment: "")) {
            Picker(NSLocalizedString("create_post.select_category", comment: ""), selection: $selectedCategory) {
                ForEach(categories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var titleSection: some View {
        Section(NSLocalizedString("create_post.title_field", comment: "")) {
            TextField(NSLocalizedString("create_post.title_placeholder", comment: ""), text: $title)
#if os(iOS) || os(visionOS)
                .textInputAutocapitalization(.never)
#endif
        }
    }
    
    private var contentSection: some View {
        Section(NSLocalizedString("create_post.content", comment: "")) {
            TextEditor(text: $content)
                .frame(minHeight: 150)
#if os(iOS) || os(visionOS)
                .textInputAutocapitalization(.sentences)
#endif
        }
    }
    
    private var imageSelectionSection: some View {
        #if os(macOS)
        // macOS 不支持图片选择
        EmptyView()
        #else
        Section(String(format: NSLocalizedString("create_post.images", comment: ""), maxImages)) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // 已选择的图片
                    ForEach(Array(imageData.enumerated()), id: \.offset) { index, data in
                        if let image = PlatformImage(data: data) {
                            imagePreviewCell(image: image, index: index)
                        }
                    }
                    
                    // 添加图片按钮
                    if imageData.count < maxImages {
                        addImageButton
                    }
                }
                .padding(.vertical, 8)
            }
        }
        #endif
    }
    
    private func imagePreviewCell(image: PlatformImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            PlatformImageView(platformImage: image)
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
    
    private var addImageButton: some View {
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
    
    private var publishingOptionsSection: some View {
        Section {
            Toggle(NSLocalizedString("create_post.anonymous", comment: ""), isOn: $isAnonymous)
            
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text(NSLocalizedString("create_post.test_notice", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            
            // Ensure UI updates on the main actor
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
                let author = isAnonymous ? NSLocalizedString("create_post.anonymous_user", comment: "") : (settings.username ?? NSLocalizedString("create_post.user", comment: ""))
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
                    alertMessage = NSLocalizedString("create_post.success", comment: "")
                    showAlert = true
                    
                    // 延迟关闭
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isPosting = false
                    alertMessage = String(format: NSLocalizedString("create_post.failed", comment: ""), error.localizedDescription)
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
