import Foundation
import SwiftUI

@MainActor
class SessionStore: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var recentSessionIds: [UUID] = []
    
    private let savePath: URL
    private let recentPath: URL
    private var expirationTimer: Timer?
    
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
        
        load()
        loadRecent()
        print("SessionStore initialized. Loaded \(sessions.count) sessions.")
        
        if sessions.isEmpty {
            print("Sessions empty. Loading mock data...")
            sessions = Session.mockData
            print("Loaded \(sessions.count) mock sessions.")
        }
        
        // Start expiration check timer
        startExpirationTimer()
    }
    
    private func startExpirationTimer() {
        expirationTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkExpiredSessions()
            }
        }
    }
    
    private func checkExpiredSessions() {
        var needsSave = false
        
        for i in 0..<sessions.count {
            if sessions[i].status == .active,
               let expiration = sessions[i].expiration,
               expiration < Date() {
                print("⏰ Session expired: \(sessions[i].alias)")
                sessions[i].status = .inactive
                sessions[i].accessKeyId = nil
                sessions[i].expiration = nil
                sessions[i].logs.append("[\(Date().formatted(date: .omitted, time: .standard))] ⏰ Session expired")
                needsSave = true
            }
        }
        
        if needsSave {
            save()
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
