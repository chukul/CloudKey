import SwiftUI

struct SettingsView: View {
    @AppStorage("awsCliPath") private var awsCliPath = "/usr/local/bin/aws"
    
    var body: some View {
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
                            Text("Default: /usr/local/bin/aws")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(4)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 200)
    }
}
