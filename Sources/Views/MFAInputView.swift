import SwiftUI
import AppKit

struct MFAInputView: View {
    @Binding var mfaToken: String
    let profileAlias: String?
    let onSubmit: () -> Void
    let onCancel: () -> Void
    @State private var totpCode: String = ""
    @State private var timeRemaining: Int = 30
    @State private var timer: Timer?
    
    var hasTOTP: Bool {
        guard let alias = profileAlias else { return false }
        return TOTPService.shared.hasTOTPSecret(for: alias)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enter MFA Token")
                .font(.title2)
                .fontWeight(.semibold)
            
            if hasTOTP {
                Text("Auto-generated TOTP code or enter manually")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Please enter the 6-digit code from your MFA device.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // TOTP auto-fill section
            if hasTOTP {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Text(totpCode.isEmpty ? "------" : totpCode)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(totpCode.isEmpty ? .secondary : .primary)
                        
                        VStack(spacing: 4) {
                            Text("\(timeRemaining)s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ProgressView(value: Double(timeRemaining), total: 30)
                                .frame(width: 40)
                        }
                    }
                    
                    Button(action: {
                        mfaToken = totpCode
                    }) {
                        Label("Use This Code", systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(totpCode.isEmpty)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                Text("or enter manually:")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 8) {
                MacTextField(text: $mfaToken, placeholder: "Token Code", onSubmit: onSubmit)
                    .frame(width: 200, height: 30)
                
                Button(action: {
                    if let clipboard = NSPasteboard.general.string(forType: .string) {
                        // Extract only digits from clipboard
                        let digits = clipboard.filter { $0.isNumber }
                        if digits.count == 6 {
                            mfaToken = digits
                        } else {
                            mfaToken = clipboard
                        }
                    }
                }) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .help("Paste from clipboard")
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Submit") {
                    onSubmit()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(mfaToken.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 400)
        .onAppear {
            if hasTOTP {
                updateTOTPCode()
                startTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    func updateTOTPCode() {
        guard let alias = profileAlias else { return }
        totpCode = TOTPService.shared.generateTOTPCode(for: alias) ?? ""
        timeRemaining = TOTPService.shared.getTimeRemaining()
    }
    
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            timeRemaining = TOTPService.shared.getTimeRemaining()
            if timeRemaining == 30 {
                updateTOTPCode()
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

struct MacTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.font = NSFont.monospacedSystemFont(ofSize: 20, weight: .regular)
        textField.alignment = .center
        textField.delegate = context.coordinator
        textField.bezelStyle = .roundedBezel
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
        if nsView.window?.firstResponder != nsView.currentEditor() {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MacTextField
        
        init(_ parent: MacTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}
