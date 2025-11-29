import Foundation

enum SessionStatus: String, Codable, CaseIterable {
    case active
    case inactive
    case expiring
}

enum SessionType: String, Codable, CaseIterable {
    case iamUser = "IAM User"
    case sso = "AWS SSO"
    case assumedRole = "Assumed Role"
}

struct ProfileExport: Codable {
    var alias: String
    var type: SessionType
    var region: String
    var accountId: String
    var group: String?
    var roleArn: String?
    var mfaSerial: String?
    var sourceProfile: String?
}

struct Session: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var alias: String
    var profileName: String
    var region: String
    var accountId: String
    var status: SessionStatus
    var type: SessionType
    var group: String? // For organizing profiles (Dev, Prod, Personal, etc.)
    var roleArn: String?
    var mfaSerial: String?
    var sourceProfile: String? // For assumed roles - which IAM profile to use
    var accessKeyId: String? // Masked in UI
    var expiration: Date?
    var logs: [String] = [] // Console output logs
    var skipMFACache: Bool = false // If true, bypass MFA cache for federation compatibility
    var autoRenew: Bool = false // If true, automatically renew session before expiration
    
    static var mockData: [Session] {
        [
            Session(alias: "Production", profileName: "prod-admin", region: "us-east-1", accountId: "123456789012", status: .active, type: .sso, accessKeyId: "AKIA...", expiration: Date().addingTimeInterval(3600)),
            Session(alias: "Development", profileName: "dev-sandbox", region: "ap-southeast-1", accountId: "987654321098", status: .inactive, type: .assumedRole, roleArn: "arn:aws:iam::987654321098:role/DeveloperRole", mfaSerial: "arn:aws:iam::123456789012:mfa/user", accessKeyId: nil, expiration: nil),
            Session(alias: "Staging", profileName: "staging", region: "eu-central-1", accountId: "555555555555", status: .expiring, type: .assumedRole, accessKeyId: "ASIA...", expiration: Date().addingTimeInterval(300))
        ]
    }
    
    func toExport() -> ProfileExport {
        ProfileExport(
            alias: alias,
            type: type,
            region: region,
            accountId: accountId,
            group: group,
            roleArn: roleArn,
            mfaSerial: mfaSerial,
            sourceProfile: sourceProfile
        )
    }
    
    static func fromExport(_ export: ProfileExport) -> Session {
        Session(
            alias: export.alias,
            profileName: export.type == .assumedRole ? export.alias : "",
            region: export.region,
            accountId: export.accountId,
            status: .inactive,
            type: export.type,
            group: export.group,
            roleArn: export.roleArn,
            mfaSerial: export.mfaSerial,
            sourceProfile: export.sourceProfile
        )
    }
}
