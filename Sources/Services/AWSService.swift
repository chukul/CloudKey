import Foundation
import AppKit

class AWSService {
    static let shared = AWSService()
    
    // Cache for MFA session tokens
    private var sessionTokenCache: [String: (credentials: Credentials, expiration: Date)] = [:]
    private let mfaCachePath: URL
    
    init() {
        // Setup MFA cache path
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("CloudKey")
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755])
        mfaCachePath = appSupport.appendingPathComponent("mfa-cache.json")
        
        // Load cached MFA tokens from disk
        loadMFACache()
    }
    
    private func loadMFACache() {
        guard FileManager.default.fileExists(atPath: mfaCachePath.path) else {
            print("No MFA cache file found")
            return
        }
        
        do {
            let data = try Data(contentsOf: mfaCachePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let cacheDict = try decoder.decode([String: CachedMFAToken].self, from: data)
            
            // Convert to internal format and filter expired
            let now = Date()
            for (key, cached) in cacheDict {
                if cached.expiration > now {
                    sessionTokenCache[key] = (cached.credentials, cached.expiration)
                    print("✅ Loaded cached MFA token for \(key), expires: \(cached.expiration.formatted())")
                } else {
                    print("⏰ Skipped expired MFA token for \(key)")
                }
            }
        } catch {
            print("Failed to load MFA cache: \(error.localizedDescription)")
        }
    }
    
    private func saveMFACache() {
        do {
            // Convert to codable format
            var cacheDict: [String: CachedMFAToken] = [:]
            for (key, value) in sessionTokenCache {
                cacheDict[key] = CachedMFAToken(credentials: value.credentials, expiration: value.expiration)
            }
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(cacheDict)
            try data.write(to: mfaCachePath, options: [.atomic])
            
            print("✅ Saved MFA cache to disk (\(sessionTokenCache.count) entries)")
        } catch {
            print("Failed to save MFA cache: \(error.localizedDescription)")
        }
    }
    
    private var debugEnabled: Bool {
        UserDefaults.standard.bool(forKey: "debugLogging")
    }
    
    private func debugLog(_ message: String) {
        if debugEnabled {
            print("🔍 DEBUG: \(message)")
        }
    }
    
    func hasCachedMFAToken(sourceProfile: String, mfaSerial: String) -> Bool {
        let cacheKey = "\(sourceProfile)-\(mfaSerial)"
        let now = Date()
        
        debugLog("Checking MFA cache for key: \(cacheKey)")
        debugLog("Cache contains \(sessionTokenCache.count) entries")
        
        if let cached = sessionTokenCache[cacheKey] {
            let remaining = cached.expiration.timeIntervalSince(now)
            debugLog("Found cached token, expires in \(Int(remaining/60)) minutes")
            
            if cached.expiration > now.addingTimeInterval(300) {
                debugLog("Cache is valid (more than 5 minutes remaining)")
                return true
            } else {
                debugLog("Cache expired or expiring soon")
                return false
            }
        } else {
            debugLog("No cached token found for this key")
            debugLog("Available cache keys: \(sessionTokenCache.keys.joined(separator: ", "))")
            return false
        }
    }
    
    // For testing: clear MFA cache
    func clearMFACache() {
        sessionTokenCache.removeAll()
        try? FileManager.default.removeItem(at: mfaCachePath)
        print("🧹 MFA session token cache cleared (memory and disk)")
    }
    
    // For testing: get cache info
    func getMFACacheInfo() -> String {
        if sessionTokenCache.isEmpty {
            return "No cached MFA tokens"
        }
        
        var info = "Cached MFA tokens:\n"
        for (key, value) in sessionTokenCache {
            let remaining = value.expiration.timeIntervalSince(Date())
            let hours = Int(remaining / 3600)
            let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
            info += "  • \(key): expires in \(hours)h \(minutes)m\n"
        }
        return info
    }
    
    func setAsDefaultProfile(_ session: Session) throws {
        guard session.status == .active else {
            throw NSError(domain: "AWSService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Only active sessions can be set as default"])
        }
        
        let credentialsPath = self.credentialsURL
        guard FileManager.default.fileExists(atPath: credentialsPath.path) else {
            throw NSError(domain: "AWSService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Credentials file not found"])
        }
        
        let content = try String(contentsOf: credentialsPath, encoding: .utf8)
        var lines = content.components(separatedBy: .newlines)
        
        // Find the profile section
        guard let profileIndex = lines.firstIndex(of: "[\(session.alias)]") else {
            throw NSError(domain: "AWSService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Profile not found in credentials file"])
        }
        
        // Extract credentials from profile
        var accessKey = ""
        var secretKey = ""
        var sessionToken = ""
        
        var i = profileIndex + 1
        while i < lines.count && !lines[i].hasPrefix("[") {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("aws_access_key_id") {
                accessKey = line.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? ""
            } else if line.hasPrefix("aws_secret_access_key") {
                secretKey = line.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? ""
            } else if line.hasPrefix("aws_session_token") {
                sessionToken = line.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? ""
            }
            i += 1
        }
        
        // Remove existing [default] section
        if let defaultIndex = lines.firstIndex(of: "[default]") {
            var endIndex = defaultIndex + 1
            while endIndex < lines.count && !lines[endIndex].hasPrefix("[") {
                endIndex += 1
            }
            lines.removeSubrange(defaultIndex..<endIndex)
        }
        
        // Add new [default] section
        lines.append("[default]")
        lines.append("aws_access_key_id = \(accessKey)")
        lines.append("aws_secret_access_key = \(secretKey)")
        if !sessionToken.isEmpty {
            lines.append("aws_session_token = \(sessionToken)")
        }
        lines.append("")
        
        let newContent = lines.joined(separator: "\n")
        try newContent.write(to: credentialsPath, atomically: true, encoding: .utf8)
        
        print("✅ Set \(session.alias) as default profile")
    }
    
    func isDefaultProfile(_ profileName: String) -> Bool {
        guard FileManager.default.fileExists(atPath: credentialsURL.path) else { return false }
        
        do {
            let content = try String(contentsOf: credentialsURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            // Find [default] section
            guard let defaultIndex = lines.firstIndex(of: "[default]") else { return false }
            
            // Find [profile] section
            guard let profileIndex = lines.firstIndex(of: "[\(profileName)]") else { return false }
            
            // Extract access keys from both sections
            var defaultKey = ""
            var profileKey = ""
            
            var i = defaultIndex + 1
            while i < lines.count && !lines[i].hasPrefix("[") {
                let line = lines[i].trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("aws_access_key_id") {
                    defaultKey = line.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? ""
                    break
                }
                i += 1
            }
            
            i = profileIndex + 1
            while i < lines.count && !lines[i].hasPrefix("[") {
                let line = lines[i].trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("aws_access_key_id") {
                    profileKey = line.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? ""
                    break
                }
                i += 1
            }
            
            return !defaultKey.isEmpty && defaultKey == profileKey
        } catch {
            return false
        }
    }
    
    private var awsPath: String {
        if let customPath = UserDefaults.standard.string(forKey: "awsCliPath"), !customPath.isEmpty {
            return customPath
        }
        
        // Auto-detect AWS CLI location
        let possiblePaths = [
            "/opt/homebrew/bin/aws",  // Apple Silicon
            "/usr/local/bin/aws",      // Intel Mac
            "/usr/bin/aws"             // System default
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return "/opt/homebrew/bin/aws" // Fallback for Apple Silicon
    }
    
    var credentialsURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".aws/credentials")
    
    func startSession(_ session: Session, mfaToken: String? = nil) async throws -> Session {
        var updatedSession = session
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        
        switch session.type {
        case .iamUser:
            // For IAM User, we just verify the profile exists
            updatedSession.status = .active
            updatedSession.logs.append("[\(timestamp)] ✅ IAM User session activated")
            
        case .assumedRole:
            // Construct command: aws sts assume-role --role-arn <arn> --role-session-name <name> --profile <source_profile>
            
            debugLog("Starting assume role for session: \(session.alias)")
            
            guard let roleArn = session.roleArn else {
                let error = "[\(timestamp)] ❌ Error: Role ARN is missing"
                updatedSession.logs.append(error)
                throw NSError(domain: "AWSService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Role ARN is missing"])
            }
            
            debugLog("Role ARN: \(roleArn)")
            
            // Use profile alias as session name
            let sessionName = session.alias
            let sourceProfile = session.sourceProfile ?? session.profileName
            
            debugLog("Session name: \(sessionName)")
            debugLog("Source profile: \(sourceProfile)")
            
            // Check if we need to use MFA session token
            var effectiveProfile = sourceProfile
            var usedDirectMFA = false
            
            if let mfaSerial = session.mfaSerial {
                debugLog("MFA Serial: \(mfaSerial)")
                
                // If skipMFACache is true, skip caching and use direct MFA
                if session.skipMFACache {
                    guard let token = mfaToken else {
                        let error = "[\(timestamp)] ❌ Error: MFA token required"
                        updatedSession.logs.append(error)
                        throw NSError(domain: "AWSService", code: 1, userInfo: [NSLocalizedDescriptionKey: "MFA token required"])
                    }
                    debugLog("Skipping MFA cache - using direct MFA")
                    updatedSession.logs.append("[\(timestamp)] 🔐 Using direct MFA (no cache, federation-compatible)")
                    usedDirectMFA = true
                    // effectiveProfile stays as sourceProfile, MFA will be added to assume-role
                } else {
                    // Normal flow with MFA caching
                    let cacheKey = "\(sourceProfile)-\(mfaSerial)"
                    let now = Date()
                    
                    // Check cache first
                    if let cached = sessionTokenCache[cacheKey], cached.expiration > now.addingTimeInterval(300) {
                        // Use cached session token (valid for at least 5 more minutes)
                        debugLog("Using cached MFA session token")
                        updatedSession.logs.append("[\(timestamp)] 🔄 Using cached MFA session token")
                        effectiveProfile = "\(sourceProfile)-mfa-session"
                    } else if let token = mfaToken {
                        debugLog("Getting new MFA session token")
                        // Get new session token with MFA
                        updatedSession.logs.append("[\(timestamp)] 🔐 Getting MFA session token (valid for 12 hours)...")
                    
                    let sessionArgs = [
                        "sts", "get-session-token",
                        "--serial-number", mfaSerial,
                        "--token-code", token,
                        "--duration-seconds", "43200", // 12 hours
                        "--profile", sourceProfile,
                        "--output", "json"
                    ]
                    
                    do {
                        let sessionData = try await runAWSCommand(sessionArgs)
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        let sessionResponse = try decoder.decode(STSResponse.self, from: sessionData)
                        
                        // Cache the session token
                        sessionTokenCache[cacheKey] = (sessionResponse.Credentials, sessionResponse.Credentials.Expiration)
                        saveMFACache()
                        
                        // Write session token to a temporary profile
                        effectiveProfile = "\(sourceProfile)-mfa-session"
                        try updateCredentialsFile(profile: effectiveProfile, credentials: sessionResponse.Credentials, setAsDefault: false)
                        
                        updatedSession.logs.append("[\(timestamp)] ✅ MFA session token obtained (expires: \(sessionResponse.Credentials.Expiration.formatted()))")
                        updatedSession.logs.append("[\(timestamp)] 💡 You won't need MFA again for 12 hours!")
                    } catch {
                        updatedSession.logs.append("[\(timestamp)] ❌ Failed to get session token: \(error.localizedDescription)")
                        throw error
                    }
                } else {
                    // No cached token and no MFA token provided - this shouldn't happen
                    let error = "[\(timestamp)] ❌ Error: MFA token required but not provided"
                    updatedSession.logs.append(error)
                    throw NSError(domain: "AWSService", code: 1, userInfo: [NSLocalizedDescriptionKey: "MFA token required"])
                }
            }
            
            // Now assume the role using the effective profile (either original or MFA session)
            var args = [
                "sts", "assume-role",
                "--role-arn", roleArn,
                "--role-session-name", sessionName,
                "--profile", effectiveProfile,
                "--output", "json"
            ]
            
            // If using direct MFA (skipMFACache), add MFA to assume-role command
            if usedDirectMFA, let mfaSerial = session.mfaSerial, let token = mfaToken {
                args.append("--serial-number")
                args.append(mfaSerial)
                args.append("--token-code")
                args.append(token)
            }
            
            let command = "aws " + args.joined(separator: " ")
            updatedSession.logs.append("[\(timestamp)] 🔄 Assuming role...")
            
            do {
                let data = try await runAWSCommand(args)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let response = try decoder.decode(STSResponse.self, from: data)
                
                // Update ~/.aws/credentials
                try updateCredentialsFile(profile: session.alias, credentials: response.Credentials)
                
                updatedSession.status = .active
                updatedSession.expiration = response.Credentials.Expiration
                updatedSession.accessKeyId = response.Credentials.AccessKeyId
                updatedSession.logs.append("[\(timestamp)] ✅ Successfully assumed role")
                updatedSession.logs.append("[\(timestamp)] 📝 Updated credentials file: ~/.aws/credentials")
                updatedSession.logs.append("[\(timestamp)] 🎯 Set as default profile - you can now use AWS CLI without --profile")
                updatedSession.logs.append("[\(timestamp)] ⏰ Session expires: \(response.Credentials.Expiration.formatted())")
            } catch {
                let errorMsg = "[\(timestamp)] ❌ Error: \(error.localizedDescription)"
                updatedSession.logs.append(errorMsg)
                throw error
            }
            }
            
        case .sso:
            // aws sso login
            let args = ["sso", "login", "--profile", session.profileName]
            let command = "aws " + args.joined(separator: " ")
            updatedSession.logs.append("[\(timestamp)] 🔄 Executing: \(command)")
            
            do {
                _ = try await runAWSCommand(args)
                updatedSession.status = .active
                updatedSession.logs.append("[\(timestamp)] ✅ SSO login successful")
            } catch {
                updatedSession.logs.append("[\(timestamp)] ❌ Error: \(error.localizedDescription)")
                throw error
            }
        }
        
        return updatedSession
    }
    
    func stopSession(_ session: Session) async throws -> Session {
        var updatedSession = session
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        
        updatedSession.logs.append("[\(timestamp)] 🛑 Stopping session...")
        
        // Remove the profile from credentials file
        do {
            try removeProfileFromCredentials(profile: session.alias)
            // Also remove [default] if it matches this session
            try removeDefaultIfMatches(profile: session.alias)
            updatedSession.logs.append("[\(timestamp)] ✅ Removed credentials from ~/.aws/credentials")
        } catch {
            updatedSession.logs.append("[\(timestamp)] ⚠️ Warning: \(error.localizedDescription)")
        }
        
        updatedSession.status = .inactive
        updatedSession.accessKeyId = nil
        updatedSession.expiration = nil
        updatedSession.logs.append("[\(timestamp)] ✅ Session stopped")
        
        return updatedSession
    }
    
    // MARK: - Helper Methods
    
    private func runAWSCommand(_ arguments: [String]) async throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: awsPath)
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        debugLog("AWS CLI Path: \(awsPath)")
        debugLog("Command: aws \(arguments.joined(separator: " "))")
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        debugLog("Exit code: \(process.terminationStatus)")
        if debugEnabled {
            let output = String(data: data, encoding: .utf8) ?? ""
            debugLog("Output: \(output)")
        }
        
        if process.terminationStatus != 0 {
            let output = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AWSService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])
        }
        
        return data
    }
    
    private func updateCredentialsFile(profile: String, credentials: Credentials, setAsDefault: Bool = true) throws {
        let credentialsPath = self.credentialsURL
        
        var content = ""
        if FileManager.default.fileExists(atPath: credentialsPath.path) {
            content = try String(contentsOf: credentialsPath, encoding: .utf8)
        }
        
        // Simple INI parser/updater
        var lines = content.components(separatedBy: .newlines)
        
        // Remove existing profile section if present
        if let startIndex = lines.firstIndex(of: "[\(profile)]") {
            var endIndex = startIndex + 1
            while endIndex < lines.count && !lines[endIndex].hasPrefix("[") {
                endIndex += 1
            }
            lines.removeSubrange(startIndex..<endIndex)
        }
        
        // Remove existing [default] section if we're setting as default
        if setAsDefault {
            if let startIndex = lines.firstIndex(of: "[default]") {
                var endIndex = startIndex + 1
                while endIndex < lines.count && !lines[endIndex].hasPrefix("[") {
                    endIndex += 1
                }
                lines.removeSubrange(startIndex..<endIndex)
            }
        }
        
        // Append profile section
        if !lines.isEmpty && !lines.last!.isEmpty {
            lines.append("") // Ensure blank line before new section
        }
        lines.append("[\(profile)]")
        lines.append("aws_access_key_id = \(credentials.AccessKeyId)")
        lines.append("aws_secret_access_key = \(credentials.SecretAccessKey)")
        lines.append("aws_session_token = \(credentials.SessionToken)")
        lines.append("") // Empty line
        
        // Also set as [default] for convenience
        if setAsDefault {
            lines.append("[default]")
            lines.append("aws_access_key_id = \(credentials.AccessKeyId)")
            lines.append("aws_secret_access_key = \(credentials.SecretAccessKey)")
            lines.append("aws_session_token = \(credentials.SessionToken)")
            lines.append("") // Empty line
        }
        
        let newContent = lines.joined(separator: "\n")
        try newContent.write(to: credentialsPath, atomically: true, encoding: .utf8)
    }
    
    private func removeProfileFromCredentials(profile: String) throws {
        let credentialsPath = self.credentialsURL
        
        guard FileManager.default.fileExists(atPath: credentialsPath.path) else { return }
        
        let content = try String(contentsOf: credentialsPath, encoding: .utf8)
        var lines = content.components(separatedBy: .newlines)
        
        if let startIndex = lines.firstIndex(of: "[\(profile)]") {
            var endIndex = startIndex + 1
            while endIndex < lines.count && !lines[endIndex].hasPrefix("[") {
                endIndex += 1
            }
            lines.removeSubrange(startIndex..<endIndex)
            
            let newContent = lines.joined(separator: "\n")
            try newContent.write(to: credentialsPath, atomically: true, encoding: .utf8)
        }
    }
    
    private func removeDefaultIfMatches(profile: String) throws {
        let credentialsPath = self.credentialsURL
        
        guard FileManager.default.fileExists(atPath: credentialsPath.path) else { return }
        
        let content = try String(contentsOf: credentialsPath, encoding: .utf8)
        var lines = content.components(separatedBy: .newlines)
        
        // Remove [default] section
        if let startIndex = lines.firstIndex(of: "[default]") {
            var endIndex = startIndex + 1
            while endIndex < lines.count && !lines[endIndex].hasPrefix("[") {
                endIndex += 1
            }
            lines.removeSubrange(startIndex..<endIndex)
            
            let newContent = lines.joined(separator: "\n")
            try newContent.write(to: credentialsPath, atomically: true, encoding: .utf8)
        }
    }
    
    func openAWSConsole(for session: Session) async -> Session {
        var updatedSession = session
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        
        updatedSession.logs.append("[\(timestamp)] 🌐 Opening AWS Console...")
        
        guard session.status == .active else {
            updatedSession.logs.append("[\(timestamp)] ❌ Session must be active to open console")
            return updatedSession
        }
        
        // Attempt federation only if skipMFACache is enabled (direct MFA credentials)
        if session.skipMFACache {
            updatedSession.logs.append("[\(timestamp)] 🔐 Attempting federated sign-in...")
            return await attemptFederatedConsole(for: updatedSession)
        } else {
            updatedSession.logs.append("[\(timestamp)] ℹ️  Opening console directly (using MFA cache)")
            return await openDirectConsole(for: updatedSession)
        }
    }
    
    private func attemptFederatedConsole(for session: Session) async -> Session {
        var updatedSession = session
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        
        let script = """
        #!/bin/bash
        export AWS_PROFILE="\(session.alias)"
        export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
        
        # Get credentials
        ACCESS_KEY=$(\(awsPath) configure get aws_access_key_id)
        SECRET_KEY=$(\(awsPath) configure get aws_secret_access_key)
        SESSION_TOKEN=$(\(awsPath) configure get aws_session_token)
        
        if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
            echo "ERROR"
            exit 1
        fi
        
        # Create JSON and encode
        SESSION_JSON="{\\"sessionId\\":\\"$ACCESS_KEY\\",\\"sessionKey\\":\\"$SECRET_KEY\\",\\"sessionToken\\":\\"$SESSION_TOKEN\\"}"
        ENCODED_SESSION=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$SESSION_JSON''', safe=''))")
        
        # Get signin token
        RESPONSE=$(curl -s "https://signin.aws.amazon.com/federation?Action=getSigninToken&SessionDuration=43200&Session=$ENCODED_SESSION")
        TOKEN=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('SigninToken', ''))" 2>/dev/null)
        
        if [ -n "$TOKEN" ] && [ ${#TOKEN} -gt 10 ]; then
            CONSOLE_URL="https://signin.aws.amazon.com/federation?Action=login&Issuer=CloudKey&Destination=https://\(session.region).console.aws.amazon.com/console/home?region=\(session.region)&SigninToken=$TOKEN"
            open "$CONSOLE_URL"
            echo "SUCCESS"
        else
            echo "FAILED"
            exit 1
        fi
        """
        
        let tempDir = FileManager.default.temporaryDirectory
        let scriptPath = tempDir.appendingPathComponent("open-console-\(UUID().uuidString).sh")
        
        do {
            try script.write(to: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptPath.path]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            try? FileManager.default.removeItem(at: scriptPath)
            
            if output.contains("SUCCESS") {
                updatedSession.logs.append("[\(timestamp)] ✅ Opened console with automatic sign-in")
            } else {
                updatedSession.logs.append("[\(timestamp)] ⚠️  Federation failed, opening console directly")
                return await openDirectConsole(for: updatedSession)
            }
        } catch {
            updatedSession.logs.append("[\(timestamp)] ❌ Error: \(error.localizedDescription)")
            return await openDirectConsole(for: updatedSession)
        }
        
        return updatedSession
    }
    
    private func openDirectConsole(for session: Session) async -> Session {
        var updatedSession = session
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        
        let consoleURL = "https://\(session.region).console.aws.amazon.com/console/home?region=\(session.region)"
        
        if let url = URL(string: consoleURL) {
            await MainActor.run {
                NSWorkspace.shared.open(url)
            }
            updatedSession.logs.append("[\(timestamp)] ✅ Opened console - sign in manually if needed")
        }
        
        return updatedSession
    }
}

struct STSResponse: Codable {
    let Credentials: Credentials
}

struct Credentials: Codable {
    let AccessKeyId: String
    let SecretAccessKey: String
    let SessionToken: String
    let Expiration: Date
}

struct CachedMFAToken: Codable {
    let credentials: Credentials
    let expiration: Date
}
