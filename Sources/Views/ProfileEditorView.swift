import SwiftUI

struct ProfileEditorView: View {
    let initialSession: Session
    let onSave: (Session) -> Void
    let onCancel: () -> Void
    
    @State private var alias: String
    @State private var profileName: String
    @State private var type: SessionType
    @State private var region: String
    @State private var accountId: String
    @State private var roleArn: String
    @State private var mfaSerial: String
    @State private var accessKey: String
    @State private var secretKey: String
    @State private var sourceProfile: String
    @State private var group: String
    
    init(session: Session, onSave: @escaping (Session) -> Void, onCancel: @escaping () -> Void) {
        self.initialSession = session
        self.onSave = onSave
        self.onCancel = onCancel
        
        _alias = State(initialValue: session.alias)
        _profileName = State(initialValue: session.profileName)
        _type = State(initialValue: session.type)
        _region = State(initialValue: session.region)
        _accountId = State(initialValue: session.accountId)
        _roleArn = State(initialValue: session.roleArn ?? "")
        _mfaSerial = State(initialValue: session.mfaSerial ?? "")
        _accessKey = State(initialValue: session.accessKeyId ?? "")
        _secretKey = State(initialValue: "")
        _sourceProfile = State(initialValue: session.sourceProfile ?? "")
        _group = State(initialValue: session.group ?? "")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: initialSession.alias.isEmpty ? "plus.circle.fill" : "pencil.circle.fill")
                        .font(.title)
                        .foregroundColor(.accentColor)
                    
                    Text(initialSession.alias.isEmpty ? "New Profile" : "Edit Profile")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                
                if !initialSession.alias.isEmpty {
                    HStack {
                        Text("Editing: \(initialSession.alias)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Form Content
            ScrollView {
                VStack(spacing: 24) {
                    // Basic Information
                    GroupBox {
                        VStack(spacing: 16) {
                            ModernTextField(
                                label: "Alias",
                                placeholder: "My AWS Profile",
                                text: $alias,
                                icon: "tag.fill"
                            )
                            
                            ModernTextField(
                                label: "Profile Name",
                                placeholder: "default",
                                text: $profileName,
                                icon: "person.fill"
                            )
                            
                            ModernTextField(
                                label: "Group (Optional)",
                                placeholder: "Dev, Prod, Personal, etc.",
                                text: $group,
                                icon: "folder.fill"
                            )
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Type", systemImage: "list.bullet.circle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Picker("", selection: $type) {
                                    ForEach(SessionType.allCases, id: \.self) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        .padding(4)
                    } label: {
                        Label("Basic Information", systemImage: "info.circle.fill")
                            .font(.headline)
                    }
                    
                    // AWS Configuration
                    GroupBox {
                        VStack(spacing: 16) {
                            ModernTextField(
                                label: "Region",
                                placeholder: "us-east-1",
                                text: $region,
                                icon: "globe"
                            )
                            
                            ModernTextField(
                                label: "Account ID",
                                placeholder: "123456789012",
                                text: $accountId,
                                icon: "number"
                            )
                            
                            if type == .iamUser {
                                ModernTextField(
                                    label: "Access Key ID",
                                    placeholder: "AKIA...",
                                    text: $accessKey,
                                    icon: "key.fill"
                                )
                                
                                ModernSecureField(
                                    label: "Secret Access Key",
                                    placeholder: "Enter secret key",
                                    text: $secretKey,
                                    icon: "lock.fill"
                                )
                            }
                            
                            if type == .assumedRole {
                                ModernTextField(
                                    label: "Source Profile",
                                    placeholder: "default or IAM profile name",
                                    text: $sourceProfile,
                                    icon: "person.fill"
                                )
                                
                                ModernTextField(
                                    label: "Role ARN",
                                    placeholder: "arn:aws:iam::123456789012:role/RoleName",
                                    text: $roleArn,
                                    icon: "key.fill"
                                )
                            }
                        }
                        .padding(4)
                    } label: {
                        Label("AWS Configuration", systemImage: "cloud.fill")
                            .font(.headline)
                    }
                    
                    // MFA (Optional)
                    GroupBox {
                        VStack(spacing: 12) {
                            ModernTextField(
                                label: "MFA Serial ARN (Optional)",
                                placeholder: "arn:aws:iam::123456789012:mfa/username",
                                text: $mfaSerial,
                                icon: "lock.shield.fill"
                            )
                            
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.secondary)
                                Text("Required for roles that enforce MFA")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                        .padding(4)
                    } label: {
                        Label("Multi-Factor Authentication", systemImage: "checkmark.shield.fill")
                            .font(.headline)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .frame(minWidth: 80)
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)
                
                Spacer()
                
                Button(action: {
                    var updatedSession = initialSession
                    updatedSession.alias = alias
                    updatedSession.profileName = profileName
                    updatedSession.type = type
                    updatedSession.region = region
                    updatedSession.accountId = accountId
                    updatedSession.roleArn = roleArn.isEmpty ? nil : roleArn
                    updatedSession.mfaSerial = mfaSerial.isEmpty ? nil : mfaSerial
                    updatedSession.sourceProfile = sourceProfile.isEmpty ? nil : sourceProfile
                    updatedSession.group = group.isEmpty ? nil : group
                    
                    // For IAM users, save credentials to ~/.aws/credentials
                    if type == .iamUser && !accessKey.isEmpty && !secretKey.isEmpty {
                        saveIAMCredentials(profile: profileName, accessKey: accessKey, secretKey: secretKey)
                    }
                    
                    onSave(updatedSession)
                }) {
                    Label("Save Profile", systemImage: "checkmark.circle.fill")
                        .frame(minWidth: 120)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(alias.isEmpty || profileName.isEmpty)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 650, height: 600)
    }
    
    private func saveIAMCredentials(profile: String, accessKey: String, secretKey: String) {
        let credentialsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".aws/credentials")
        
        var content = ""
        if FileManager.default.fileExists(atPath: credentialsURL.path) {
            content = (try? String(contentsOf: credentialsURL, encoding: .utf8)) ?? ""
        }
        
        var lines = content.components(separatedBy: .newlines)
        
        // Remove existing section if present
        if let startIndex = lines.firstIndex(of: "[\(profile)]") {
            var endIndex = startIndex + 1
            while endIndex < lines.count && !lines[endIndex].hasPrefix("[") {
                endIndex += 1
            }
            lines.removeSubrange(startIndex..<endIndex)
        }
        
        // Append new section
        lines.append("[\(profile)]")
        lines.append("aws_access_key_id = \(accessKey)")
        lines.append("aws_secret_access_key = \(secretKey)")
        lines.append("")
        
        let newContent = lines.joined(separator: "\n")
        try? newContent.write(to: credentialsURL, atomically: true, encoding: .utf8)
    }
}

struct ModernTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundColor(isFocused ? .accentColor : .secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .focused($isFocused)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

struct ModernSecureField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundColor(isFocused ? .accentColor : .secondary)
            
            SecureField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .focused($isFocused)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}
