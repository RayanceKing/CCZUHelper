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

    private let barHeight: CGFloat = 50
    private let leftButtonSize: CGFloat = 48
    private let sendButtonHeight: CGFloat = 34
    private let sendButtonWidth: CGFloat = 42
    private let pressScale: CGFloat = 1.04
    @State private var isLeftPressed = false
    @State private var isFieldPressed = false
    @State private var isRecording = false

#if canImport(Speech) && canImport(AVFoundation)
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: Locale.preferredLanguages.first ?? "zh-CN"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
#endif

    @ViewBuilder
    var body: some View {
        #if os(visionOS)
        inputRow
        #else
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: isAnyPressed ? -8 : 8) {
                inputRow
            }
        } else {
            inputRow
        }
        #endif
    }

    private var inputRow: some View {
        HStack(alignment: .center) {
            Menu {
                Button(action: { isAnonymous.toggle() }) {
                    Label(
                        isAnonymous ? "teahouse.comment.anonymous.disable".localized : "teahouse.comment.anonymous.enable".localized,
                        systemImage: isAnonymous ? "eye.fill" : "eye.slash.fill"
                    )
                }
            } label: {
                Image(systemName: isAnonymous ? "eye.slash.fill" : "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.primary)
                .frame(width: leftButtonSize, height: leftButtonSize)
                .contentShape(Circle())
                .modifier(InteractiveGlassCircle())
                .scaleEffect(isLeftPressed ? pressScale : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(!isAuthenticated)

            HStack(alignment: .center, spacing: 8) {
                TextField(
                    "",
                    text: $text,
                    prompt: Text("teahouse.post.comment.placeholder".localized)
                        .foregroundStyle(.primary.opacity(0.52))
                )
                    .disabled(!isAuthenticated || isLoading)
                    .submitLabel(.send)
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(.primary)
                    .tint(.primary)
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
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: sendButtonWidth, height: sendButtonHeight)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(sendButtonBackground)
                                )
                        } else {
                            Image(systemName: isRecording ? "stop.circle.fill" : "microphone")
                                .font(.system(size: 26, weight: .regular))
                                .foregroundStyle(.primary.opacity(isRecording ? 1 : 0.95))
                                .frame(width: 34, height: 34)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: barHeight)
            .modifier(InteractiveGlassCapsule())
            .animation(.easeInOut(duration: 0.18), value: canSend)
            .scaleEffect(isFieldPressed ? pressScale : 1.0)
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

    private var sendButtonBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.03, green: 0.63, blue: 0.98),
                Color(red: 0.02, green: 0.47, blue: 0.88)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

}

private struct InteractiveGlassCircle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(visionOS)
        content
            .background(
                Circle().fill(.ultraThinMaterial)
            )
        #else
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(.clear.interactive(), in: .circle)
        } else {
            content
                .background(
                    Circle().fill(.ultraThinMaterial)
                )
        }
        #endif
    }
}

private struct InteractiveGlassCapsule: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(visionOS)
        content
            .background(
                Capsule(style: .continuous).fill(.ultraThinMaterial)
            )
        #else
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(.clear.interactive(), in: .capsule)
        } else {
            content
                .background(
                    Capsule(style: .continuous).fill(.ultraThinMaterial)
                )
        }
        #endif
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
