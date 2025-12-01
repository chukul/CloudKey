import SwiftUI

struct TOTPSetupView: View {
    let profileAlias: String
    @Binding var isPresented: Bool
    @State private var totpSecret = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var testCode = ""
    @State private var isValidating = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Setup TOTP Authenticator")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Add your TOTP secret to auto-generate MFA codes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)
            
            Divider()
            
            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("How to get your TOTP secret:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Option 1: Re-add to AWS (Recommended)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    InstructionRow(number: "1", text: "Go to AWS IAM Console → Your User → Security Credentials")
                    InstructionRow(number: "2", text: "Click 'Manage' next to MFA device")
                    InstructionRow(number: "3", text: "Remove existing MFA and add new one")
                    InstructionRow(number: "4", text: "When QR code appears, click 'Show secret key'")
                    InstructionRow(number: "5", text: "Copy the secret key and paste below")
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    Text("Option 2: Export from Microsoft Authenticator")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    InstructionRow(number: "1", text: "Open Microsoft Authenticator")
                    InstructionRow(number: "2", text: "Tap ⋯ menu → Settings → Backup")
                    InstructionRow(number: "3", text: "Export accounts (requires Microsoft account)")
                    
                    Text("Note: Microsoft Authenticator doesn't show secrets directly for security")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Secret input
            VStack(alignment: .leading, spacing: 8) {
                Text("TOTP Secret Key")
                    .font(.headline)
                
                TextField("Enter your TOTP secret (e.g., JBSWY3DPEHPK3PXP)", text: $totpSecret)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: totpSecret) { _ in
                        validateSecret()
                    }
                
                if !testCode.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Valid secret! Test code: \(testCode)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if showError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    saveTOTPSecret()
                }
                .buttonStyle(.borderedProminent)
                .disabled(testCode.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 550, height: 700)
    }
    
    func validateSecret() {
        testCode = ""
        showError = false
        
        guard !totpSecret.isEmpty else { return }
        
        if TOTPService.shared.validateSecret(totpSecret) {
            if let code = TOTPService.shared.generateTOTPCode(from: totpSecret) {
                testCode = code
            }
        } else {
            showError = true
            errorMessage = "Invalid TOTP secret format"
        }
    }
    
    func saveTOTPSecret() {
        if TOTPService.shared.storeTOTPSecret(for: profileAlias, secret: totpSecret) {
            isPresented = false
        } else {
            showError = true
            errorMessage = "Failed to save TOTP secret"
        }
    }
}

struct InstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    TOTPSetupView(profileAlias: "Test Profile", isPresented: .constant(true))
}
