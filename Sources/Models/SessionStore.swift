import Foundation
import SwiftUI
import UserNotifications

@MainActor
class SessionStore: ObservableObject {
    static var shared: SessionStore?
    
    @Published var sessions: [Session] = []
    @Published var recentSessionIds: [UUID] = []
    @Published var expiringSession: Session? // Session that's about to expire
    @Published var showExpirationWarning = false
    @Published var isAWSCLIAvailable = true
    
    private let savePath: URL
    private let recentPath: URL
    private var expirationTimer: Timer?
    private var warnedSessionIds: Set<UUID> = [] // Track which sessions we've warned about
    
    init() {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("CloudKey")
        
        // Create directory with proper permissions
        do {
            if !FileManager.default.fileExists(atPath: appSupport.path) {
                try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755])
                print("Created CloudKey data directory: \(appSupport.path)")
            }
        } catch {
            print("Warning: Could not create data directory: \(error.localizedDescription)")
        }
        
        savePath = appSupport.appendingPathComponent("sessions.json")
        recentPath = appSupport.appendingPathComponent("recent.json")
        
        // Set shared instance after properties are initialized
        SessionStore.shared = self
        
        load()
        loadRecent()
        print("SessionStore initialized. Loaded \(sessions.count) sessions.")
        
        if sessions.isEmpty {
            print("Sessions empty. Loading mock data...")
            sessions = Session.mockData
            print("Loaded \(sessions.count) mock sessions.")
        }
        
        // Request notification permissions
        requestNotificationPermissions()
        
        // Check AWS CLI availability
        checkAWSCLI()
        
        // Start expiration check timer on main queue
        DispatchQueue.main.async { [weak self] in
            self?.startExpirationTimer()
        }
    }
    
    func checkAWSCLI() {
        Task {
            let available = await AWSService.shared.isAWSCLIAvailable()
            await MainActor.run {
                isAWSCLIAvailable = available
            }
        }
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("✅ Notification permissions granted")
            }
        }
    }
    
    private func startExpirationTimer() {
        expirationTimer?.invalidate()
        // Use coalescing timer for better power efficiency
        expirationTimer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkExpiredSessions()
        }
        expirationTimer?.tolerance = 5 // Allow 5 second tolerance for power efficiency
        RunLoop.main.add(expirationTimer!, forMode: .common)
    }
    
    private func checkExpiredSessions() {
        // Early exit if no active sessions
        let activeSessions = sessions.filter { $0.status == .active && $0.expiration != nil }
        guard !activeSessions.isEmpty else { return }
        
        var needsSave = false
        let now = Date()
        let warningThreshold: TimeInterval = 600 // 10 minutes
        let autoRenewThreshold: TimeInterval = 300 // 5 minutes
        
        for i in 0..<sessions.count {
            guard sessions[i].status == .active, let expiration = sessions[i].expiration else {
                continue
            }
            
            let timeRemaining = expiration.timeIntervalSince(now)
            
            // Check if expired
            if timeRemaining <= 0 {
                print("⏰ Session expired: \(sessions[i].alias)")
                sessions[i].status = .inactive
                sessions[i].accessKeyId = nil
                sessions[i].expiration = nil
                sessions[i].logs.append("[\(Date().formatted(date: .omitted, time: .standard))] ⏰ Session expired")
                warnedSessionIds.remove(sessions[i].id)
                needsSave = true
            }
            // Check for auto-renewal (5 minutes before expiration)
            else if sessions[i].autoRenew && timeRemaining <= autoRenewThreshold && !warnedSessionIds.contains(sessions[i].id) {
                print("🔄 Auto-renewing session: \(sessions[i].alias)")
                warnedSessionIds.insert(sessions[i].id) // Prevent multiple renewal attempts
                attemptAutoRenewal(sessions[i])
            }
            // Check if expiring soon (within warning threshold) and not already warned
            // Skip warning for sessions with auto-renew enabled
            else if !sessions[i].autoRenew && timeRemaining <= warningThreshold && !warnedSessionIds.contains(sessions[i].id) {
                print("⚠️  Session expiring soon: \(sessions[i].alias) in \(Int(timeRemaining/60)) minutes")
                warnedSessionIds.insert(sessions[i].id)
                showExpirationWarning(for: sessions[i])
            }
        }
        
        if needsSave {
            save()
        }
    }
    
    private func attemptAutoRenewal(_ session: Session) {
        // If session requires MFA and doesn't have cache, show notification
        if session.skipMFACache {
            Task {
                await showAutoRenewMFANotification(for: session)
            }
        } else {
            // Has MFA cache, renew silently
            Task {
                do {
                    var stopped = try await AWSService.shared.stopSession(session)
                    stopped.skipMFACache = session.skipMFACache
                    stopped.autoRenew = session.autoRenew
                    updateSession(stopped)
                    
                    let renewed = try await AWSService.shared.startSession(stopped, mfaToken: nil)
                    updateSession(renewed)
                    
                    // Show success notification
                    let content = UNMutableNotificationContent()
                    content.title = "Session Auto-Renewed"
                    content.body = "\(session.alias) has been automatically renewed"
                    content.sound = .default
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    try? await UNUserNotificationCenter.current().add(request)
                    
                    print("✅ Auto-renewed session: \(session.alias)")
                } catch {
                    print("❌ Auto-renewal failed for \(session.alias): \(error)")
                    await showAutoRenewFailureNotification(for: session, error: error)
                }
            }
        }
    }
    
    private func showAutoRenewMFANotification(for session: Session) async {
        let content = UNMutableNotificationContent()
        content.title = "Auto-Renew Needs MFA"
        content.body = "\(session.alias) requires MFA token for auto-renewal. Click to provide."
        content.sound = .default
        content.userInfo = ["sessionId": session.id.uuidString, "action": "autoRenewMFA"]
        
        let request = UNNotificationRequest(identifier: session.id.uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
        
        // Also show in-app alert
        await MainActor.run {
            expiringSession = session
            showExpirationWarning = true
        }
    }
    
    private func showAutoRenewFailureNotification(for session: Session, error: Error) async {
        let content = UNMutableNotificationContent()
        content.title = "Auto-Renew Failed"
        content.body = "\(session.alias) could not be renewed: \(error.localizedDescription)"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
    
    private func showExpirationWarning(for session: Session) {
        // Show in-app alert
        expiringSession = session
        showExpirationWarning = true
        
        // Send system notification
        let content = UNMutableNotificationContent()
        content.title = "Session Expiring Soon"
        content.body = "\(session.alias) will expire in \(Int((session.expiration?.timeIntervalSinceNow ?? 0) / 60)) minutes"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: session.id.uuidString, content: content, trigger: nil)
        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
    
    func renewSession(_ session: Session, mfaToken: String? = nil) {
        // Reset warning flag
        warnedSessionIds.remove(session.id)
        showExpirationWarning = false
        expiringSession = nil
        
        // Stop and restart the session
        Task {
            do {
                // First stop the session
                var stopped = try await AWSService.shared.stopSession(session)
                // Preserve skipMFACache flag
                stopped.skipMFACache = session.skipMFACache
                updateSession(stopped)
                
                // Then start it again (with MFA if provided, or use cached MFA)
                let renewed = try await AWSService.shared.startSession(stopped, mfaToken: mfaToken)
                updateSession(renewed)
            } catch {
                print("Error renewing session: \(error)")
            }
        }
    }
    
    func load() {
        guard FileManager.default.fileExists(atPath: savePath.path) else {
            sessions = []
            return
        }
        
        do {
            let data = try Data(contentsOf: savePath)
            sessions = try JSONDecoder().decode([Session].self, from: data)
        } catch {
            print("Failed to load sessions: \(error.localizedDescription)")
            sessions = []
        }
    }
    
    func save() {
        do {
            let data = try JSONEncoder().encode(sessions)
            
            // Ensure directory exists with proper permissions
            let directory = savePath.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755])
            }
            
            // Write with proper options
            try data.write(to: savePath, options: [.atomic])
        } catch {
            print("Failed to save sessions: \(error.localizedDescription)")
        }
    }
    
    func addSession(_ session: Session) {
        sessions.append(session)
        save()
    }
    
    func updateSession(_ session: Session) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            save()
        }
    }
    
    func deleteSession(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
        save()
    }
    
    func toggleSession(_ session: Session, mfaToken: String? = nil) {
        Task {
            do {
                if session.status == .active {
                    let updated = try await AWSService.shared.stopSession(session)
                    updateSession(updated)
                } else {
                    let updated = try await AWSService.shared.startSession(session, mfaToken: mfaToken)
                    updateSession(updated)
                    addToRecent(session.id)
                }
            } catch {
                print("Error toggling session: \(error)")
            }
        }
    }
    
    private func loadRecent() {
        guard FileManager.default.fileExists(atPath: recentPath.path) else {
            recentSessionIds = []
            return
        }
        
        do {
            let data = try Data(contentsOf: recentPath)
            recentSessionIds = try JSONDecoder().decode([UUID].self, from: data)
        } catch {
            print("Failed to load recent sessions: \(error.localizedDescription)")
            recentSessionIds = []
        }
    }
    
    private func saveRecent() {
        do {
            let data = try JSONEncoder().encode(recentSessionIds)
            
            // Ensure directory exists with proper permissions
            let directory = recentPath.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755])
            }
            
            // Write with proper options
            try data.write(to: recentPath, options: [.atomic])
        } catch {
            print("Failed to save recent sessions: \(error.localizedDescription)")
        }
    }
    
    private func addToRecent(_ id: UUID) {
        // Remove if already exists
        recentSessionIds.removeAll { $0 == id }
        // Add to front
        recentSessionIds.insert(id, at: 0)
        // Keep only last 5
        if recentSessionIds.count > 5 {
            recentSessionIds = Array(recentSessionIds.prefix(5))
        }
        saveRecent()
    }
    
    var recentSessions: [Session] {
        recentSessionIds.compactMap { id in
            sessions.first { $0.id == id }
        }
    }
    
    // MARK: - Export/Import
    
    func exportProfiles() -> Data? {
        let exports = sessions.map { $0.toExport() }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(exports)
    }
    
    func importProfiles(from data: Data, replace: Bool = false) throws {
        let decoder = JSONDecoder()
        let importedExports = try decoder.decode([ProfileExport].self, from: data)
        let importedSessions = importedExports.map { Session.fromExport($0) }
        
        if replace {
            sessions = importedSessions
        } else {
            // Merge: add new profiles, skip duplicates by alias
            for imported in importedSessions {
                if !sessions.contains(where: { $0.alias == imported.alias }) {
                    var newSession = imported
                    newSession.id = UUID()
                    sessions.append(newSession)
                }
            }
        }
        save()
    }
}
