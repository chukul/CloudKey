import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: SessionStore
    @State private var selection: Session.ID?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showMFAForRenewal = false
    @State private var mfaToken = ""
    @State private var sessionToRenew: Session?
    
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
        .overlay(alignment: .bottomTrailing) {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "202511301520"
            
            // Format build number from YYYYMMDDHHmm to YY-MM-DD HH:mm
            let formatted: String = {
                if buildNumber.count == 12 {
                    let year = buildNumber.prefix(4).suffix(2)
                    let month = buildNumber.dropFirst(4).prefix(2)
                    let day = buildNumber.dropFirst(6).prefix(2)
                    let hour = buildNumber.dropFirst(8).prefix(2)
                    let minute = buildNumber.dropFirst(10).prefix(2)
                    return "\(year)-\(month)-\(day) \(hour):\(minute)"
                }
                return buildNumber
            }()
            
            Text("v\(version) (Build: \(formatted))")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(8)
        }
        .alert("Session Expiring Soon", isPresented: $store.showExpirationWarning, presenting: store.expiringSession) { session in
            Button("Renew", role: .none) {
                if session.skipMFACache {
                    sessionToRenew = session
                    store.showExpirationWarning = false
                    showMFAForRenewal = true
                } else {
                    store.renewSession(session)
                }
            }
            Button("Dismiss", role: .cancel) {
                store.showExpirationWarning = false
            }
        } message: { session in
            if let expiration = session.expiration {
                let minutes = Int(expiration.timeIntervalSinceNow / 60)
                Text("\(session.alias) will expire in \(minutes) minute\(minutes == 1 ? "" : "s"). Renew now to avoid interruption.")
            }
        }
        .sheet(isPresented: $showMFAForRenewal) {
            MFAInputView(mfaToken: $mfaToken, onSubmit: {
                if let session = sessionToRenew {
                    store.renewSession(session, mfaToken: mfaToken)
                }
                showMFAForRenewal = false
                mfaToken = ""
                sessionToRenew = nil
            }, onCancel: {
                showMFAForRenewal = false
                mfaToken = ""
                sessionToRenew = nil
            })
        }
    }
}

struct EmptyStateView: View {
    @State private var isAnimating = false
    @EnvironmentObject var store: SessionStore
    @State private var showProfileEditor = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
            
            VStack(spacing: 8) {
                Text("No Profiles Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Get started by creating your first AWS profile")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    showProfileEditor = true
                }) {
                    Label("Create Your First Profile", systemImage: "plus.circle.fill")
                        .font(.body)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Text("or press ⌘N")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isAnimating = true
        }
        .sheet(isPresented: $showProfileEditor) {
            ProfileEditorView(
                session: Session(
                    alias: "",
                    profileName: "default",
                    region: "ap-southeast-1",
                    accountId: "",
                    status: .inactive,
                    type: .assumedRole,
                    logs: []
                ),
                onSave: { session in
                    store.addSession(session)
                    showProfileEditor = false
                },
                onCancel: {
                    showProfileEditor = false
                }
            )
        }
    }
}
