import SwiftUI

struct SettingsView: View {
    @AppStorage("awsCliPath") private var awsCliPath = ""
    @AppStorage("debugLogging") private var debugLogging = false
    @State private var cacheInfo = ""
    @State private var showClearConfirm = false
    
    private var detectedPath: String {
        let possiblePaths = [
            "/opt/homebrew/bin/aws",
            "/usr/local/bin/aws",
            "/usr/bin/aws"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "/usr/local/bin/aws"
    }
    
    var body: some View {
        TabView {
            Form {
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "terminal.fill")
                                .foregroundColor(.accentColor)
                            Text("AWS CLI Configuration")
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("CLI Path", systemImage: "folder.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField("Leave empty for auto-detect", text: $awsCliPath)
                                .textFieldStyle(.roundedBorder)
                            
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.secondary)
                                Text("Auto-detected: \(detectedPath)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(4)
                }
                
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "ladybug.fill")
                                .foregroundColor(.accentColor)
                            Text("Debug Options")
                                .font(.headline)
                        }
                        
                        Toggle(isOn: $debugLogging) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enable Debug Logging")
                                    .font(.body)
                                Text("Shows detailed AWS CLI commands and responses in Console tab")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(4)
                }
                
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.accentColor)
                            Text("MFA Session Cache")
                                .font(.headline)
                        }
                        
                        Text(cacheInfo.isEmpty ? "No cached MFA tokens" : cacheInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack {
                            Button("Refresh Info") {
                                cacheInfo = AWSService.shared.getMFACacheInfo()
                            }
                            
                            Button("Clear Cache") {
                                showClearConfirm = true
                            }
                            .foregroundColor(.red)
                        }
                    }
                    .padding(4)
                }
                .alert("Clear MFA Cache & Session Credentials?", isPresented: $showClearConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear", role: .destructive) {
                        AWSService.shared.clearMFACache()
                        cacheInfo = "Cache and session credentials cleared"
                    }
                } message: {
                    Text("This will clear MFA cache and remove temporary session credentials. IAM user profiles will be preserved.")
                }
            }
            .formStyle(.grouped)
            .onAppear {
                cacheInfo = AWSService.shared.getMFACacheInfo()
            }
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            Form {
                GroupBox {
                    VStack(spacing: 20) {
                        if let appIcon = NSImage(named: "AppIcon") {
                            Image(nsImage: appIcon)
                                .resizable()
                                .frame(width: 80, height: 80)
                        } else {
                            Image(systemName: "key.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.accentColor)
                        }
                        
                        Text("CloudKey")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Version 1.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.accentColor)
                                Text("Author")
                                    .font(.headline)
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Chuchai Kultanahiran")
                                    .font(.body)
                                
                                Button(action: {
                                    if let url = URL(string: "mailto:chuchaik@outlook.com") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "envelope.fill")
                                        Text("chuchaik@outlook.com")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        VStack(spacing: 8) {
                            Text("A modern macOS application for managing")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("AWS credentials and sessions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: {
                            if let url = URL(string: "https://github.com/chukul/CloudKey") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "link")
                                Text("View on GitHub")
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .frame(width: 500, height: 400)
    }
}
