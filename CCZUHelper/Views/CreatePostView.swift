//
//  CreatePostView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/1.
//

import SwiftUI
import SwiftData
import PhotosUI
import Supabase

/// 创建帖子视图
struct CreatePostView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @StateObject private var teahouseService = TeahouseService()
    
    private var categories: [String] {
        [
            NSLocalizedString("teahouse.category.study".localized, comment: ""),
            NSLocalizedString("teahouse.category.life".localized, comment: ""),
            NSLocalizedString("teahouse.category.secondhand".localized, comment: ""),
            NSLocalizedString("teahouse.category.confession".localized, comment: ""),
            NSLocalizedString("teahouse.category.lost_found".localized, comment: "")
        ]
    }
    
    @State private var selectedCategory = ""
    @State private var title = ""
    @State private var content = ""
    @State private var isAnonymous = false
    @State private var priceText: String = ""
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
                priceSection
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
                    if isPosting {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text(NSLocalizedString("create_post.publishing", comment: ""))
                        }
                        .foregroundColor(.gray)
                    } else {
                        Button(NSLocalizedString("create_post.publish", comment: "")) {
                            publishPost()
                        }
                        .disabled(!canPublish)
                    }
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
    
    private var priceSection: some View {
        Section(NSLocalizedString("create_post.price", comment: "")) {
            // 仅在选择二手交易时显示价格输入
            if selectedCategory == NSLocalizedString("teahouse.category.secondhand", comment: "") {
                TextField(NSLocalizedString("create_post.price_placeholder", comment: ""), text: $priceText)
                    .keyboardType(.decimalPad)
            } else {
                Text(NSLocalizedString("create_post.price_hint_unavailable", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
                guard (supabase.auth.currentSession?.user.id.uuidString) != nil else {
                    throw AppError.notAuthenticated
                }

                let postId = UUID().uuidString

                // 1. 将 imageData 写入临时文件，得到 [URL]
                let tempImageURLs: [URL] = try imageData.enumerated().map { idx, data in
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("post_img_\(UUID().uuidString)_\(idx).jpg")
                    try data.write(to: tempURL)
                    return tempURL
                }
                // 2. 上传到图床
                let remoteImageUrls = try await teahouseService.uploadPostImages(imageFileURLs: tempImageURLs)

                // 准备远端字段
                let categoryId = mapCategoryToId(selectedCategory)
                let priceValue: Double? = (selectedCategory == NSLocalizedString("teahouse.category.secondhand", comment: "")) ? Double(priceText) : nil
                let imageUrlsForServer: [String]? = remoteImageUrls.isEmpty ? nil : remoteImageUrls

                // 远端创建帖子（Supabase）
                let created = try await teahouseService.createPost(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    categoryId: categoryId,
                    imageUrls: imageUrlsForServer,
                    price: priceValue,
                    isAnonymous: isAnonymous,
                    id: postId
                )
                
                // 本地插入以便 UI 立即反馈
                let author = isAnonymous ? NSLocalizedString("create_post.anonymous_user", comment: "") : (settings.userDisplayName ?? settings.username ?? NSLocalizedString("create_post.user", comment: ""))
                let localPost = TeahousePost(
                    id: created.id,
                    author: author,
                    authorId: isAnonymous ? nil : settings.username,
                    authorAvatarUrl: isAnonymous ? nil : nil,
                    category: selectedCategory,
                    price: priceValue,
                    title: created.title,
                    content: created.content,
                    images: remoteImageUrls,
                    likes: 0,
                    comments: 0,
                    createdAt: Date(),
                    isLocal: false,
                    syncStatus: .synced
                )
                
                await MainActor.run {
                    modelContext.insert(localPost)
                    
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
    
    private func mapCategoryToId(_ category: String) -> Int {
        // 简化映射：与数据库 categories 表保持一致（示例）
        let mapping: [String: Int] = [
            NSLocalizedString("teahouse.category.study", comment: ""): 1,
            NSLocalizedString("teahouse.category.life", comment: ""): 2,
            NSLocalizedString("teahouse.category.secondhand", comment: ""): 3,
            NSLocalizedString("teahouse.category.confession", comment: ""): 4,
            NSLocalizedString("teahouse.category.lost_found", comment: ""): 5
        ]
        return mapping[category] ?? 1
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

