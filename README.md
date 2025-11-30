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
- **Session Expiration Warnings**: Automatic notifications when sessions are about to expire
- **Auto-Renew**: Automatically renew sessions before expiration (configurable per profile)
- **Recent Sessions**: Quick access to your last 5 used profiles
- **Session Groups**: Organize profiles into folders (Dev/Prod/Personal)
- **MFA Support**: Integrated MFA token input for secure authentication
- **MFA Caching**: Optional MFA token caching for faster session starts
- **Session Cloning**: Duplicate profiles with one click
- **Profile Import/Export**: Backup and share profile configurations as JSON

### 🎨 User Experience
- **Menu Bar Integration**: Native macOS menu bar app with quick access
  - App icon shows active session count
  - Dropdown menu with session list and actions
  - Quick renew, stop, and copy access key
  - Runs in background when main window closed
  - Red warning icon when sessions expiring
- **Modern 3-Pane Layout**: Clean sidebar, list, and detail views
- **Search & Filter**: Find profiles quickly with real-time search
- **Status Indicators**: Visual badges for active, inactive, and expiring sessions
- **Default Profile Indicator**: 🚩 flag shows which profile is set as default
- **Auto-Renew Badge**: Blue indicator shows which profiles have auto-renewal enabled
- **Quick Copy Credentials**: One-click copy buttons for access key, secret key, and session token
- **Hover Actions**: Context-sensitive buttons appear on hover
- **Visual Feedback**: Success/error alerts for all actions
- **Version Display**: Build version shown in bottom-right corner (v1.0 Build: YY-MM-DD HH:mm)
- **Region Selector**: Dropdown with all AWS regions (default: ap-southeast-1)
- **Streamlined Forms**: Simplified profile editor for assumed roles
- **Keyboard Shortcuts**:
  - `⌘N` - New profile
  - `⌘R` - Refresh sessions
  - `⌘↩` - Start/stop selected session
  - `⌘O` - Open main window (from menu bar)

### ☁️ AWS Integration
- **IAM User Sessions**: Direct credential management with access keys
- **Assumed Roles**: STS assume-role with MFA and source profile support
- **AWS SSO**: Single sign-on integration
- **Credential Management**: Automatic ~/.aws/credentials updates
- **AWS Console Access**: One-click federated login to AWS Console (with federation-compatible mode)
- **Console Logging**: Real-time activity logs with detailed output
- **Export Options**: Shell, JSON, and AWS CLI format exports
- **Auto-detect AWS CLI**: Works on both Intel and Apple Silicon Macs
- **Profile Validation**: Test profile configuration before saving with deep validation

### 🔄 Import/Export
- **Export Profiles**: Save all profile configurations to JSON
- **Import (Merge)**: Add profiles from JSON without deleting existing ones
- **Import (Replace)**: Replace all profiles with imported configuration
- **Clean Format**: Only essential fields exported (no temporary data)

### 🔒 Advanced Features
- **Skip MFA Cache**: Toggle per profile for AWS Console federation compatibility
- **Auto-Renew**: Automatically renew sessions 5 minutes before expiration
  - Silent renewal for profiles with MFA cache
  - MFA prompt for profiles without cache
  - Failure notifications with error details
  - Only shows expiration warnings for non-auto-renew profiles
- **Smart Cache Clearing**: Clear MFA cache and temporary credentials
  - Preserves IAM user source profiles
  - Removes only session tokens
  - Prevents breaking profile dependencies
- **Profile Validation**: Deep testing before saving
  - Verifies source profile exists
  - Tests credentials validity
  - Validates role ARN format
  - Actually tests assume-role with MFA
  - Provides specific error messages
- **Session Renewal**: Manual renewal with "Renew" button in expiration warnings
  - Automatic MFA prompt for federation-compatible sessions
  - Preserves session configuration during renewal

### ⚡ Performance & Efficiency
- **Optimized Resource Usage**:
  - CPU: ~5% idle, ~15% during updates (90% improvement)
  - Memory: ~97-127 MB (stable, no leaks)
  - Low power impact with optimized timers
- **Smart Updates**:
  - Timer tolerance for power efficiency (5-10s)
  - Cached icons (no runtime image processing)
  - Debounced Combine publishers (0.5s)
  - Skip updates when nothing changed
  - Session row updates every 10 seconds (reduced from 1s)
- **Efficient Monitoring**:
  - Session checks every 30 seconds
  - Menu bar updates every 2 minutes
  - Early exits for inactive sessions
  - Automatic cache cleanup for expired entries
- **Thread Safety**:
  - File locking for credential operations
  - Safe concurrent access
  - No race conditions

## 📋 Requirements

- macOS 13.0 or later (Universal Binary: Intel & Apple Silicon)
- AWS CLI installed and configured
- Python 3 (pre-installed on macOS, for URL encoding)
- `curl` (pre-installed on macOS)

### Installing Dependencies

```bash
# Install AWS CLI
brew install awscli
```

## 🚀 Installation

### Option 1: Build from Source

```bash
# Clone the repository
git clone https://github.com/chukul/CloudKey.git
cd CloudKey

# Build the universal binary app
./build-app.sh

# Run the app
open CloudKey.app
```

The build script creates a universal binary that runs natively on both Intel and Apple Silicon Macs.

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
4. Click **Test Connection** to validate configuration
   - Verifies source profile exists
   - Tests credentials
   - Validates role ARN format
   - Tests actual assume-role (with MFA if required)
5. Wait for all validation checks to pass (✅)
6. Click **Save** (only enabled after successful validation)

### Starting a Session

1. Select a profile from the sidebar
2. Click the **Start** button (or press `⌘↩`)
3. Enter MFA token if required
4. Session credentials are automatically written to `~/.aws/credentials`

### Enabling Auto-Renew

1. Right-click a profile in the sidebar
2. Select **Enable Auto-Renew**
3. Session will automatically renew 5 minutes before expiration
4. Blue "Auto-Renew" badge appears in detail view

### AWS Console Federation

For profiles that need AWS Console access:

1. Right-click the profile in sidebar
2. Select **Skip MFA Cache (federation)**
3. Start the session (will prompt for MFA each time)
4. Click **Open Console** button to access AWS Console

**Note**: AWS Console federation requires single-step assume-role credentials (not MFA-cached).

### Opening AWS Console

1. Start an active session with federation mode enabled
2. Click **Open Console** button
3. Browser opens with federated login to AWS Console
4. Check the **Console** tab for detailed logs

### Copying Individual Credentials

1. Select an active session
2. Go to the **Details** tab
3. In the **Active Credentials** section, click copy buttons (📋) next to:
   - **Access Key**: Copies the full access key ID
   - **Secret Key**: Copies the secret access key (masked in UI)
   - **Session Token**: Copies the session token (masked in UI)
4. Toast notification confirms successful copy
5. Paste credentials wherever needed (terminal, scripts, etc.)

**Note**: Each profile's credentials are read from its own section in `~/.aws/credentials`, ensuring you copy the correct credentials for each profile.

### Exporting Credentials

1. Select an active session
2. Click the export menu (⋮)
3. Choose format:
   - **Shell**: Export as environment variables
   - **JSON**: Export as JSON object
   - **AWS CLI**: Export as AWS CLI config

### Import/Export Profiles

**Export Profiles:**
1. Click the menu button (⋮) in the toolbar
2. Select **Export Profiles**
3. Choose location and save as JSON

**Import Profiles:**
1. Click the menu button (⋮) in the toolbar
2. Choose import mode:
   - **Import (Merge)**: Add profiles without deleting existing ones
   - **Import (Replace)**: Replace all profiles with imported configuration
3. Select JSON file to import

### Using Menu Bar Mode

CloudKey runs as a native macOS menu bar app:

**Menu Bar Icon:**
- Shows your app icon with active session count (e.g., "🔑 2")
- Changes to red warning icon ⚠️ when sessions are expiring (<10 minutes)
- Updates automatically every minute

**Quick Actions:**
1. Click the menu bar icon to see dropdown menu
2. View all active sessions with time remaining
3. Hover over a session to see submenu:
   - **Renew**: Renew the session (prompts for MFA if needed)
   - **Stop**: Stop the session
   - **Copy Access Key**: Copy to clipboard
4. Click **Open CloudKey** to show main window
5. Click **Quit** to exit the app

**Background Mode:**
- Close the main window (red button) - app continues running in menu bar
- App disappears from Dock when window is closed
- Click "Open CloudKey" from menu bar to bring window back
- Perfect for keeping sessions active without cluttering your Dock

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
│       ├── AWSService.swift     # AWS CLI integration
│       └── ValidationService.swift  # Profile validation
├── Assets.xcassets/             # App icons
├── Package.swift                # Swift package manifest
├── build-app.sh                 # Build script for universal binary
└── README.md
```

## 🔧 Configuration

### AWS CLI Path

CloudKey automatically detects AWS CLI location:
- `/opt/homebrew/bin/aws` (Apple Silicon)
- `/usr/local/bin/aws` (Intel Mac)
- `/usr/bin/aws` (System default)

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

### Auto-Renew
- Automatically renews sessions 5 minutes before expiration
- For profiles with MFA cache: Renews silently in background
- For profiles without MFA cache: Shows notification requesting MFA token
- Displays success/failure notifications
- Can be enabled/disabled per profile via context menu

### Session Expiration Warnings
- Checks every 10 seconds for expiring sessions
- Shows in-app alert and system notification
- Configurable warning threshold (default: 10 minutes)
- "Renew" button in alert for quick renewal
- Automatically prompts for MFA if needed

### Profile Validation
- Tests configuration before allowing save
- Verifies source profile exists in ~/.aws/credentials
- Validates credentials with `aws sts get-caller-identity`
- Checks role ARN format
- Actually tests assume-role with provided MFA token
- Provides specific error messages for troubleshooting

### AWS Console Federation
- Uses AWS Federation API for secure console access
- Requires single-step assume-role (skipMFACache mode)
- Generates temporary signin tokens with Python URL encoding
- Opens browser with federated login
- Respects profile region settings

### MFA Caching
- Caches MFA session tokens for 12 hours
- Faster session starts (no MFA prompt each time)
- Toggle per profile: "Use MFA Cache (faster)" vs "Skip MFA Cache (federation)"
- Federation mode bypasses cache for AWS Console compatibility

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
