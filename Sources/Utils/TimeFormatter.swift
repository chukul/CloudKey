import Foundation
import SwiftUI

struct TimeFormatter {
    static func formatRemainingTime(expiration: Date, now: Date = Date()) -> (String, Color) {
        let remaining = expiration.timeIntervalSince(now)
        
        if remaining <= 0 {
            return ("Expired", .red)
        } else if remaining < 300 {
            let minutes = Int(remaining / 60)
            let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
            return (String(format: "%d:%02d", minutes, seconds), .red)
        } else if remaining < 900 {
            let minutes = Int(remaining / 60)
            return ("\(minutes)m", .orange)
        } else if remaining < 3600 {
            let minutes = Int(remaining / 60)
            return ("\(minutes)m", .secondary)
        } else {
            let hours = Int(remaining / 3600)
            let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
            return ("\(hours)h \(minutes)m", .secondary)
        }
    }
}
