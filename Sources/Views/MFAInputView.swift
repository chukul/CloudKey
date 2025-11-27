import SwiftUI
import AppKit

struct MFAInputView: View {
    @Binding var mfaToken: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enter MFA Token")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Please enter the 6-digit code from your MFA device.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            MacTextField(text: $mfaToken, placeholder: "Token Code", onSubmit: onSubmit)
                .frame(width: 200, height: 30)
            
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
