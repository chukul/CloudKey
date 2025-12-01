import Foundation
import Security
import SwiftOTP

class TOTPService {
    static let shared = TOTPService()
    
    private let keychainService = "com.cloudkey.totp"
    
    private init() {}
    
    // MARK: - TOTP Secret Management
    
    /// Store TOTP secret in Keychain
    func storeTOTPSecret(for profileAlias: String, secret: String) -> Bool {
        guard let secretData = secret.data(using: .utf8) else { return false }
        
        // Delete existing entry first
        deleteTOTPSecret(for: profileAlias)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: profileAlias,
            kSecValueData as String: secretData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Retrieve TOTP secret from Keychain
    func getTOTPSecret(for profileAlias: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: profileAlias,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let secret = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return secret
    }
    
    /// Delete TOTP secret from Keychain
    func deleteTOTPSecret(for profileAlias: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: profileAlias
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Check if profile has TOTP secret stored
    func hasTOTPSecret(for profileAlias: String) -> Bool {
        return getTOTPSecret(for: profileAlias) != nil
    }
    
    // MARK: - TOTP Code Generation
    
    /// Generate current TOTP code for profile
    func generateTOTPCode(for profileAlias: String) -> String? {
        guard let secret = getTOTPSecret(for: profileAlias) else {
            return nil
        }
        
        return generateTOTPCode(from: secret)
    }
    
    /// Generate TOTP code from secret
    func generateTOTPCode(from secret: String) -> String? {
        // Clean secret (remove spaces and convert to uppercase)
        let cleanSecret = secret.replacingOccurrences(of: " ", with: "").uppercased()
        
        guard let secretData = base32DecodeToData(cleanSecret) else {
            return nil
        }
        
        guard let totp = TOTP(secret: secretData, digits: 6, timeInterval: 30, algorithm: .sha1) else {
            return nil
        }
        
        return totp.generate(time: Date())
    }
    
    /// Get time remaining until next code
    func getTimeRemaining() -> Int {
        let now = Date().timeIntervalSince1970
        let timeInterval: TimeInterval = 30
        let remaining = timeInterval - now.truncatingRemainder(dividingBy: timeInterval)
        return Int(remaining)
    }
    
    // MARK: - Secret Validation
    
    /// Validate TOTP secret format
    func validateSecret(_ secret: String) -> Bool {
        let cleanSecret = secret.replacingOccurrences(of: " ", with: "").uppercased()
        
        // Check if valid base32
        guard base32DecodeToData(cleanSecret) != nil else {
            return false
        }
        
        // Try to generate a code
        return generateTOTPCode(from: secret) != nil
    }
    
    /// Parse TOTP URI (otpauth://totp/...)
    func parseOTPAuthURI(_ uri: String) -> (issuer: String?, account: String?, secret: String?)? {
        guard let url = URL(string: uri),
              url.scheme == "otpauth",
              url.host == "totp" else {
            return nil
        }
        
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        var issuer: String?
        var account: String?
        var secret: String?
        
        // Parse account from path
        if path.contains(":") {
            let parts = path.split(separator: ":", maxSplits: 1)
            issuer = String(parts[0])
            account = String(parts[1])
        } else {
            account = path
        }
        
        // Parse query parameters
        if let queryItems = components?.queryItems {
            for item in queryItems {
                switch item.name {
                case "secret":
                    secret = item.value
                case "issuer":
                    issuer = item.value
                default:
                    break
                }
            }
        }
        
        return (issuer, account, secret)
    }
    
    // MARK: - Base32 Decoding
    
    private func base32DecodeToData(_ string: String) -> Data? {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        var bits = ""
        
        for char in string.uppercased() {
            guard let index = alphabet.firstIndex(of: char) else {
                continue
            }
            let binary = String(alphabet.distance(from: alphabet.startIndex, to: index), radix: 2)
            bits += String(repeating: "0", count: 5 - binary.count) + binary
        }
        
        var bytes = [UInt8]()
        for i in stride(from: 0, to: bits.count, by: 8) {
            let endIndex = min(i + 8, bits.count)
            let byteString = String(bits[bits.index(bits.startIndex, offsetBy: i)..<bits.index(bits.startIndex, offsetBy: endIndex)])
            if byteString.count == 8, let byte = UInt8(byteString, radix: 2) {
                bytes.append(byte)
            }
        }
        
        return Data(bytes)
    }
}
