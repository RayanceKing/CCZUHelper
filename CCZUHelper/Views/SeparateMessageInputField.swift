import SwiftUI
#if canImport(Speech)
import Speech
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

struct SeparateMessageInputField: View {
    @Binding var text: String
    @Binding var isAnonymous: Bool
    let isLoading: Bool
    let isAuthenticated: Bool
    let onSend: () -> Void
    let onRequireLogin: () -> Void

    private let barHeight: CGFloat = 36
    private let sendButtonHeight: CGFloat = 28
    private let sendButtonWidth: CGFloat = 34
    private let pressScale: CGFloat = 1.055
    @State private var isLeftPressed = false
    @State private var isFieldPressed = false
    @State private var isRecording = false

#if canImport(Speech) && canImport(AVFoundation)
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: Locale.preferredLanguages.first ?? "zh-CN"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
#endif

    var body: some View {
        HStack(alignment: .center, spacing: isAnyPressed ? -4 : 8) {
            Menu {
                Button(action: { isAnonymous.toggle() }) {
                    Label(
                        isAnonymous ? "teahouse.comment.anonymous.disable".localized : "teahouse.comment.anonymous.enable".localized,
                        systemImage: isAnonymous ? "eye.fill" : "eye.slash.fill"
                    )
                }
            } label: {
                ZStack {
                    circleBackground
                    Image(systemName: isAnonymous ? "eye.slash.fill" : "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isAnonymous ? .orange : .blue)
                }
                .frame(width: barHeight, height: barHeight)
                .contentShape(Circle())
                .scaleEffect(isLeftPressed ? pressScale : 1.0)
                .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                        isLeftPressed = pressing
                    }
                }, perform: {})
            }
            .buttonStyle(.plain)
            .disabled(!isAuthenticated)

            HStack(alignment: .center, spacing: 8) {
                TextField("teahouse.post.comment.placeholder".localized, text: $text)
                    .disabled(!isAuthenticated || isLoading)
                    .submitLabel(.send)
                    .font(.system(size: 16))
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .onSubmit {
                        triggerSend()
                    }

                if isLoading {
                    ProgressView()
                        .frame(width: barHeight, height: barHeight)
                } else {
                    Button(action: { triggerPrimaryAction() }) {
                        if hasTypedText {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: sendButtonWidth, height: sendButtonHeight)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.blue)
                                )
                        } else {
                            Image(systemName: isRecording ? "stop.circle.fill" : "microphone")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: sendButtonHeight, height: sendButtonHeight)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: barHeight)
            .background(capsuleBackground)
            .animation(.easeInOut(duration: 0.18), value: canSend)
            .scaleEffect(isFieldPressed ? pressScale : 1.0)
            .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
                withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                    isFieldPressed = pressing
                }
            }, perform: {})
            .overlay {
                if !isAuthenticated {
                    Color.clear
                        .contentShape(Capsule())
                        .onTapGesture(perform: onRequireLogin)
                }
            }
        }
        .padding(.horizontal, 2)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isAnyPressed)
        .onDisappear {
            stopRecording()
        }
    }

    private var canSend: Bool {
        isAuthenticated && !isLoading && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasTypedText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isAnyPressed: Bool {
        isLeftPressed || isFieldPressed
    }

    private func triggerSend() {
        guard isAuthenticated else {
            onRequireLogin()
            return
        }
        if canSend {
            onSend()
        }
    }

    private func triggerPrimaryAction() {
        guard isAuthenticated else {
            onRequireLogin()
            return
        }
        if hasTypedText {
            triggerSend()
            return
        }
        if isRecording {
            stopRecording()
        } else {
            requestSpeechAuthAndStart()
        }
    }

    private func requestSpeechAuthAndStart() {
#if canImport(Speech) && canImport(AVFoundation)
        SFSpeechRecognizer.requestAuthorization { authStatus in
            guard authStatus == .authorized else { return }
            DispatchQueue.main.async {
                startRecording()
            }
        }
#endif
    }

    private func startRecording() {
#if canImport(Speech) && canImport(AVFoundation)
        guard !audioEngine.isRunning else { return }
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

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
            if let result {
                DispatchQueue.main.async {
                    text = result.bestTranscription.formattedString
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                DispatchQueue.main.async {
                    stopRecording()
                }
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            stopRecording()
        }
#endif
    }

    private func stopRecording() {
#if canImport(Speech) && canImport(AVFoundation)
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
#endif
        isRecording = false
    }

    @ViewBuilder
    private var circleBackground: some View {
        if #available(iOS 26.0, *) {
            Circle()
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: .circle)
                .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 0.5))
        } else {
            Circle()
                .fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private var capsuleBackground: some View {
        if #available(iOS 26.0, *) {
            Capsule(style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: .capsule)
                .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.2), lineWidth: 0.5))
        } else {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}

#Preview {
    SeparateMessageInputField(
        text: .constant(""),
        isAnonymous: .constant(false),
        isLoading: false,
        isAuthenticated: true,
        onSend: {},
        onRequireLogin: {}
    )
}
