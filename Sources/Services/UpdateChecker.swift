import Foundation
import SwiftUI

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let htmlUrl: String
    let body: String?
    let publishedAt: String
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlUrl = "html_url"
        case body
        case publishedAt = "published_at"
    }
}

@MainActor
class UpdateChecker: ObservableObject {
    @Published var updateAvailable = false
    @Published var latestVersion = ""
    @Published var releaseURL = ""
    @Published var releaseNotes = ""
    
    private let repoOwner = "chukul"
    private let repoName = "CloudKey"
    
    // Test mode - set to true to simulate update available
    private let testMode = false
    
    func checkForUpdates() async {
        // Test mode simulation
        if testMode {
            let currentVersion = getCurrentVersion()
            let testVersion = "1.0.1"
            
            if isNewerVersion(latest: testVersion, current: currentVersion) {
                self.updateAvailable = true
                self.latestVersion = testVersion
                self.releaseURL = "https://github.com/\(repoOwner)/\(repoName)/releases/latest"
                self.releaseNotes = "🧪 TEST MODE\n\n• Added automatic update checking\n• Improved UI performance\n• Bug fixes"
            }
            return
        }
        
        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            
            let currentVersion = getCurrentVersion()
            let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
            
            if isNewerVersion(latest: latestVersion, current: currentVersion) {
                self.updateAvailable = true
                self.latestVersion = latestVersion
                self.releaseURL = release.htmlUrl
                self.releaseNotes = release.body ?? "No release notes available"
            }
        } catch {
            print("Failed to check for updates: \(error)")
        }
    }
    
    func getCurrentVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private func isNewerVersion(latest: String, current: String) -> Bool {
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(latestComponents.count, currentComponents.count) {
            let latestPart = i < latestComponents.count ? latestComponents[i] : 0
            let currentPart = i < currentComponents.count ? currentComponents[i] : 0
            
            if latestPart > currentPart {
                return true
            } else if latestPart < currentPart {
                return false
            }
        }
        return false
    }
    
    func openReleaseURL() {
        if let url = URL(string: releaseURL) {
            NSWorkspace.shared.open(url)
        }
    }
}
