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
    
    func setup(store: SessionStore?) async {
        print("🔧 MenuBarManager setup called")
        self.sessionStore = store
        
        // Prevent app from quitting when window closes
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // Set up window delegate
        windowDelegate = WindowDelegate()
        if let window = NSApp.windows.first {
            window.delegate = windowDelegate
        }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        print("🔧 Status item created: \(statusItem != nil)")
        
        if let button = statusItem?.button {
            // Use app icon
            if let appIcon = NSImage(named: "AppIcon") {
                let resizedIcon = NSImage(size: NSSize(width: 18, height: 18))
                resizedIcon.lockFocus()
                appIcon.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
                resizedIcon.unlockFocus()
                button.image = resizedIcon
            } else {
                // Fallback to system icon
                button.image = NSImage(systemSymbolName: "cloud.fill", accessibilityDescription: "CloudKey")
            }
            button.title = " 0"
            print("🔧 Menu bar button configured")
        }
        
        updateMenuBar()
        startAutoUpdate()
        observeSessionChanges()
        print("✅ Menu bar setup complete")
    }
    
    func startAutoUpdate() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateMenuBar()
        }
    }
    
    func observeSessionChanges() {
        sessionStore?.$sessions
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
        
        DispatchQueue.main.async { [weak self] in
            if let button = self?.statusItem?.button {
                if expiringCount > 0 {
                    // Warning icon in red
                    let image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Warning")
                    image?.isTemplate = true
                    button.image = image
                    button.contentTintColor = .red
                } else {
                    // Use app icon
                    if let appIcon = NSImage(named: "AppIcon") {
                        let resizedIcon = NSImage(size: NSSize(width: 18, height: 18))
                        resizedIcon.lockFocus()
                        appIcon.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
                        resizedIcon.unlockFocus()
                        button.image = resizedIcon
                        button.contentTintColor = nil
                    }
                }
                button.title = " \(activeSessions.count)"
            }
            
            self?.rebuildMenu(activeSessions: activeSessions)
        }
    }
    
    func rebuildMenu(activeSessions: [Session]) {
        let menu = NSMenu()
        
        let header = NSMenuItem(title: "Active Sessions (\(activeSessions.count))", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())
        
        if activeSessions.isEmpty {
            let noSessions = NSMenuItem(title: "No active sessions", action: nil, keyEquivalent: "")
            noSessions.isEnabled = false
            menu.addItem(noSessions)
        } else {
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
