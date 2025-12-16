import SwiftUI
import PhotosUI

struct SeparateMessageInputField: View {
    @Binding var text: String
    var onSendTapped: (() -> Void)? = nil
    var onImageSelected: ((UIImage) -> Void)? = nil
    
    @State private var isPlusPressed: Bool = false
    @State private var isFieldPressed: Bool = false
    @State private var isMenuActivating: Bool = false
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var cameraSourceType: UIImagePickerController.SourceType = .photoLibrary
    private let pressScale: CGFloat = 1.06
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 顶层：保持原有的样式与交互完全不变
            HStack(alignment: .bottom, spacing: 8) {

                // 1. 左侧的加号按钮 (独立于输入框), 点击后弹出 Menu
                Menu {
                    #if !os(visionOS)
                    Button {
                        cameraSourceType = .camera
                        showCamera = true
                    } label: {
                        Label("相机", systemImage: "camera.fill")
                    }
                    #endif
                    Button {
                        showImagePicker = true
                    } label: {
                        Label("照片", systemImage: "photo.on.rectangle")
                    }
                    #if os(iOS)
                    Button {
                        // 拟我表情功能
                        showMemojiPicker()
                    } label: {
                        Label("拟我表情", systemImage: "face.smiling")
                    }
                    #endif
                } label: {
                    // 将加号按钮的样式改为与输入框背景一致
                    ZStack {
                        Group {
                            if #available(iOS 26.0, *) {
                                #if os(visionOS)
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.black.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                #else
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(.clear)
                                    .glassEffect(
                                        .regular,
                                        in: .rect(cornerRadius: 18)
                                    )
                                #endif
                            } else {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.black.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            }
                        }
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .frame(width: 36, height: 36)
                    .scaleEffect(isPlusPressed ? pressScale : 1.0)
                    .animation(.easeOut(duration: 0.15), value: isPlusPressed)
                    .onLongPressGesture(minimumDuration: 0, pressing: { isPressing in
                        withAnimation(.easeOut(duration: 0.15)) {
                            isPlusPressed = isPressing
                            isMenuActivating = isPressing
                        }
                        if !isPressing {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    isMenuActivating = false
                                }
                            }
                        }
                    }, perform: {})
                }

                // 2. 主文本输入框及背景，右侧包含麦克风/发送按钮
                ZStack(alignment: .leading) {
                    TextField("", text: $text, axis: .vertical)
                        .foregroundColor(.white)
                        .padding(8)
                        .padding(.trailing, 36)
                        .background(
                            Group {
                                if #available(iOS 26.0, *) {
                                    #if os(visionOS)
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color.black.opacity(0.3))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                    #else
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(.clear)
                                        .glassEffect(
                                            .regular,
                                            in: .rect(cornerRadius: 18)
                                        )
                                    #endif
                                } else {
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color.black.opacity(0.3))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                }
                            }
                        )
                        .overlay(alignment: .bottomTrailing) {
                            Button {
                                if !text.isEmpty {
                                    onSendTapped?()
                                    text = ""
                                } else {
                                    print("Voice button tapped")
                                }
                            } label: {
                                Image(systemName: text.isEmpty ? "microphone" : "arrow.up.circle.fill")
                                    .symbolRenderingMode(text.isEmpty ? .monochrome : .palette)
                                    .font(.title2)
                                    .foregroundStyle(
                                        text.isEmpty ? Color.white : Color.white,
                                        text.isEmpty ? Color.white : Color.accentColor
                                    )
                                    .frame(width: 32, height: 32)
                            }
                            .padding(.trailing, 4)
                            .padding(.bottom, 4)
                        }
                        .overlay(alignment: .leading) {
                            if text.isEmpty {
                                Text("评论")
                                    .foregroundColor(.gray)
                                    .padding(.leading, 8)
                                    .padding(.vertical, 8)
                            }
                        }
                        .frame(minHeight: 36)
                }
                .scaleEffect(isFieldPressed ? pressScale : 1.0)
                .animation(.easeOut(duration: 0.15), value: isFieldPressed)
                .onLongPressGesture(minimumDuration: 0, pressing: { isPressing in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isFieldPressed = isPressing
                    }
                }, perform: {})
            }
        }
        .padding(.horizontal, 16)
        .background(Color.clear)
        .sheet(isPresented: $showImagePicker) {
            PhotosPickerView { image in
                onImageSelected?(image)
            }
        }
        #if !os(visionOS)
        .sheet(isPresented: $showCamera) {
            CameraPickerView(sourceType: .camera) { image in
                onImageSelected?(image)
            }
        }
        #endif
    }
    
    private func showMemojiPicker() {
        // 打开系统的拟我表情选择器
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            let memojiViewController: UIViewController?
            #if !os(visionOS)
            memojiViewController = UIStoryboard(name: "Main", bundle: nil)
                .instantiateViewController(withIdentifier: "MemojiPickerViewController")
            #else
            memojiViewController = nil
            #endif
            if let memojiVC = memojiViewController {
                rootViewController.present(memojiVC, animated: true)
            } else {
                let alertController = UIAlertController(title: "拟我表情", message: "拟我表情将作为表情图片发送", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "了解", style: .default) { [weak rootViewController] _ in
                    rootViewController?.dismiss(animated: true)
                })
                rootViewController.present(alertController, animated: true)
            }
        }
    }
}

// MARK: - Photos Picker View (Using PhotosUI)
struct PhotosPickerView: UIViewControllerRepresentable {
    var onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> ImagePickerCoordinator {
        ImagePickerCoordinator(onImageSelected: onImageSelected, dismiss: dismiss)
    }
    
    class ImagePickerCoordinator: NSObject, PHPickerViewControllerDelegate {
        var onImageSelected: (UIImage) -> Void
        var dismiss: DismissAction
        
        init(onImageSelected: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImageSelected = onImageSelected
            self.dismiss = dismiss
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            dismiss()
            
            guard let result = results.first else { return }
            
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                if let image = image as? UIImage {
                    DispatchQueue.main.async {
                        self?.onImageSelected(image)
                    }
                }
            }
        }
    }
}

// MARK: - Camera Picker View (Using UIImagePickerController)
struct CameraPickerView: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    var onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> CameraPickerCoordinator {
        CameraPickerCoordinator(onImageSelected: onImageSelected, dismiss: dismiss)
    }
    
    class CameraPickerCoordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onImageSelected: (UIImage) -> Void
        var dismiss: DismissAction
        
        init(onImageSelected: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImageSelected = onImageSelected
            self.dismiss = dismiss
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImageSelected(image)
            }
            dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

// MARK: - Memoji Picker
class EmojiPickerViewController: UIViewController {
    var onEmojiSelected: ((UIImage) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 创建拟我表情选择器（仅在 iOS 13.1+ 支持）
        if #available(iOS 13.1, *) {
            #if !os(visionOS)
            _ = UIStoryboard(name: "Main", bundle: nil)
                .instantiateViewController(withIdentifier: "MemojiPickerViewController")
            #endif
            
            // 如果系统提供的拟我表情选择器不可用，显示提示
            let alertController = UIAlertController(title: "拟我表情", message: "拟我表情将作为表情图片发送", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "了解", style: .default) { [weak self] _ in
                self?.dismiss(animated: true)
            })
            present(alertController, animated: true)
        }
    }
}

// 预览视图 (保持不变)
struct SeparateContentView: View {
    @State private var messageText: String = ""
    
    var body: some View {
        ZStack {
            // 模拟聊天界面的背景
            Color.gray.opacity(0.8).edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                SeparateMessageInputField(text: $messageText)
                    .padding(.vertical, 8)
                    .background(
                        // 提供一个与系统一致的半透明毛玻璃背景，便于悬浮在键盘上方
                        VisualEffectBlur()
                            .clipShape(RoundedRectangle(cornerRadius: 0))
                            .opacity(0.0) // 如果你暂时不想要毛玻璃，可保持为0
                    )
            }
            .ignoresSafeArea(.keyboard)
        }
    }
}

#Preview {
    SeparateContentView()
}

