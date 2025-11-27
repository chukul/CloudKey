import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: SessionStore
    @State private var selection: Session.ID?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $selection)
                .frame(minWidth: 250, idealWidth: 300)
        } detail: {
            if let id = selection, let session = store.sessions.first(where: { $0.id == id }) {
                DetailView(session: session)
                    .id(session.id)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                EmptyStateView()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .navigationSplitViewStyle(.balanced)
    }
}

struct EmptyStateView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
            
            VStack(spacing: 8) {
                Text("Select a profile")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Choose a profile from the sidebar to view details")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("or press ⌘N to create a new one")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isAnimating = true
        }
    }
}
