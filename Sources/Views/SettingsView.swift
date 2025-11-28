import SwiftUI

struct SettingsView: View {
    @AppStorage("awsCliPath") private var awsCliPath = "/usr/local/bin/aws"
    
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
                            
                            TextField("Path to AWS CLI", text: $awsCliPath)
                                .textFieldStyle(.roundedBorder)
                            
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.secondary)
                                Text("Auto-detected: /opt/homebrew/bin/aws or /usr/local/bin/aws")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(4)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            Form {
                GroupBox {
                    VStack(spacing: 20) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)
                        
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
