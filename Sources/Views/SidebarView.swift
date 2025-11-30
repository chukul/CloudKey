import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: SessionStore
    @Binding var selection: Session.ID?
    @State private var editingSession: Session?
    @State private var searchText = ""
    @State private var filterStatus: SessionStatus?
    @State private var showMFAAlert = false
    @State private var mfaToken = ""
    @State private var sessionToStart: Session?
    @State private var showExportSuccess = false
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    
    var filteredSessions: [Session] {
        store.sessions.filter { session in
            let matchesSearch = searchText.isEmpty || 
                session.alias.localizedCaseInsensitiveContains(searchText) ||
                session.accountId.contains(searchText) ||
                session.region.localizedCaseInsensitiveContains(searchText)
            let matchesFilter = filterStatus == nil || session.status == filterStatus
            return matchesSearch && matchesFilter
        }
    }
    
    var activeSessions: [Session] {
        filteredSessions.filter { $0.status == .active }
    }
    
    var inactiveSessions: [Session] {
        filteredSessions.filter { $0.status != .active }
    }
    
    var groupedInactiveSessions: [String: [Session]] {
        Dictionary(grouping: inactiveSessions) { session in
            session.group ?? "Ungrouped"
        }
    }
    
    var sortedGroups: [String] {
        groupedInactiveSessions.keys.sorted { group1, group2 in
            if group1 == "Ungrouped" { return false }
            if group2 == "Ungrouped" { return true }
            return group1 < group2
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search profiles...", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
    
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: filterStatus == nil) {
                    filterStatus = nil
                }
                FilterChip(title: "Active", isSelected: filterStatus == .active) {
                    filterStatus = .active
                }
                FilterChip(title: "Inactive", isSelected: filterStatus == .inactive) {
                    filterStatus = .inactive
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
    
    private var sessionsList: some View {
        List(selection: $selection) {
            if !store.recentSessions.isEmpty {
                Section(header: Text("Recent")) {
                    ForEach(store.recentSessions) { session in
                        SessionRow(session: session, onQuickAction: {
                            if session.status == .active {
                                store.toggleSession(session)
                            } else if let mfaSerial = session.mfaSerial, 
                                      let sourceProfile = session.sourceProfile {
                                // Check cache
                                let hasCached = AWSService.shared.hasCachedMFAToken(sourceProfile: sourceProfile, mfaSerial: mfaSerial)
                                print("🔍 UI: Checking cache for \(session.alias), hasCached: \(hasCached)")
                                
                                if !hasCached {
                                    // Only show MFA prompt if no cached token
                                    sessionToStart = session
                                    showMFAAlert = true
                                } else {
                                    print("🔍 UI: Using cached token, calling toggleSession without MFA")
                                    store.toggleSession(session)
                                }
                            } else {
                                store.toggleSession(session)
                            }
                        })
                        .tag(session.id)
                        .contextMenu {
                            contextMenuItems(for: session)
                        }
                    }
                }
            }
            
            if !activeSessions.isEmpty {
                Section(header: Text("Active Sessions")) {
                    ForEach(activeSessions) { session in
                        SessionRow(session: session, onQuickAction: {
                            if session.status == .active {
                                store.toggleSession(session)
                            } else if let mfaSerial = session.mfaSerial,
                                      let sourceProfile = session.sourceProfile,
                                      !AWSService.shared.hasCachedMFAToken(sourceProfile: sourceProfile, mfaSerial: mfaSerial) {
                                sessionToStart = session
                                showMFAAlert = true
                            } else {
                                store.toggleSession(session)
                            }
                        })
                        .tag(session.id)
                        .contextMenu {
                            contextMenuItems(for: session)
                        }
                    }
                }
            }
            
            if !inactiveSessions.isEmpty {
                ForEach(sortedGroups, id: \.self) { groupName in
                    Section(header: Text(groupName)) {
                        ForEach(groupedInactiveSessions[groupName] ?? []) { session in
                            SessionRow(session: session, onQuickAction: {
                                if session.status == .active {
                                    store.toggleSession(session)
                                } else if let mfaSerial = session.mfaSerial,
                                          let sourceProfile = session.sourceProfile,
                                          !AWSService.shared.hasCachedMFAToken(sourceProfile: sourceProfile, mfaSerial: mfaSerial) {
                                    sessionToStart = session
                                    showMFAAlert = true
                                } else {
                                    store.toggleSession(session)
                                }
                            })
                            .tag(session.id)
                            .contextMenu {
                                contextMenuItems(for: session)
                            }
                        }
                    }
                }
            }
            
            if filteredSessions.isEmpty {
                Text("No profiles found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .listStyle(.sidebar)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            filterChips
            Divider()
            sessionsList
        }
        .navigationTitle("CloudKey")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button(action: exportProfiles) {
                        Label("Export Profiles", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: importProfiles) {
                        Label("Import Profiles (Merge)", systemImage: "square.and.arrow.down")
                    }
                    
                    Button(action: importProfilesReplace) {
                        Label("Import Profiles (Replace)", systemImage: "arrow.triangle.2.circlepath")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    editingSession = Session(
                        alias: "",
                        profileName: "",
                        region: "ap-southeast-1",
                        accountId: "",
                        status: .inactive,
                        type: .assumedRole
                    )
                }) {
                    Label("Add Profile", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(item: $editingSession) { session in
            ProfileEditorView(
                session: session,
                onSave: { updatedSession in
                    if store.sessions.contains(where: { $0.id == updatedSession.id }) {
                        store.updateSession(updatedSession)
                    } else {
                        store.addSession(updatedSession)
                    }
                    editingSession = nil
                },
                onCancel: {
                    editingSession = nil
                }
            )
        }
        .sheet(isPresented: $showMFAAlert) {
            MFAInputView(mfaToken: $mfaToken, onSubmit: {
                if let session = sessionToStart {
                    store.toggleSession(session, mfaToken: mfaToken)
                }
                showMFAAlert = false
                mfaToken = ""
                sessionToStart = nil
            }, onCancel: {
                showMFAAlert = false
                mfaToken = ""
                sessionToStart = nil
            })
        }
        .alert("Export Successful", isPresented: $showExportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Profiles exported successfully")
        }
        .alert("Import Successful", isPresented: $showImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Profiles imported successfully")
        }
        .alert("Import Error", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
        }
    }
    
    private func exportProfiles() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "cloudkey-profiles.json"
        panel.message = "Export CloudKey profiles"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let data = store.exportProfiles() {
                    do {
                        try data.write(to: url)
                        showExportSuccess = true
                    } catch {
                        importErrorMessage = "Failed to save file: \(error.localizedDescription)"
                        showImportError = true
                    }
                }
            }
        }
    }
    
    private func importProfiles() {
        importProfilesWithMode(replace: false)
    }
    
    private func importProfilesReplace() {
        importProfilesWithMode(replace: true)
    }
    
    private func importProfilesWithMode(replace: Bool) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.message = replace ? "Import and replace all profiles" : "Import and merge profiles"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = try Data(contentsOf: url)
                    try store.importProfiles(from: data, replace: replace)
                    showImportSuccess = true
                } catch {
                    importErrorMessage = "Failed to import: \(error.localizedDescription)"
                    showImportError = true
                }
            }
        }
    }
    
    @ViewBuilder
    private func contextMenuItems(for session: Session) -> some View {
        Button(action: { 
            if session.status == .active {
                store.toggleSession(session)
            } else if let mfaSerial = session.mfaSerial,
                      let sourceProfile = session.sourceProfile,
                      (session.skipMFACache || !AWSService.shared.hasCachedMFAToken(sourceProfile: sourceProfile, mfaSerial: mfaSerial)) {
                sessionToStart = session
                showMFAAlert = true
            } else {
                store.toggleSession(session)
            }
        }) {
            Label(session.status == .active ? "Stop" : "Start", 
                  systemImage: session.status == .active ? "stop.circle" : "play.circle")
        }
        
        if session.status == .active {
            Button(action: {
                do {
                    try AWSService.shared.setAsDefaultProfile(session)
                    // Show success feedback
                    NSSound.beep()
                } catch {
                    print("Failed to set as default: \(error.localizedDescription)")
                }
            }) {
                Label("Set as Default Profile", systemImage: "star.circle.fill")
            }
            
            // Only show Open Console when skipMFACache is enabled (federation works)
            if session.skipMFACache {
                Button(action: {
                    Task {
                        let updated = await AWSService.shared.openAWSConsole(for: session)
                        store.updateSession(updated)
                    }
                }) {
                    Label("Open AWS Console", systemImage: "globe")
                }
            }
            
            if let keyId = session.accessKeyId {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(keyId, forType: .string)
                }) {
                    Label("Copy Access Key", systemImage: "doc.on.doc")
                }
            }
        }
        
        Divider()
        
        // Federation compatibility toggle (only for assume role with MFA)
        if session.type == .assumedRole && session.mfaSerial != nil {
            Button(action: {
                var updated = session
                updated.skipMFACache.toggle()
                store.updateSession(updated)
            }) {
                Label(session.skipMFACache ? "✓ Skip MFA Cache (federation)" : "Use MFA Cache (faster)", 
                      systemImage: session.skipMFACache ? "network" : "bolt.fill")
            }
            
            Divider()
        }
        
        // Auto-renew toggle
        Button(action: {
            var updated = session
            updated.autoRenew.toggle()
            store.updateSession(updated)
        }) {
            Label(session.autoRenew ? "✓ Auto-Renew Enabled" : "Enable Auto-Renew", 
                  systemImage: session.autoRenew ? "arrow.clockwise.circle.fill" : "arrow.clockwise.circle")
        }
        
        Divider()
        
        Button(action: {
            editingSession = session
        }) {
            Label("Edit", systemImage: "pencil")
        }
        
        Button(action: {
            var clonedSession = session
            clonedSession.id = UUID()
            clonedSession.alias = "\(session.alias) (Copy)"
            clonedSession.status = .inactive
            clonedSession.accessKeyId = nil
            clonedSession.expiration = nil
            clonedSession.logs = []
            editingSession = clonedSession
        }) {
            Label("Clone", systemImage: "doc.on.doc")
        }
        
        Button(role: .destructive, action: {
            if let index = store.sessions.firstIndex(where: { $0.id == session.id }) {
                store.deleteSession(at: IndexSet(integer: index))
            }
        }) {
            Label("Delete", systemImage: "trash")
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct SessionRow: View {
    let session: Session
    let onQuickAction: () -> Void
    @State private var isHovered = false
    @State private var isPulsing = false
    @State private var timeRemaining: String = ""
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 10) {
            // Default profile flag indicator
            if session.status == .active && AWSService.shared.isDefaultProfile(session.alias) {
                Text("🚩")
                    .font(.caption)
            }
            
            // Status indicator with pulse animation
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.3), lineWidth: session.status == .active ? 4 : 0)
                        .scaleEffect(isPulsing ? 1.5 : 1.0)
                        .opacity(isPulsing ? 0 : 1)
                )
                .onAppear {
                    if session.status == .active {
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                            isPulsing = true
                        }
                    }
                }
            
            // Type icon
            Image(systemName: typeIcon)
                .foregroundColor(.secondary)
                .frame(width: 16)
            
            // Session info
            VStack(alignment: .leading, spacing: 2) {
                Text(session.alias)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(session.region)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if session.status == .active, let expiration = session.expiration {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(timeRemaining)
                            .font(.caption)
                            .foregroundColor(expirationColor)
                            .onReceive(timer) { _ in
                                updateTimeRemaining(expiration: expiration)
                            }
                            .onAppear {
                                updateTimeRemaining(expiration: expiration)
                            }
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            // Quick action button (visible on hover)
            if isHovered {
                Button(action: onQuickAction) {
                    Image(systemName: session.status == .active ? "stop.circle.fill" : "play.circle.fill")
                        .foregroundColor(session.status == .active ? .red : .green)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .help(session.status == .active ? "Stop session" : "Start session")
                .transition(.scale.combined(with: .opacity))
            }
            
            // MFA indicator
            if session.mfaSerial != nil {
                Image(systemName: "lock.shield.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
    
    private func updateTimeRemaining(expiration: Date) {
        let now = Date()
        let remaining = expiration.timeIntervalSince(now)
        
        if remaining <= 0 {
            timeRemaining = "Expired"
        } else if remaining < 300 { // Less than 5 minutes
            let minutes = Int(remaining / 60)
            let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
            timeRemaining = String(format: "%d:%02d", minutes, seconds)
        } else if remaining < 3600 { // Less than 1 hour
            let minutes = Int(remaining / 60)
            timeRemaining = "\(minutes)m"
        } else {
            let hours = Int(remaining / 3600)
            let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
            timeRemaining = "\(hours)h \(minutes)m"
        }
    }
    
    private var expirationColor: Color {
        guard let expiration = session.expiration else { return .secondary }
        let remaining = expiration.timeIntervalSince(Date())
        
        if remaining < 300 { // Less than 5 minutes
            return .red
        } else if remaining < 900 { // Less than 15 minutes
            return .orange
        } else {
            return .secondary
        }
    }
    
    var statusColor: Color {
        switch session.status {
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
