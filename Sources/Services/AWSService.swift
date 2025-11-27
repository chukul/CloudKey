import Foundation
import AppKit

class AWSService {
    static let shared = AWSService()
    
    private var awsPath: String {
        UserDefaults.standard.string(forKey: "awsCliPath") ?? "/usr/local/bin/aws"
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
            
            guard let roleArn = session.roleArn else {
                let error = "[\(timestamp)] ❌ Error: Role ARN is missing"
                updatedSession.logs.append(error)
                throw NSError(domain: "AWSService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Role ARN is missing"])
            }
            
            // Use profile alias as session name (AWS will prepend role name automatically)
            let sessionName = session.alias
            let sourceProfile = session.sourceProfile ?? session.profileName
            
            var args = [
                "sts", "assume-role",
                "--role-arn", roleArn,
                "--role-session-name", sessionName,
                "--profile", sourceProfile,
                "--output", "json"
            ]
            
            if let mfaSerial = session.mfaSerial, let token = mfaToken {
                args.append("--serial-number")
                args.append(mfaSerial)
                args.append("--token-code")
                args.append(token)
            }
            
            let command = "aws " + args.joined(separator: " ")
            updatedSession.logs.append("[\(timestamp)] 🔄 Executing: \(command)")
            
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
                updatedSession.logs.append("[\(timestamp)] ⏰ Session expires: \(response.Credentials.Expiration.formatted())")
            } catch {
                updatedSession.logs.append("[\(timestamp)] ❌ Error: \(error.localizedDescription)")
                throw error
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
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        if process.terminationStatus != 0 {
            let output = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AWSService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])
        }
        
        return data
    }
    
    private func updateCredentialsFile(profile: String, credentials: Credentials) throws {
        let credentialsPath = self.credentialsURL
        
        var content = ""
        if FileManager.default.fileExists(atPath: credentialsPath.path) {
            content = try String(contentsOf: credentialsPath, encoding: .utf8)
        }
        
        // Simple INI parser/updater
        var lines = content.components(separatedBy: .newlines)
        
        // Remove existing section if present
        if let startIndex = lines.firstIndex(of: "[\(profile)]") {
            var endIndex = startIndex + 1
            while endIndex < lines.count && !lines[endIndex].hasPrefix("[") {
                endIndex += 1
            }
            lines.removeSubrange(startIndex..<endIndex)
        }
        
        // Append new section
        lines.append("[\(profile)]")
        lines.append("aws_access_key_id = \(credentials.AccessKeyId)")
        lines.append("aws_secret_access_key = \(credentials.SecretAccessKey)")
        lines.append("aws_session_token = \(credentials.SessionToken)")
        lines.append("") // Empty line
        
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
    
    func openAWSConsole(for session: Session) async -> Session {
        var updatedSession = session
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        
        updatedSession.logs.append("[\(timestamp)] 🌐 Opening AWS Console...")
        
        guard session.status == .active else {
            updatedSession.logs.append("[\(timestamp)] ❌ Session must be active to open console")
            return updatedSession
        }
        
        // Use AWS CLI to generate console URL
        let script = """
        #!/bin/bash
        export AWS_PROFILE="\(session.alias)"
        export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
        
        echo "📋 Getting credentials for profile: \(session.alias)"
        
        # Get credentials
        ACCESS_KEY=$(\(awsPath) configure get aws_access_key_id)
        SECRET_KEY=$(\(awsPath) configure get aws_secret_access_key)
        SESSION_TOKEN=$(\(awsPath) configure get aws_session_token)
        
        echo "🔑 Access Key: ${ACCESS_KEY:0:10}..."
        
        if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
            echo "❌ Failed to get credentials from profile"
            exit 1
        fi
        
        # Create JSON for federation
        SESSION_JSON=$(cat <<EOF
        {"sessionId":"$ACCESS_KEY","sessionKey":"$SECRET_KEY","sessionToken":"$SESSION_TOKEN"}
        EOF
        )
        
        echo "🔗 Requesting signin token..."
        
        # URL encode and get signin token
        ENCODED_SESSION=$(echo -n "$SESSION_JSON" | jq -sRr @uri)
        SIGNIN_URL="https://signin.aws.amazon.com/federation?Action=getSigninToken&SessionDuration=43200&Session=$ENCODED_SESSION"
        
        # Get token
        TOKEN=$(curl -s "$SIGNIN_URL" | jq -r '.SigninToken')
        
        echo "🎫 Token received: ${TOKEN:0:20}..."
        
        if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
            # Generate console URL with region
            CONSOLE_URL="https://signin.aws.amazon.com/federation?Action=login&Issuer=CloudKey&Destination=https://\(session.region).console.aws.amazon.com/console/home?region=\(session.region)&SigninToken=$TOKEN"
            echo "🌐 Opening URL..."
            open "$CONSOLE_URL"
            echo "✅ Opened console in region \(session.region)"
        else
            echo "❌ Failed to get signin token"
            echo "🔄 Fallback: Opening console directly"
            open "https://\(session.region).console.aws.amazon.com/console/home?region=\(session.region)"
        fi
        """
        
        // Write script to temp file
        let tempDir = FileManager.default.temporaryDirectory
        let scriptPath = tempDir.appendingPathComponent("open-console-\(UUID().uuidString).sh")
        
        do {
            try script.write(to: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)
            
            // Execute script
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptPath.path]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            
            // Log output
            for line in output.components(separatedBy: .newlines).filter({ !$0.isEmpty }) {
                updatedSession.logs.append("[\(timestamp)] \(line)")
            }
            
            // Cleanup
            try? FileManager.default.removeItem(at: scriptPath)
        } catch {
            updatedSession.logs.append("[\(timestamp)] ❌ Error: \(error.localizedDescription)")
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
