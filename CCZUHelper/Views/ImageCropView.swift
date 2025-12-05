//
//  ImageCropView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/5.
//

import SwiftUI

#if os(iOS)
/// 图片裁剪视图（圆形裁剪）
struct ImageCropView: View {
    let image: UIImage
    let onCrop: (UIImage?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let cropSize: CGFloat = 300
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    // 裁剪区域
                    ZStack {
                        // 原始图片
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale *= delta
                                        // 限制缩放范围
                                        scale = max(0.5, min(scale, 5.0))
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                    }
                            )
                            .simultaneousGesture(
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
                            )
                        
                        // 裁剪遮罩
                        Rectangle()
                            .fill(Color.black.opacity(0.5))
                            .mask(
                                Canvas { context, size in
                                    context.fill(
                                        Path(CGRect(origin: .zero, size: size)),
                                        with: .color(.white)
                                    )
                                    context.blendMode = .destinationOut
                                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                                    context.fill(
                                        Circle().path(in: CGRect(
                                            x: center.x - cropSize / 2,
                                            y: center.y - cropSize / 2,
                                            width: cropSize,
                                            height: cropSize
                                        )),
                                        with: .color(.white)
                                    )
                                }
                            )
                            .allowsHitTesting(false)
                        
                        // 裁剪边框
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: cropSize, height: cropSize)
                            .allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 提示文字
                    Text("image.crop.instruction".localized)
                        .foregroundColor(.white)
                        .padding()
                }
            }
            .navigationTitle("image.crop.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("done".localized) {
                        cropImage()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    /// 裁剪图片
    private func cropImage() {
        // 获取屏幕上实际用于显示图片的区域大小
        let screenBounds = UIScreen.main.bounds
        let imageSize = image.size
        
        // 计算图片按 scaledToFit 显示的实际尺寸
        let imageAspect = imageSize.width / imageSize.height
        let screenAspect = screenBounds.width / screenBounds.height
        
        var displaySize: CGSize
        if imageAspect > screenAspect {
            // 图片更宽，以宽度为准
            displaySize = CGSize(
                width: screenBounds.width,
                height: screenBounds.width / imageAspect
            )
        } else {
            // 图片更高，以高度为准
            displaySize = CGSize(
                width: screenBounds.height * imageAspect,
                height: screenBounds.height
            )
        }
        
        // 应用用户的缩放和偏移
        let scaledDisplaySize = CGSize(
            width: displaySize.width * scale,
            height: displaySize.height * scale
        )
        
        // 计算裁剪框中心在屏幕上的位置
        let cropCenterInScreen = CGPoint(
            x: screenBounds.width / 2,
            y: screenBounds.height / 2
        )
        
        // 计算图片中心在屏幕上的位置（考虑偏移）
        let imageCenterInScreen = CGPoint(
            x: screenBounds.width / 2 + offset.width,
            y: screenBounds.height / 2 + offset.height
        )
        
        // 计算裁剪框在图片坐标系中的位置
        let cropOriginInImage = CGPoint(
            x: (cropCenterInScreen.x - imageCenterInScreen.x + scaledDisplaySize.width / 2) / scaledDisplaySize.width * imageSize.width - cropSize / 2 / scaledDisplaySize.width * imageSize.width,
            y: (cropCenterInScreen.y - imageCenterInScreen.y + scaledDisplaySize.height / 2) / scaledDisplaySize.height * imageSize.height - cropSize / 2 / scaledDisplaySize.height * imageSize.height
        )
        
        let cropRectInImage = CGRect(
            x: cropOriginInImage.x,
            y: cropOriginInImage.y,
            width: cropSize / scaledDisplaySize.width * imageSize.width,
            height: cropSize / scaledDisplaySize.height * imageSize.height
        )
        
        // 使用 CGImage 裁剪
        guard let cgImage = image.cgImage,
              let croppedCGImage = cgImage.cropping(to: cropRectInImage) else {
            onCrop(nil)
            dismiss()
            return
        }
        
        // 创建裁剪后的方形图片
        let croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
        
        // 渲染为正方形并应用圆形遮罩
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropSize, height: cropSize))
        let finalImage = renderer.image { context in
            // 先设置圆形裁剪路径
            let path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: CGSize(width: cropSize, height: cropSize)))
            path.addClip()
            
            // 绘制裁剪后的图片，保持宽高比
            croppedImage.draw(in: CGRect(origin: .zero, size: CGSize(width: cropSize, height: cropSize)))
        }
        
        onCrop(finalImage)
        dismiss()
    }
}

#elseif os(macOS)
/// macOS 图片裁剪视图
struct ImageCropView: View {
    let image: NSImage
    let onCrop: (NSImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    private let cropSize: CGFloat = 300
    
    var body: some View {
        VStack {
            Text("图片裁剪")
                .font(.headline)
            
            Text("macOS暂不支持交互式裁剪")
                .foregroundColor(.secondary)
            
            HStack {
                Button("取消") {
                    dismiss()
                }
                
                Button("使用原图") {
                    onCrop(image)
                    dismiss()
                }
            }
            .padding()
        }
        .frame(width: 400, height: 300)
    }
}
#endif

#Preview {
    #if os(iOS)
    ImageCropView(image: UIImage(systemName: "person.circle")!) { _ in }
    #else
    ImageCropView(image: NSImage(systemSymbolName: "person.circle", accessibilityDescription: nil)!) { _ in }
    #endif
}
