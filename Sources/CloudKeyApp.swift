import SwiftUI
import Combine

@main
struct CloudKeyApp: App {
    @StateObject private var store = SessionStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task {
                    print("🚀 Task running, setting up menu bar")
                    await MenuBarManager.shared.setup(store: SessionStore.shared)
                }
        }
        .commands {
            SidebarCommands()
            
            CommandGroup(replacing: .newItem) {
                Button("New Profile") {
                    // Handled by sidebar
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandMenu("Session") {
                Button("Start/Stop Session") {
                    // Handled by detail view
                }
                .keyboardShortcut(.return, modifiers: .command)
                
                Divider()
                
                Button("Refresh Sessions") {
                    store.load()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        
        Settings {
            SettingsView()
        }
    }
}

@MainActor
class MenuBarManager {
    static let shared = MenuBarManager()
    
    var statusItem: NSStatusItem?
    var sessionStore: SessionStore?
    var cancellables = Set<AnyCancellable>()
    var updateTimer: Timer?
    var windowDelegate: WindowDelegate?
    var lastActiveCount = 0
    var lastExpiringCount = 0
    var cachedAppIcon: NSImage?
    var cachedWarningIcon: NSImage?
    
    func setup(store: SessionStore?) async {
        self.sessionStore = store
        
        // Pre-cache icons
        if let appIcon = NSImage(named: "AppIcon") {
            let resizedIcon = NSImage(size: NSSize(width: 18, height: 18))
            resizedIcon.lockFocus()
            appIcon.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
            resizedIcon.unlockFocus()
            cachedAppIcon = resizedIcon
        }
        
        let warningImage = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Warning")
        warningImage?.isTemplate = true
        cachedWarningIcon = warningImage
        
        // Prevent app from quitting when window closes
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // Set up window delegate
        windowDelegate = WindowDelegate()
        if let window = NSApp.windows.first {
            window.delegate = windowDelegate
        }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Use cached icon
            button.image = cachedAppIcon ?? NSImage(systemSymbolName: "cloud.fill", accessibilityDescription: "CloudKey")
            button.title = " 0"
        }
        
        updateMenuBar()
        startAutoUpdate()
        observeSessionChanges()
    }
    
    func startAutoUpdate() {
        // Update every 2 minutes instead of 1 minute
        updateTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            self?.updateMenuBar()
        }
        updateTimer?.tolerance = 10 // Allow 10 second tolerance for power efficiency
    }
    
    func observeSessionChanges() {
        sessionStore?.$sessions
            .map { $0.filter { $0.status == .active }.count }
            .removeDuplicates()
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBar()
            }
            .store(in: &cancellables)
    }
    
    func updateMenuBar() {
        guard let store = sessionStore else { return }
        
        let activeSessions = store.sessions.filter { $0.status == .active }
        let expiringCount = activeSessions.filter { session in
            guard let expiration = session.expiration else { return false }
            return expiration.timeIntervalSinceNow <= 600
        }.count
        
        // Skip update if nothing changed
        if activeSessions.count == lastActiveCount && expiringCount == lastExpiringCount {
            return
        }
        
        lastActiveCount = activeSessions.count
        lastExpiringCount = expiringCount
        
        DispatchQueue.main.async { [weak self] in
            if let button = self?.statusItem?.button {
                if expiringCount > 0 {
                    button.image = self?.cachedWarningIcon
                    button.contentTintColor = .red
                } else {
                    button.image = self?.cachedAppIcon
                    button.contentTintColor = nil
                }
                button.title = " \(activeSessions.count)"
            }
            
            self?.rebuildMenu(activeSessions: activeSessions)
        }
    }
    
    func rebuildMenu(activeSessions: [Session]) {
        let menu = NSMenu()
        menu.delegate = self // Set delegate for lazy loading
        
        let header = NSMenuItem(title: "Active Sessions (\(activeSessions.count))", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())
        
        if activeSessions.isEmpty {
            let noSessions = NSMenuItem(title: "No active sessions", action: nil, keyEquivalent: "")
            noSessions.isEnabled = false
            menu.addItem(noSessions)
        } else {
            // Store sessions for lazy loading
            menu.representedObject = activeSessions
            
            for session in activeSessions {
                let item = createSessionMenuItem(session)
                menu.addItem(item)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let openItem = NSMenuItem(title: "Open CloudKey", action: #selector(openMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    func createSessionMenuItem(_ session: Session) -> NSMenuItem {
        let item = NSMenuItem()
        
        var title = "● \(session.alias)"
        if let expiration = session.expiration {
            let minutes = Int(expiration.timeIntervalSinceNow / 60)
            title += "  [\(minutes)m]"
        }
        item.title = title
        
        let submenu = NSMenu()
        
        let renewItem = NSMenuItem(title: "Renew", action: #selector(renewSession(_:)), keyEquivalent: "")
        renewItem.representedObject = session.id
        renewItem.target = self
        submenu.addItem(renewItem)
        
        let stopItem = NSMenuItem(title: "Stop", action: #selector(stopSession(_:)), keyEquivalent: "")
        stopItem.representedObject = session.id
        stopItem.target = self
        submenu.addItem(stopItem)
        
        let copyItem = NSMenuItem(title: "Copy Access Key", action: #selector(copyAccessKey(_:)), keyEquivalent: "")
        copyItem.representedObject = session.id
        copyItem.target = self
        submenu.addItem(copyItem)
        
        item.submenu = submenu
        return item
    }
    
    @objc func openMainWindow() {
        // Show app in Dock and activate
        NSApplication.shared.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Show or create window
        if let window = NSApp.windows.first(where: { $0.isVisible == false || $0.isMiniaturized }) {
            window.makeKeyAndOrderFront(nil)
            window.deminiaturize(nil)
        } else if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc func renewSession(_ sender: NSMenuItem) {
        guard let sessionId = sender.representedObject as? UUID,
              let store = sessionStore,
              let session = store.sessions.first(where: { $0.id == sessionId }) else { return }
        
        Task { @MainActor in
            store.renewSession(session)
        }
    }
    
    @objc func stopSession(_ sender: NSMenuItem) {
        guard let sessionId = sender.representedObject as? UUID,
              let store = sessionStore,
              let session = store.sessions.first(where: { $0.id == sessionId }) else { return }
        
        Task { @MainActor in
            store.toggleSession(session)
        }
    }
    
    @objc func copyAccessKey(_ sender: NSMenuItem) {
        guard let sessionId = sender.representedObject as? UUID,
              let store = sessionStore,
              let session = store.sessions.first(where: { $0.id == sessionId }),
              let accessKey = session.accessKeyId else { return }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(accessKey, forType: .string)
    }
}

class WindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide window instead of closing
        sender.orderOut(nil)
        // Hide from Dock
        NSApplication.shared.setActivationPolicy(.accessory)
        return false
    }
}

extension MenuBarManager: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Menu is about to open - items are already created
    }
}
