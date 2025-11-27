import SwiftUI

@main
struct CloudKeyApp: App {
    @StateObject private var store = SessionStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
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
