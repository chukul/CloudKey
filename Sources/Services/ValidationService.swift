import Foundation

enum ValidationResult {
    case success(String)
    case warning(String)
    case error(String)
    
    var icon: String {
        switch self {
        case .success: return "✅"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
    
    var message: String {
        switch self {
        case .success(let msg), .warning(let msg), .error(let msg): return msg
        }
    }
}

struct ValidationReport {
    var results: [ValidationResult]
    var isValid: Bool {
        !results.contains { if case .error = $0 { return true } else { return false } }
    }
}

actor ValidationService {
    static let shared = ValidationService()
    
    func validateProfile(
        sourceProfile: String,
        roleArn: String?,
        mfaSerial: String?,
        type: SessionType,
        mfaToken: String?
    ) async -> ValidationReport {
        var results: [ValidationResult] = []
        
        // 1. Check source profile exists
        if type == .assumedRole {
            if sourceProfile.isEmpty {
                results.append(.error("Source profile is required for assumed roles"))
                return ValidationReport(results: results)
            } else if await checkProfileExists(sourceProfile) {
                results.append(.success("Source profile '\(sourceProfile)' found"))
            } else {
                results.append(.error("Source profile '\(sourceProfile)' not found in ~/.aws/credentials"))
                return ValidationReport(results: results)
            }
        }
        
        // 2. Validate credentials
        if !sourceProfile.isEmpty {
            let credResult = await validateCredentials(profile: sourceProfile)
            results.append(credResult)
            
            // Stop if credentials are invalid
            if case .error = credResult {
                return ValidationReport(results: results)
            }
        }
        
        // 3. Validate role ARN format
        if type == .assumedRole {
            if let arn = roleArn, !arn.isEmpty {
                if validateRoleArnFormat(arn) {
                    results.append(.success("Role ARN format is valid"))
                } else {
                    results.append(.error("Invalid role ARN format. Expected: arn:aws:iam::ACCOUNT:role/ROLE_NAME"))
                    return ValidationReport(results: results)
                }
            } else {
                results.append(.error("Role ARN is required for assumed roles"))
                return ValidationReport(results: results)
            }
        }
        
        // 4. Validate MFA serial format
        if let mfa = mfaSerial, !mfa.isEmpty {
            if validateMfaSerialFormat(mfa) {
                results.append(.success("MFA serial format is valid"))
            } else {
                results.append(.warning("MFA serial format may be invalid. Expected: arn:aws:iam::ACCOUNT:mfa/USERNAME"))
            }
        }
        
        // 5. Test actual assume-role (deep validation)
        if type == .assumedRole, let arn = roleArn, !arn.isEmpty {
            if let mfa = mfaSerial, !mfa.isEmpty {
                // MFA required
                if let token = mfaToken, !token.isEmpty {
                    let assumeResult = await testAssumeRole(
                        roleArn: arn,
                        sourceProfile: sourceProfile,
                        mfaSerial: mfa,
                        mfaToken: token
                    )
                    results.append(assumeResult)
                } else {
                    results.append(.warning("MFA token required to test role assumption. Provide token for full validation."))
                }
            } else {
                // No MFA required
                let assumeResult = await testAssumeRole(
                    roleArn: arn,
                    sourceProfile: sourceProfile,
                    mfaSerial: nil,
                    mfaToken: nil
                )
                results.append(assumeResult)
            }
        }
        
        return ValidationReport(results: results)
    }
    
    private func checkProfileExists(_ profile: String) async -> Bool {
        let credPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".aws/credentials")
        
        guard let content = try? String(contentsOf: credPath) else { return false }
        return content.contains("[\(profile)]")
    }
    
    private func validateCredentials(profile: String) async -> ValidationResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/aws")
        process.arguments = ["sts", "get-caller-identity", "--profile", profile, "--output", "json"]
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let arn = json["Arn"] as? String {
                    let user = arn.split(separator: "/").last ?? "Unknown"
                    return .success("Credentials valid (User: \(user))")
                }
                return .success("Credentials are valid")
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return .error("Invalid credentials: \(errorMsg.prefix(100))")
            }
        } catch {
            return .error("Failed to validate credentials: \(error.localizedDescription)")
        }
    }
    
    private func testAssumeRole(
        roleArn: String,
        sourceProfile: String,
        mfaSerial: String?,
        mfaToken: String?
    ) async -> ValidationResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/aws")
        
        var args = [
            "sts", "assume-role",
            "--role-arn", roleArn,
            "--role-session-name", "validation-test",
            "--profile", sourceProfile,
            "--output", "json"
        ]
        
        if let mfa = mfaSerial, let token = mfaToken {
            args.append(contentsOf: ["--serial-number", mfa, "--token-code", token])
        }
        
        process.arguments = args
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let assumedRole = json["AssumedRoleUser"] as? [String: Any],
                   let arn = assumedRole["Arn"] as? String {
                    let roleName = arn.split(separator: "/").last ?? "Unknown"
                    return .success("Role assumption successful (Role: \(roleName))")
                }
                return .success("Role assumption successful")
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                
                if errorMsg.contains("AccessDenied") {
                    return .error("Access denied: You don't have permission to assume this role")
                } else if errorMsg.contains("InvalidClientTokenId") {
                    return .error("Invalid credentials for source profile")
                } else if errorMsg.contains("MultiFactorAuthentication") {
                    return .error("MFA required but token invalid or missing")
                } else {
                    return .error("Role assumption failed: \(errorMsg.prefix(150))")
                }
            }
        } catch {
            return .error("Failed to test role assumption: \(error.localizedDescription)")
        }
    }
    
    private func validateRoleArnFormat(_ arn: String) -> Bool {
        let pattern = "^arn:aws:iam::\\d{12}:role/[\\w+=,.@-]+$"
        return arn.range(of: pattern, options: .regularExpression) != nil
    }
    
    private func validateMfaSerialFormat(_ serial: String) -> Bool {
        let pattern = "^arn:aws:iam::\\d{12}:mfa/[\\w+=,.@-]+$"
        return serial.range(of: pattern, options: .regularExpression) != nil
    }
}
