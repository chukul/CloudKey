# CloudKey

<p align="center">
  <img src="Assets.xcassets/AppIcon.appiconset/256.png" alt="CloudKey Logo" width="128" height="128">
</p>

A modern macOS application for managing AWS credentials and sessions, inspired by Leapp.
Built with **SwiftUI** targeting macOS 13.0+.

## ✨ Features

### 🔐 Session Management
- **Multiple Profile Types**: IAM User, Assumed Roles, and AWS SSO
- **Quick Actions**: Start/stop sessions with hover buttons in sidebar
- **Live Expiration Timer**: Real-time countdown with color-coded status
- **Recent Sessions**: Quick access to your last 5 used profiles
- **Session Groups**: Organize profiles into folders (Dev/Prod/Personal)
- **MFA Support**: Integrated MFA token input for secure authentication
- **Session Cloning**: Duplicate profiles with one click

### 🎨 User Experience
- **Modern 3-Pane Layout**: Clean sidebar, list, and detail views
- **Search & Filter**: Find profiles quickly with real-time search
- **Status Indicators**: Visual badges for active, inactive, and expiring sessions
- **Hover Actions**: Context-sensitive buttons appear on hover
- **Visual Feedback**: Toast notifications for clipboard operations
- **Keyboard Shortcuts**:
  - `⌘N` - New profile
  - `⌘R` - Refresh sessions
  - `⌘↩` - Start/stop selected session

### ☁️ AWS Integration
- **IAM User Sessions**: Direct credential management with access keys
- **Assumed Roles**: STS assume-role with MFA and source profile support
- **AWS SSO**: Single sign-on integration
- **Credential Management**: Automatic ~/.aws/credentials updates
- **AWS Console Access**: One-click federated login to AWS Console
- **Console Logging**: Real-time activity logs with detailed output
- **Export Options**: Shell, JSON, and AWS CLI format exports

## 📋 Requirements

- macOS 13.0 or later
- AWS CLI installed and configured
- `jq` for JSON processing (for console access)
- `curl` (pre-installed on macOS)

### Installing Dependencies

```bash
# Install AWS CLI
brew install awscli

# Install jq
brew install jq
```

## 🚀 Installation

### Option 1: Build from Source

```bash
# Clone the repository
git clone https://github.com/chukul/CloudKey.git
cd CloudKey

# Build the app
./build-app.sh

# Run the app
open CloudKey.app
```

### Option 2: Swift Package Manager

```bash
# Build and run directly
swift run
```

## 📖 Usage

### Adding a Profile

1. Click the **+** button in the toolbar (or press `⌘N`)
2. Choose profile type:
   - **IAM User**: Enter access key and secret key
   - **Assumed Role**: Enter role ARN, select source profile, optional MFA
   - **AWS SSO**: Configure SSO settings
3. Fill in profile details (alias, region, account ID)
4. Optionally assign to a group
5. Click **Save**

### Starting a Session

1. Select a profile from the sidebar
2. Click the **Start** button (or press `⌘↩`)
3. Enter MFA token if required
4. Session credentials are automatically written to `~/.aws/credentials`

### Opening AWS Console

1. Start an active session
2. Click **Open Console** button
3. Browser opens with federated login to AWS Console
4. Check the **Console** tab for detailed logs

### Exporting Credentials

1. Select an active session
2. Click the export menu (⋮)
3. Choose format:
   - **Shell**: Export as environment variables
   - **JSON**: Export as JSON object
   - **AWS CLI**: Export as AWS CLI config

## 🏗️ Project Structure

```
CloudKey/
├── Sources/
│   ├── CloudKeyApp.swift        # App entry point
│   ├── Models/
│   │   ├── Session.swift        # Session data model
│   │   ├── SessionStore.swift   # State management & persistence
│   │   └── ColorTheme.swift     # Color definitions
│   ├── Views/
│   │   ├── ContentView.swift    # Main window layout
│   │   ├── SidebarView.swift    # Profile list with search/filter
│   │   ├── DetailView.swift     # Session details and controls
│   │   ├── ProfileEditorView.swift  # Add/edit profile form
│   │   ├── MFAInputView.swift   # MFA token input
│   │   └── SettingsView.swift   # App settings
│   └── Services/
│       └── AWSService.swift     # AWS CLI integration
├── Assets.xcassets/             # App icons
├── Package.swift                # Swift package manifest
├── build-app.sh                 # Build script for .app bundle
└── README.md
```

## 🔧 Configuration

### AWS CLI Path

By default, CloudKey looks for AWS CLI at `/usr/local/bin/aws`. You can configure a custom path in Settings.

### Data Storage

CloudKey stores session data in:
```
~/Library/Application Support/CloudKey/
├── sessions.json    # Profile configurations
└── recent.json      # Recent session history
```

AWS credentials are stored in the standard location:
```
~/.aws/credentials
```

## 🎯 Key Features Explained

### Live Expiration Timer
- Automatically checks session expiration every 10 seconds
- Color-coded status: Green (active), Orange (expiring soon), Gray (inactive)
- Updates status automatically when sessions expire

### Recent Sessions
- Tracks your last 5 used profiles
- Quick access section at the top of the sidebar
- Automatically updates when you start sessions

### Session Groups
- Organize profiles into logical groups (e.g., Dev, Prod, Personal)
- Collapsible sections in the sidebar
- Assign groups when creating/editing profiles

### AWS Console Access
- Uses AWS Federation API for secure console access
- Generates temporary signin tokens
- Opens browser with federated login
- Respects profile region settings

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📝 License

This project is open source and available under the MIT License.

## 🙏 Acknowledgments

- Inspired by [Leapp](https://www.leapp.cloud/)
- Built with SwiftUI and AWS SDK

## 📧 Support

For issues, questions, or suggestions, please open an issue on GitHub.

---

Made with ❤️ for AWS developers
