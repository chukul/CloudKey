import SwiftUI

struct DetailView: View {
    @EnvironmentObject var store: SessionStore
    let session: Session
    @State private var selectedTab = 0
    @State private var showMFAAlert = false
    @State private var mfaToken = ""
    @State private var showCopiedNotification = false
    @State private var isStarting = false
    
    // Get live session from store
    private var liveSession: Session {
        store.sessions.first(where: { $0.id == session.id }) ?? session
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                // Status badge with animation
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    Text(session.status.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.1))
                .cornerRadius(12)
                .transition(.scale.combined(with: .opacity))
                
                Spacer()
                
                // Quick actions
                HStack(spacing: 12) {
                    if liveSession.status == .active {
                        Button(action: {
                            Task {
                                let updated = await AWSService.shared.openAWSConsole(for: liveSession)
                                await MainActor.run {
                                    store.updateSession(updated)
                                }
                            }
                        }) {
                            Label("Open Console", systemImage: "globe")
                        }
                        .controlSize(.large)
                        
                        Menu {
                            Button(action: { copyToClipboard(session.alias) }) {
                                Label("Copy Profile Name", systemImage: "doc.on.doc")
                            }
                            if let keyId = session.accessKeyId {
                                Button(action: { copyToClipboard(keyId) }) {
                                    Label("Copy Access Key", systemImage: "key")
                                }
                            }
                            
                            Divider()
                            
                            Menu("Export As...") {
                                Button(action: { copyExportCommands() }) {
                                    Label("Shell Export", systemImage: "terminal")
                                }
                                Button(action: { copyAsJSON() }) {
                                    Label("JSON Format", systemImage: "doc.text")
                                }
                                Button(action: { copyAsAWSCLI() }) {
                                    Label("AWS CLI Config", systemImage: "command")
                                }
                            }
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .menuStyle(.borderlessButton)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    
                    Button(action: {
                        if session.status == .active {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isStarting = true
                            }
                            store.toggleSession(session)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isStarting = false
                            }
                        } else {
                            // Check if MFA is required and if we have cached token
                            if let mfaSerial = session.mfaSerial,
                               let sourceProfile = session.sourceProfile {
                                let hasCached = AWSService.shared.hasCachedMFAToken(sourceProfile: sourceProfile, mfaSerial: mfaSerial)
                                print("🔍 UI (DetailView): Checking cache for \(session.alias), hasCached: \(hasCached)")
                                
                                if !hasCached {
                                    // Show MFA prompt
                                    showMFAAlert = true
                                } else {
                                    // Use cached token
                                    print("🔍 UI (DetailView): Using cached token, calling toggleSession without MFA")
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        isStarting = true
                                    }
                                    store.toggleSession(session)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        isStarting = false
                                    }
                                }
                            } else {
                                // No MFA required
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isStarting = true
                                }
                                store.toggleSession(session)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isStarting = false
                                }
                            }
                        }
                    }) {
                        HStack {
                            if isStarting {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: session.status == .active ? "stop.circle.fill" : "play.circle.fill")
                            }
                            Text(session.status == .active ? "Stop" : "Start")
                        }
                        .frame(minWidth: 100)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .tint(session.status == .active ? .red : .green)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(isStarting)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .animation(.easeInOut(duration: 0.3), value: session.status)
            
            Divider()
            
            // Profile info header
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: typeIcon)
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.alias)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 8) {
                            Text(session.type.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            Text(session.region)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if session.status == .active, let expiration = session.expiration {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text("Expires \(expiration, style: .relative)")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding()
            
            Divider()
            
            // Tabs
            Picker("", selection: $selectedTab) {
                Label("Details", systemImage: "info.circle").tag(0)
                Label("Console", systemImage: "terminal").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Tab content
            TabView(selection: $selectedTab) {
                DetailsTab(session: liveSession)
                    .tag(0)
                
                ConsoleTab(session: liveSession)
                    .tag(1)
            }
            .tabViewStyle(.automatic)
        }
        .overlay(alignment: .top) {
            if showCopiedNotification {
                Text("Copied to clipboard")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showMFAAlert) {
            MFAInputView(mfaToken: $mfaToken, onSubmit: {
                store.toggleSession(session, mfaToken: mfaToken)
                showMFAAlert = false
                mfaToken = ""
            }, onCancel: {
                showMFAAlert = false
            })
        }
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation {
            showCopiedNotification = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedNotification = false
            }
        }
    }
    
    private func copyExportCommands() {
        let commands = """
        export AWS_PROFILE=\(session.alias)
        export AWS_REGION=\(session.region)
        export AWS_DEFAULT_REGION=\(session.region)
        """
        copyToClipboard(commands)
    }
    
    private func copyAsJSON() {
        guard let keyId = session.accessKeyId else { return }
        let json = """
        {
          "profile": "\(session.alias)",
          "region": "\(session.region)",
          "accountId": "\(session.accountId)",
          "accessKeyId": "\(keyId)",
          "type": "\(session.type.rawValue)"
        }
        """
        copyToClipboard(json)
    }
    
    private func copyAsAWSCLI() {
        let config = """
        [\(session.alias)]
        region = \(session.region)
        output = json
        """
        copyToClipboard(config)
    }
    
    var statusColor: Color {
        switch liveSession.status {
        case .active: return .green
        case .inactive: return .gray
        case .expiring: return .orange
        }
    }
    
    var typeIcon: String {
        switch session.type {
        case .iamUser: return "person.fill"
        case .sso: return "arrow.triangle.2.circlepath"
        case .assumedRole: return "key.fill"
        }
    }
}

struct DetailsTab: View {
    let session: Session
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Profile Information
                GroupBox {
                    VStack(spacing: 10) {
                        InfoRow(icon: "tag.fill", label: "Alias", value: session.alias)
                        InfoRow(icon: "person.fill", label: "Profile", value: session.profileName)
                        InfoRow(icon: "globe", label: "Region", value: session.region)
                        InfoRow(icon: "number", label: "Account", value: session.accountId)
                        
                        if let roleArn = session.roleArn {
                            InfoRow(icon: "key.fill", label: "Role ARN", value: roleArn)
                        }
                        
                        if let mfa = session.mfaSerial {
                            InfoRow(icon: "lock.shield.fill", label: "MFA", value: mfa)
                        }
                    }
                } label: {
                    Label("Configuration", systemImage: "gearshape.fill")
                        .font(.headline)
                }
                
                // Credentials
                if session.status == .active {
                    GroupBox {
                        VStack(spacing: 10) {
                            if let accessKey = session.accessKeyId {
                                InfoRow(icon: "key.fill", label: "Access Key", value: accessKey)
                            }
                            
                            if let expiration = session.expiration {
                                InfoRow(icon: "clock.fill", label: "Expires", value: expiration.formatted())
                            }
                        }
                    } label: {
                        Label("Active Credentials", systemImage: "checkmark.shield.fill")
                            .font(.headline)
                    }
                }
            }
            .padding()
        }
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    @State private var isHovered = false
    @State private var justCopied = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 16)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.body)
                .textSelection(.enabled)
                .lineLimit(1)
            
            Spacer()
            
            if isHovered {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        justCopied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        withAnimation {
                            justCopied = false
                        }
                    }
                }) {
                    Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(justCopied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.accentColor.opacity(0.05) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct ConsoleTab: View {
    let session: Session
    @State private var highlightedIndex: Int?
    @EnvironmentObject var store: SessionStore
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "terminal.fill")
                        .foregroundColor(.accentColor)
                    Text("Console Output")
                        .font(.headline)
                    Spacer()
                    
                    if !session.logs.isEmpty {
                        HStack(spacing: 8) {
                            Text("\(session.logs.count) entries")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                var updatedSession = session
                                updatedSession.logs.removeAll()
                                store.updateSession(updatedSession)
                            }) {
                                Label("Clear", systemImage: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(session.logs.joined(separator: "\n"), forType: .string)
                            }) {
                                Label("Copy All", systemImage: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                
                if session.logs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "terminal")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No activity yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Start the session to see AWS CLI output")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(session.logs.enumerated()), id: \.offset) { index, log in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: logIcon(for: log))
                                    .font(.caption)
                                    .foregroundColor(logColor(for: log))
                                    .frame(width: 16)
                                
                                Text(log)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(logColor(for: log))
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(highlightedIndex == index ? logColor(for: log).opacity(0.1) : Color.clear)
                            )
                            .onAppear {
                                if index == session.logs.count - 1 {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        highlightedIndex = index
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        withAnimation {
                                            highlightedIndex = nil
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
    }
    
    func logIcon(for log: String) -> String {
        if log.contains("❌") || log.contains("Error") {
            return "xmark.circle.fill"
        } else if log.contains("⚠️") || log.contains("Warning") {
            return "exclamationmark.triangle.fill"
        } else if log.contains("✅") {
            return "checkmark.circle.fill"
        } else if log.contains("🔄") {
            return "arrow.clockwise.circle.fill"
        }
        return "circle.fill"
    }
    
    func logColor(for log: String) -> Color {
        if log.contains("❌") || log.contains("Error") {
            return .red
        } else if log.contains("⚠️") || log.contains("Warning") {
            return .orange
        } else if log.contains("✅") {
            return .green
        } else if log.contains("🔄") {
            return .blue
        }
        return .primary
    }
}
