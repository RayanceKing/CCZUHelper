//
//  CustomizeProfileSheet.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/2/23.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
typealias ProfileImageType = UIImage
#else
import AppKit
typealias ProfileImageType = NSImage
#endif

/// 自定义个人资料弹窗
struct CustomizeProfileSheet: View {
    let avatarUrl: String?
    @Environment(AppSettings.self) private var settings
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Binding var isPresented: Bool
    @Binding var nickname: String
    @Binding var selectedAvatarImage: ProfileImageType?
    var onSave: (String, ProfileImageType?) -> Void
    
    @State private var showImagePicker = false
    @State private var pickerFileURL: URL?
    @State private var isSaving: Bool = false
    
    private var secondaryBackgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(.secondarySystemBackground)
        #endif
    }
    
    private var fieldBackgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(.systemBackground)
        #endif
    }
    
    private var groupedBackgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(.systemGroupedBackground)
        #endif
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("profile.customize_prompt".localized)
                          .font(.title.bold())
                          .frame(maxWidth: .infinity)
                          .multilineTextAlignment(.center)
                          .padding(.top, 8)
                    
                    VStack(spacing: 16) {
                        Button {
                            showImagePicker = true
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                avatarContent
                                    .frame(width: 180, height: 180)
                                    .background(secondaryBackgroundColor)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle().stroke(Color.primary.opacity(0.08), lineWidth: 2)
                                    )
                                
                                Circle()
                                    .fill(fieldBackgroundColor)
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        Image(systemName: "pencil")
                                            .foregroundColor(.blue)
                                            .font(.title2)
                                    )
                                    .offset(x: 12, y: 12)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("profile.nickname".localized)
                                .fontWeight(.semibold)
                            TextField("profile.enter_nickname".localized, text: $nickname)
                                .padding(12)
                                .background(fieldBackgroundColor)
                                .cornerRadius(12)
                        }
                        
                        Text("profile.visibility_notice".localized)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
                .padding(24)
            }
            .scrollContentBackground(.hidden)
            .background(
                groupedBackgroundColor
                    .ignoresSafeArea()
            )
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close".localized) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("common.done".localized) {
                            isSaving = true
                            onSave(nickname.trimmingCharacters(in: .whitespacesAndNewlines), selectedAvatarImage)
                        }
                        .disabled(isSaving)
                    }
                }
            }
        }
        .onChange(of: isPresented) { _, newValue in
            if newValue == false {
                isSaving = false
            }
        }
        .sheet(isPresented: $showImagePicker, onDismiss: loadSelectedImage) {
            ImagePickerView(completion: { url in
                pickerFileURL = url
                showImagePicker = false
            }, filePrefix: "avatar_custom")
        }
    }
    
    private var avatarContent: some View {
        Group {
            if let urlString = avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholderAvatar
                    @unknown default:
                        placeholderAvatar
                    }
                }
            } else if let image = selectedAvatarImage {
                #if canImport(UIKit)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                #else
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                #endif
            } else {
                placeholderAvatar
            }
        }
    }

    private var placeholderAvatar: some View {
        Image(systemName: "person.fill")
            .resizable()
            .scaledToFit()
            .padding(36)
            .foregroundStyle(.secondary)
    }
    
    private func loadSelectedImage() {
        guard let url = pickerFileURL else { return }
        if let data = try? Data(contentsOf: url) {
            #if canImport(UIKit)
            if let img = UIImage(data: data) {
                selectedAvatarImage = img
            }
            #else
            if let img = NSImage(data: data) {
                selectedAvatarImage = img
            }
            #endif
        }
        try? FileManager.default.removeItem(at: url)
    }
}

#Preview {
    CustomizeProfileSheet(
        avatarUrl: nil,
        isPresented: .constant(true),
        nickname: .constant("Test User"),
        selectedAvatarImage: .constant(nil),
        onSave: { _, _ in }
    )
    .environment(AppSettings())
    .environmentObject(AuthViewModel())
}
