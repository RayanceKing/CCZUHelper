import SwiftUI
import PhotosUI
import Speech

struct SeparateMessageInputField: View {
    @Binding var text: String
    @Binding var isAnonymous: Bool
    @Binding var isLoading: Bool
    var onSendTapped: (() -> Void)? = nil
    
    @State private var isPlusPressed: Bool = false
    @State private var isFieldPressed: Bool = false
    @State private var isMenuActivating: Bool = false
    @State private var isRecording = false
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: Locale.preferredLanguages.first ?? "zh-CN"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    private let pressScale: CGFloat = 1.06
    
    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(alignment: .bottom, spacing: 8) {
                // 1. 左侧的加号按钮 (独立于输入框), 点击后弹出 Menu
                Menu {
                    Button(action: {
                        isAnonymous.toggle()
                    }) {
                        Label(
                            isAnonymous ? "取消匿名" : "设为匿名",
                            systemImage: isAnonymous ? "eye.fill" : "eye.slash.fill"
                        )
                    }
                } label: {
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
                        Image(systemName: isAnonymous ? "eye.slash.fill" : "eye.fill")
                            .font(.title2)
                            .foregroundColor(isAnonymous ? .orange : Color.primary)
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
                // 2. 主文本输入框及背景，右侧包含发送按钮
                ZStack(alignment: .leading) {
                    TextField("", text: $text, axis: .vertical)
                        .foregroundColor(Color(UIColor { trait in
                            trait.userInterfaceStyle == .dark ? .white : .black
                        }))
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
                                            .regular.interactive(),
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
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .frame(width: 32, height: 32)
                                    .padding(.trailing, 4)
                                    .padding(.bottom, 4)
                            } else {
                                Button {
                                    if !text.isEmpty {
                                        onSendTapped?()
                                    } else {
                                        if isRecording {
                                            stopRecording()
                                        } else {
                                            requestSpeechAuthAndStart()
                                        }
                                    }
                                } label: {
                                    Image(systemName: text.isEmpty ? (isRecording ? "stop.circle.fill" : "microphone") : "arrow.up.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(Color.gray.opacity(0.5))
                                        .frame(width: 32, height: 32)
                                }
                                .padding(.trailing, 4)
                                .padding(.bottom, 4)
                            }
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
    }
    
    // MARK: - 语音识别
    private func requestSpeechAuthAndStart() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            if authStatus == .authorized {
                startRecording()
            } else {
                // 可选：弹窗提示用户未授权
            }
        }
    }

    private func startRecording() {
        isRecording = true
        recognitionTask?.cancel()
        recognitionTask = nil
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            isRecording = false
            return
        }
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            isRecording = false
            return
        }
        let inputNode = audioEngine.inputNode
        recognitionRequest.shouldReportPartialResults = true
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                text = result.bestTranscription.formattedString
            }
            if error != nil || (result?.isFinal ?? false) {
                stopRecording()
            }
        }
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            stopRecording()
        }
    }

    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        isRecording = false
    }
}

// 预览视图
//struct SeparateContentView: View {
//    @State private var messageText: String = ""
//    @State private var isAnonymous: Bool = false
//    
//    var body: some View {
//        ZStack {
//            // 模拟聊天界面的背景
//            Color.gray.opacity(0.8).edgesIgnoringSafeArea(.all)
//            
//            VStack {
//                Spacer()
//            }
//            .safeAreaInset(edge: .bottom) {
//                SeparateMessageInputField(text: $messageText, isAnonymous: $isAnonymous)
//                    .padding(.vertical, 8)
//                    .background(
//                        // 提供一个与系统一致的半透明毛玻璃背景，便于悬浮在键盘上方
//                        VisualEffectBlur()
//                            .clipShape(RoundedRectangle(cornerRadius: 0))
//                            .opacity(0.0) // 如果你暂时不想要毛玻璃，可保持为0
//                    )
//            }
//            .ignoresSafeArea(.keyboard)
//        }
//    }
//}

#Preview {
    SeparateMessageInputField(
        text: .constant(""),
        isAnonymous: .constant(false),
        isLoading: .constant(false)
    )
}

